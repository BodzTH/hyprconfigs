#!/usr/bin/env python3
"""
Sync the Hyprland active border (and hyprlock, hyprtoolkit, GTK, OpenRGB
accents) to the most harmonious color in the current wallpaper. Greyscale or
near-black wallpapers fall back to Platinum.

Usage: sync_border.py [IMAGE] [--dry-run]
       IMAGE defaults to the wallpaper awww is currently displaying.
"""

import argparse
import colorsys
import os
import re
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image

PLATINUM = "e5e5e5"


def current_wallpaper():
    """Path of the image awww is currently displaying, or None."""
    try:
        out = subprocess.run(["awww", "query"], capture_output=True, text=True, timeout=1.5).stdout
    except (OSError, subprocess.TimeoutExpired):
        return None
    for line in out.splitlines():
        if "currently displaying: image:" in line:
            path = line.split("currently displaying: image:", 1)[1].strip()
            if os.path.isfile(path):
                return path
    return None


def extract_color(image_path):
    """Return (hex, reason) for the most harmonious border color in the image."""
    im = Image.open(image_path)
    if getattr(im, "is_animated", False):
        im.seek(0)  # first frame of animated GIF/WebP
    im = im.convert("RGB").resize((150, 150), Image.Resampling.BILINEAR)
    pixels = (np.array(im, dtype=np.float32) / 255.0).reshape(-1, 3)
    r, g, b = pixels[:, 0], pixels[:, 1], pixels[:, 2]

    # 1. Greyscale / near-black detection -> Platinum
    channel_deltas = np.max(pixels, axis=1) - np.min(pixels, axis=1)
    mean_delta = float(np.mean(channel_deltas))
    chromatic_ratio = float(np.mean(channel_deltas > 0.08))
    mean_luminance = float(np.mean(0.299 * r + 0.587 * g + 0.114 * b))
    if chromatic_ratio < 0.035 or mean_delta < 0.035 or (mean_luminance < 0.02 and chromatic_ratio < 0.10):
        return PLATINUM, "monochrome wallpaper"

    # 2. HSV of every pixel; keep reasonably bright, saturated candidates
    cmax = np.maximum(np.maximum(r, g), b)
    delta = cmax - np.minimum(np.minimum(r, g), b)
    sat = np.zeros_like(cmax)
    nonzero = cmax > 0.001
    sat[nonzero] = delta[nonzero] / cmax[nonzero]

    hue = np.zeros_like(cmax)
    dnonzero = delta > 0.001
    mask_r = (cmax == r) & dnonzero
    hue[mask_r] = ((g[mask_r] - b[mask_r]) / delta[mask_r]) % 6.0
    mask_g = (cmax == g) & dnonzero
    hue[mask_g] = ((b[mask_g] - r[mask_g]) / delta[mask_g]) + 2.0
    mask_b = (cmax == b) & dnonzero
    hue[mask_b] = ((r[mask_b] - g[mask_b]) / delta[mask_b]) + 4.0
    hue = (hue / 6.0) % 1.0

    valid = (cmax > 0.07) & (sat > 0.12)
    if np.sum(valid) < 40:
        return PLATINUM, "not enough colored pixels"
    valid_pixels, valid_sat, valid_val = pixels[valid], sat[valid], cmax[valid]

    # 3. Score 36 hue bins by frequency and saturation/brightness sweet spots
    bins = 36
    hue_indices = (hue[valid] * bins).astype(int) % bins
    best_score, best_rgb, best_bin = -1.0, None, 0
    for i in range(bins):
        in_bin = hue_indices == i
        count = int(np.sum(in_bin))
        if count == 0:
            continue
        sat_score = np.exp(-((float(np.mean(valid_sat[in_bin])) - 0.55) ** 2) / 0.12)
        val_score = np.exp(-((float(np.mean(valid_val[in_bin])) - 0.65) ** 2) / 0.15)
        score = (count / len(valid_pixels)) ** 0.60 * sat_score * val_score
        if score > best_score:
            best_score, best_rgb, best_bin = score, np.mean(valid_pixels[in_bin], axis=0), i

    # 4. Clamp lightness/saturation so the border glows on dark themes
    h, l, s = colorsys.rgb_to_hls(*best_rgb)
    l, s = float(np.clip(l, 0.54, 0.72)), float(np.clip(s, 0.40, 0.90))
    rgb = (int(np.round(np.clip(c * 255, 0, 255))) for c in colorsys.hls_to_rgb(h, l, s))
    return "".join(f"{c:02x}" for c in rgb), f"hue bin {best_bin}"


def rewrite(path, substitutions):
    """Apply (regex, replacement) pairs to a file in place, atomically."""
    path = os.path.expanduser(path)
    if not os.path.isfile(path):
        return
    with open(path) as f:
        content = f.read()
    new = content
    for pattern, repl in substitutions:
        new = re.sub(pattern, repl, new, flags=re.MULTILINE)
    if new != content:
        with open(path + ".tmp", "w") as f:
            f.write(new)
        os.replace(path + ".tmp", path)


def apply(hex_color):
    """Push the color to Hyprland, hyprlock, hyprtoolkit, GTK and OpenRGB."""
    rewrite("~/.config/hypr/hyprlock.conf", [
        (r"^\$accent\s*=.*$", f"$accent   = rgb({hex_color})"),
        (r"^\$accentAlpha\s*=.*$", f"$accentAlpha = {hex_color}"),
    ])
    rewrite("~/.config/hypr/hyprtoolkit.conf", [
        (r"^accent\s*=.*$", f"accent = 0xFF{hex_color}"),
    ])
    for css in ("~/.config/gtk-3.0/gtk.css", "~/.config/gtk-4.0/gtk.css", "~/.config/gtk-4.0/gtk-dark.css"):
        rewrite(css, [
            (r"@define-color\s+accent_color\s+#[0-9a-fA-F]+;", f"@define-color accent_color #{hex_color};"),
            (r"@define-color\s+accent_bg_color\s+#[0-9a-fA-F]+;", f"@define-color accent_bg_color #{hex_color};"),
        ])

    if shutil.which("openrgb"):
        subprocess.Popen(["openrgb", "--noautoconnect", "-m", "static", "-c", hex_color],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    border = f'{{ "rgba({hex_color}ee)", "rgba({hex_color}00)" }}'
    lua = f"hl.config({{ general = {{ col = {{ active_border = {{ colors = {border}, angle = 45 }} }} }} }})"
    subprocess.run(["hyprctl", "eval", lua], capture_output=True, timeout=2.0)


def main():
    parser = argparse.ArgumentParser(description="Sync Hyprland border and accents to the wallpaper color.")
    parser.add_argument("image", nargs="?", help="wallpaper to analyze (default: current awww wallpaper)")
    parser.add_argument("-d", "--dry-run", action="store_true", help="print the color without applying it")
    args = parser.parse_args()

    image = args.image or current_wallpaper()
    if image and not os.path.isfile(image):
        sys.exit(f"sync_border: no such file: {image}")
    hex_color, reason = extract_color(image) if image else (PLATINUM, "no wallpaper detected")

    if args.dry_run:
        print(f"{image or '-'}: #{hex_color} ({reason})")
    else:
        apply(hex_color)


if __name__ == "__main__":
    main()
