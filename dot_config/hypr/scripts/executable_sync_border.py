#!/usr/bin/env python3
"""
Dynamic Hyprland Border Synchronizer with Aesthetic Wallpaper Color Extraction
and Smart Platinum Fallback.

Extracts the most aesthetically harmonious color from the active wallpaper,
tunes it into a glowing semi-transparent gradient fading to complete transparency,
and updates Hyprland in real-time.
"""

import sys
import os
import re
import time
import glob
import json
import shutil
import argparse
import subprocess
import colorsys
from PIL import Image
import numpy as np

# Premium neutral fallback for black, monochrome, or greyscale wallpapers
PLATINUM_HEX = "e5e5e5"
PLATINUM_RGBA_ACTIVE = f"rgba({PLATINUM_HEX}ee)"
PLATINUM_RGBA_TRANSPARENT = f"rgba({PLATINUM_HEX}00)"

# Detected once — avoids a failed spawn attempt on every wallpaper change on
# machines with no OpenRGB-controlled hardware (e.g. a laptop).
HAS_OPENRGB = shutil.which("openrgb") is not None
HAS_MAGICK = shutil.which("magick") is not None

def get_current_wallpaper_from_awww(monitor=None):
    """Query awww or its cache to find the currently active wallpaper."""
    # 1. Try awww query command
    try:
        res = subprocess.run(["awww", "query"], capture_output=True, text=True, timeout=1.5)
        if res.returncode == 0 and res.stdout:
            for line in res.stdout.strip().split("\n"):
                if monitor and monitor not in line:
                    continue
                if "currently displaying: image:" in line:
                    path = line.split("currently displaying: image:", 1)[1].strip()
                    if os.path.isfile(path):
                        return path
    except Exception:
        pass

    # 2. Try checking ~/.cache/awww/*/*
    cache_dirs = glob.glob(os.path.expanduser("~/.cache/awww/*"))
    for cdir in cache_dirs:
        if os.path.isdir(cdir):
            cache_files = glob.glob(os.path.join(cdir, "*"))
            for cf in cache_files:
                if monitor and monitor not in os.path.basename(cf):
                    continue
                try:
                    with open(cf, "r") as f:
                        content = f.read().strip()
                        # Content format: e.g. " crop:center Lanczos3 /path/to/image.jpg"
                        parts = content.split()
                        for part in reversed(parts):
                            if os.path.isfile(part):
                                return part
                except Exception:
                    pass

    return None

def load_image(image_path):
    """Load image, handling formats like GIF, SVG, PNG, JPEG."""
    if not os.path.isfile(image_path):
        raise FileNotFoundError(f"Image not found: {image_path}")

    # For SVG files, convert to temporary PNG using magick
    if image_path.lower().endswith(".svg"):
        if not HAS_MAGICK:
            raise RuntimeError("magick not found; required to render SVG wallpapers")
        try:
            tmp_png = "/tmp/hypr_border_sync_svg.png"
            subprocess.run(["magick", image_path, tmp_png], check=True, timeout=2.0)
            image_path = tmp_png
        except Exception as e:
            raise RuntimeError(f"Failed to render SVG: {e}")

    try:
        im = Image.open(image_path)
        # Handle animated GIFs / WebPs by taking the first frame
        if getattr(im, "is_animated", False):
            im.seek(0)
        return im.convert("RGB")
    except Exception as e:
        # Fallback to magick convert if PIL fails
        if not HAS_MAGICK:
            raise
        tmp_fallback = "/tmp/hypr_border_sync_fallback.png"
        subprocess.run(["magick", f"{image_path}[0]", tmp_fallback], check=True, timeout=2.0)
        im = Image.open(tmp_fallback)
        return im.convert("RGB")

def extract_harmonious_color(image_path):
    """
    Analyzes wallpaper color palette and selects the most aesthetically harmonious
    color for glowing window borders. Gracefully falls back to Platinum for monochrome.
    
    Returns:
        dict: {
            "mode": "PLATINUM" | "COLOR",
            "hex": hex_color_string (e.g. "9c24e4" or "e5e5e5"),
            "active_rgba": "rgba(RRGGBBee)",
            "transparent_rgba": "rgba(RRGGBB00)",
            "rgb": (r, g, b),
            "reason": description
        }
    """
    im = load_image(image_path)
    
    # Downsample for fast analysis (150x150 is optimal for speed vs color accuracy)
    im = im.resize((150, 150), Image.Resampling.BILINEAR)
    arr = np.array(im, dtype=np.float32) / 255.0
    pixels = arr.reshape(-1, 3)

    r, g, b = pixels[:, 0], pixels[:, 1], pixels[:, 2]

    # --- 1. MONOCHROME / GREYSCALE / PURE BLACK DETECTION ---
    channel_deltas = np.max(pixels, axis=1) - np.min(pixels, axis=1)
    mean_delta = float(np.mean(channel_deltas))
    chromatic_ratio = float(np.mean(channel_deltas > 0.08))
    mean_luminance = float(np.mean(0.299 * r + 0.587 * g + 0.114 * b))

    # If wallpaper is greyscale, extremely dark black, or has negligible color variation
    if chromatic_ratio < 0.035 or mean_delta < 0.035 or (mean_luminance < 0.02 and chromatic_ratio < 0.10):
        return {
            "mode": "PLATINUM",
            "hex": PLATINUM_HEX,
            "active_rgba": PLATINUM_RGBA_ACTIVE,
            "transparent_rgba": PLATINUM_RGBA_TRANSPARENT,
            "rgb": (229, 229, 229),
            "reason": f"Monochrome/Greyscale detected (chromatic_ratio={chromatic_ratio:.3f}, mean_delta={mean_delta:.3f}, mean_lum={mean_luminance:.3f})"
        }

    # --- 2. CANDIDATE PIXEL FILTERING ---
    cmax = np.maximum(np.maximum(r, g), b)
    cmin = np.minimum(np.minimum(r, g), b)
    delta = cmax - cmin

    val = cmax
    sat = np.zeros_like(cmax)
    nonzero = cmax > 0.001
    sat[nonzero] = delta[nonzero] / cmax[nonzero]

    # Calculate Hue
    hue = np.zeros_like(cmax)
    dnonzero = delta > 0.001

    mask_r = (cmax == r) & dnonzero
    hue[mask_r] = ((g[mask_r] - b[mask_r]) / delta[mask_r]) % 6.0

    mask_g = (cmax == g) & dnonzero
    hue[mask_g] = ((b[mask_g] - r[mask_g]) / delta[mask_g]) + 2.0

    mask_b = (cmax == b) & dnonzero
    hue[mask_b] = ((r[mask_b] - g[mask_b]) / delta[mask_b]) + 4.0

    hue = (hue / 6.0) % 1.0

    # Filter out pure black shadow noise (val <= 0.07) and uncolored low saturation (sat <= 0.12)
    valid_mask = (val > 0.07) & (sat > 0.12)
    if np.sum(valid_mask) < 40:
        return {
            "mode": "PLATINUM",
            "hex": PLATINUM_HEX,
            "active_rgba": PLATINUM_RGBA_ACTIVE,
            "transparent_rgba": PLATINUM_RGBA_TRANSPARENT,
            "rgb": (229, 229, 229),
            "reason": "Insufficient chromatic candidate pixels; falling back to Platinum"
        }

    valid_pixels = pixels[valid_mask]
    valid_sat = sat[valid_mask]
    valid_val = val[valid_mask]
    valid_hue = hue[valid_mask]

    # --- 3. ATMOSPHERIC COLOR HARMONY CLUSTERING ---
    # 36 hue bins (10° per bin)
    bins = 36
    hue_indices = (valid_hue * bins).astype(int) % bins

    bin_scores = np.zeros(bins)
    bin_rgbs = []

    for i in range(bins):
        in_bin = (hue_indices == i)
        count = int(np.sum(in_bin))
        if count == 0:
            bin_rgbs.append((0.0, 0.0, 0.0))
            continue

        bin_p = valid_pixels[in_bin]
        bin_s = valid_sat[in_bin]
        bin_v = valid_val[in_bin]

        mean_rgb = np.mean(bin_p, axis=0)
        bin_rgbs.append(mean_rgb)

        avg_s = float(np.mean(bin_s))
        avg_v = float(np.mean(bin_v))
        freq = count / len(valid_pixels)

        # Mood harmony scoring:
        # 1. Saturation preference: sweet spot 0.40 - 0.75
        sat_score = np.exp(-((avg_s - 0.55) ** 2) / 0.12)

        # 2. Value/brightness preference: sweet spot 0.45 - 0.85
        val_score = np.exp(-((avg_v - 0.65) ** 2) / 0.15)

        # 3. Frequency weighting: prominent colors in the image
        freq_weight = freq ** 0.60

        bin_scores[i] = freq_weight * sat_score * val_score

    best_bin = int(np.argmax(bin_scores))
    best_rgb = bin_rgbs[best_bin]

    # --- 4. GLOW & LUMINANCE TUNING FOR HYPRLAND ACTIVE BORDER ---
    # Convert chosen color to HLS
    h, l, s = colorsys.rgb_to_hls(*best_rgb)

    # Adjust Lightness so border glows clearly against dark/translucent themes without washing out
    adjusted_l = float(np.clip(l, 0.54, 0.72))
    # Adjust Saturation into rich, vibrant range while retaining natural hue
    adjusted_s = float(np.clip(s, 0.40, 0.90))

    final_r, final_g, final_b = colorsys.hls_to_rgb(h, adjusted_l, adjusted_s)
    ir, ig, ib = int(np.round(np.clip(final_r * 255, 0, 255))), int(np.round(np.clip(final_g * 255, 0, 255))), int(np.round(np.clip(final_b * 255, 0, 255)))

    hex_color = f"{ir:02x}{ig:02x}{ib:02x}"
    active_rgba = f"rgba({hex_color}ee)"
    transparent_rgba = f"rgba({hex_color}00)"

    return {
        "mode": "COLOR",
        "hex": hex_color,
        "active_rgba": active_rgba,
        "transparent_rgba": transparent_rgba,
        "rgb": (ir, ig, ib),
        "reason": f"Harmonious tone extracted from hue bin {best_bin} (H={h*360:.1f}°, S={adjusted_s:.2f}, L={adjusted_l:.2f})"
    }

def apply_color_to_openrgb(color_info):
    """Synchronizes OpenRGB hardware lighting with the exact matching wallpaper/border color in static mode."""
    if not HAS_OPENRGB:
        return
    hex_color = color_info["hex"]
    try:
        subprocess.Popen(
            ["openrgb", "--noautoconnect", "-m", "static", "-c", hex_color],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
    except Exception:
        pass

def apply_color_to_hyprtoolkit(color_info):
    """Synchronizes hyprtoolkit accent color with the active border/wallpaper color."""
    hex_color = color_info["hex"].lower()
    config_path = os.path.expanduser("~/.config/hypr/hyprtoolkit.conf")
    if not os.path.isfile(config_path):
        return

    try:
        with open(config_path, "r") as f:
            lines = f.readlines()

        new_lines = []
        for line in lines:
            if line.strip().startswith("accent ="):
                new_lines.append(f"accent = 0xFF{hex_color}\n")
            else:
                new_lines.append(line)

        tmp_path = config_path + ".tmp"
        with open(tmp_path, "w") as f:
            f.writelines(new_lines)
        os.replace(tmp_path, config_path)
    except Exception as e:
        print(f"Error updating hyprtoolkit config: {e}", file=sys.stderr)

def apply_color_to_hyprlock(color_info):
    """Synchronizes hyprlock accent color with the active border/wallpaper color."""
    hex_color = color_info["hex"].lower()
    config_path = os.path.expanduser("~/.config/hypr/hyprlock.conf")
    if not os.path.isfile(config_path):
        return

    try:
        with open(config_path, "r") as f:
            lines = f.readlines()

        new_lines = []
        for line in lines:
            if line.strip().startswith("$accent   =") or line.strip().startswith("$accent ="):
                new_lines.append(f"$accent   = rgb({hex_color})\n")
            elif line.strip().startswith("$accentAlpha =") or line.strip().startswith("$accentAlpha   ="):
                new_lines.append(f"$accentAlpha = {hex_color}\n")
            else:
                new_lines.append(line)

        tmp_path = config_path + ".tmp"
        with open(tmp_path, "w") as f:
            f.writelines(new_lines)
        os.replace(tmp_path, config_path)
    except Exception as e:
        print(f"Error updating hyprlock config: {e}", file=sys.stderr)

def apply_color_to_gtk(color_info):
    """Synchronizes GTK3 and GTK4/Libadwaita accent and dialog border colors."""
    hex_color = color_info["hex"].lower()
    gtk_targets = [
        os.path.expanduser("~/.config/gtk-3.0/gtk.css"),
        os.path.expanduser("~/.config/gtk-4.0/gtk.css"),
        os.path.expanduser("~/.config/gtk-4.0/gtk-dark.css"),
    ]
    for css_file in gtk_targets:
        if not os.path.isfile(css_file):
            continue
        try:
            with open(css_file, "r") as f:
                content = f.read()

            new_content = re.sub(
                r"@define-color\s+accent_color\s+#[0-9a-fA-F]+;",
                f"@define-color accent_color #{hex_color};",
                content
            )
            new_content = re.sub(
                r"@define-color\s+accent_bg_color\s+#[0-9a-fA-F]+;",
                f"@define-color accent_bg_color #{hex_color};",
                new_content
            )

            tmp_file = css_file + ".tmp"
            with open(tmp_file, "w") as f:
                f.write(new_content)
            os.replace(tmp_file, css_file)
        except Exception as e:
            print(f"Error updating GTK config {css_file}: {e}", file=sys.stderr)

def apply_border_to_hyprland(color_info):
    """Updates Hyprland's active_border with glowing gradient fading to transparency and syncs OpenRGB, hyprtoolkit, hyprlock, and GTK."""
    active_rgba = color_info["active_rgba"]
    transparent_rgba = color_info["transparent_rgba"]

    # Save to ~/.cache/hypr_border_color.json for external tools / reference
    try:
        cache_path = os.path.expanduser("~/.cache/hypr_border_color.json")
        with open(cache_path + ".tmp", "w") as f:
            json.dump({
                "hex": f"#{color_info['hex']}",
                "rgb": list(color_info["rgb"]),
                "active_rgba": active_rgba,
                "transparent_rgba": transparent_rgba,
                "mode": color_info["mode"]
            }, f)
        os.replace(cache_path + ".tmp", cache_path)
    except Exception as e:
        print(f"Error writing color cache: {e}", file=sys.stderr)

    # Sync OpenRGB hardware lighting in background
    apply_color_to_openrgb(color_info)

    # Sync hyprtoolkit, hyprlock, and GTK theme colors
    apply_color_to_hyprtoolkit(color_info)
    apply_color_to_hyprlock(color_info)
    apply_color_to_gtk(color_info)

    # Hyprland 0.55+ Lua eval command
    lua_code = f'hl.config({{ general = {{ col = {{ active_border = {{ colors = {{ "{active_rgba}", "{transparent_rgba}" }}, angle = 45 }} }} }} }})'
    
    try:
        res = subprocess.run(["hyprctl", "eval", lua_code], capture_output=True, text=True, timeout=2.0)
        return res.returncode == 0
    except Exception as e:
        print(f"Error applying border to Hyprland: {e}", file=sys.stderr)
        return False

def sync(image_path=None, dry_run=False, verbose=False):
    """Executes single border synchronization."""
    if not image_path:
        image_path = get_current_wallpaper_from_awww()
        if not image_path:
            if verbose:
                print("No active wallpaper detected via awww. Falling back to Platinum.")
            color_info = {
                "mode": "PLATINUM",
                "hex": PLATINUM_HEX,
                "active_rgba": PLATINUM_RGBA_ACTIVE,
                "transparent_rgba": PLATINUM_RGBA_TRANSPARENT,
                "rgb": (229, 229, 229),
                "reason": "No active wallpaper detected"
            }
            if not dry_run:
                apply_border_to_hyprland(color_info)
            return color_info

    start_time = time.perf_counter()
    color_info = extract_harmonious_color(image_path)
    elapsed_ms = (time.perf_counter() - start_time) * 1000

    if verbose or dry_run:
        print(f"Wallpaper:   {image_path}")
        print(f"Status:      {color_info['mode']} ({color_info['reason']})")
        print(f"Extracted:   #{color_info['hex']} | RGB: {color_info['rgb']}")
        print(f"Active RGBA: {color_info['active_rgba']} -> {color_info['transparent_rgba']}")
        print(f"Duration:    {elapsed_ms:.2f} ms")

    if not dry_run:
        success = apply_border_to_hyprland(color_info)
        if verbose and success:
            print("Successfully updated Hyprland active border.")

    return color_info

def _awww_cache_mtime():
    """Cheapest possible signal that something in awww's cache changed.

    ~1.7us via os.stat() vs ~1.1ms to spawn `awww query` — checking this first
    means the watcher only pays for the subprocess when something actually moved.
    """
    newest = 0
    for cdir in glob.glob(os.path.expanduser("~/.cache/awww/*")):
        try:
            newest = max(newest, os.stat(cdir).st_mtime_ns)
        except OSError:
            pass
    return newest


def watch_mode():
    """Monitors awww wallpaper changes and updates border in real time.

    Not used by autostart (awww_transition.sh already re-syncs on every change) —
    kept only for manual/debugging use, so it stays cheap when left running.
    """
    last_wallpaper = None
    last_cache_mtime = None
    print("Border Synchronizer Watcher active. Monitoring wallpaper changes...")

    while True:
        try:
            mtime = _awww_cache_mtime()
            if mtime != last_cache_mtime:
                last_cache_mtime = mtime
                current = get_current_wallpaper_from_awww()
                if current and current != last_wallpaper:
                    last_wallpaper = current
                    info = sync(current, dry_run=False, verbose=False)
                    print(f"Wallpaper updated: {os.path.basename(current)} -> #{info['hex']} ({info['mode']})")
        except Exception as e:
            print(f"Watcher error: {e}", file=sys.stderr)

        time.sleep(0.5)

def main():
    parser = argparse.ArgumentParser(description="Synchronize Hyprland active border with wallpaper color.")
    parser.add_argument("image", nargs="?", help="Path to wallpaper image file (optional, queries awww if omitted)")
    parser.add_argument("-d", "--dry-run", action="store_true", help="Analyze and print color info without applying to Hyprland")
    parser.add_argument("-v", "--verbose", action="store_true", help="Print detailed diagnostic output")
    parser.add_argument("-w", "--watch", action="store_true", help="Run in continuous watch/daemon mode")

    args = parser.parse_args()

    if args.watch:
        # Initial sync first
        sync(args.image, dry_run=False, verbose=args.verbose)
        watch_mode()
    else:
        sync(args.image, dry_run=args.dry_run, verbose=args.verbose or args.dry_run)

if __name__ == "__main__":
    main()
