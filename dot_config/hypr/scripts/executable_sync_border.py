#!/usr/bin/env python3
"""
Sync the Hyprland active border and group tabs (and hyprlock, hyprtoolkit, quickshell, GTK,
Qt/Kvantum, yazi, neovim, starship, kitty cursor and OpenRGB accents) to the most harmonious
color in the current wallpaper. Greyscale or near-black wallpapers fall back
to Platinum.

Usage: sync_border.py [IMAGE] [--dry-run]
       IMAGE defaults to the wallpaper awww is currently displaying.
"""

import argparse
import colorsys
import fcntl
import glob
import os
import re
import signal
import subprocess
import sys
import time

# numpy and PIL are imported inside extract_color(), not here: they take ~70ms
# to load, and the latest-wins token must be claimed before that — otherwise
# two runs started close together could claim in the wrong order.

PLATINUM = "e5e5e5"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ACCENT_STATE = os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "hypr", "accent")
# Latest-wins. Two wallpaper changes in quick succession start two runs; without
# this, whichever finished last won — not necessarily the newest. Each run
# claims TOKEN_FILE on start; the check-and-apply is serialised on LOCK_FILE so
# an older run can't pass the check and then finish applying after a newer one.
RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
TOKEN_FILE = os.path.join(RUNTIME_DIR, "sync_border.token")
LOCK_FILE = os.path.join(RUNTIME_DIR, "sync_border.lock")


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
    import numpy as np
    from PIL import Image

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

    # 2. Hue of every pixel. Chroma (max - min channel) is how colourful a pixel
    #    is, independent of how bright it is.
    cmax = np.max(pixels, axis=1)
    chroma = channel_deltas
    hue = np.zeros_like(cmax)
    nonzero = chroma > 0.001
    mask_r = (cmax == r) & nonzero
    hue[mask_r] = ((g[mask_r] - b[mask_r]) / chroma[mask_r]) % 6.0
    mask_g = (cmax == g) & nonzero
    hue[mask_g] = ((b[mask_g] - r[mask_g]) / chroma[mask_g]) + 2.0
    mask_b = (cmax == b) & nonzero
    hue[mask_b] = ((r[mask_b] - g[mask_b]) / chroma[mask_b]) + 4.0
    hue = (hue / 6.0) % 1.0

    valid = (chroma > 0.15) & (cmax > 0.15)
    if np.sum(valid) < 40:
        return PLATINUM, "not enough colored pixels"

    # 3. Chroma^2-weighted hue histogram. The old scorer ranked hue bins mostly
    #    by pixel *count*, so a large, dull, bluish-grey backdrop beat the
    #    wallpaper's actual accent, and step 4's saturation floor then turned
    #    that grey into a steel blue that appears nowhere in the image (e.g.
    #    relaxed_mario.png -> #5b83b9 instead of its lavender; the green CRT in
    #    moments_before_desk.png lost the same way). Weighting by chroma^2 lets
    #    a vivid accent outweigh a big muted area. Neighbouring bins are
    #    smoothed together so one hue split across a bin edge isn't penalised.
    weights = chroma[valid] ** 2
    bins = 36
    hue_indices = (hue[valid] * bins).astype(int) % bins
    hist = np.bincount(hue_indices, weights=weights, minlength=bins)
    smoothed = hist + 0.5 * np.roll(hist, 1) + 0.5 * np.roll(hist, -1)
    best_bin = int(np.argmax(smoothed))
    in_peak = np.isin(hue_indices, [(best_bin - 1) % bins, best_bin, (best_bin + 1) % bins])
    best_rgb = (pixels[valid][in_peak] * weights[in_peak, None]).sum(axis=0) / weights[in_peak].sum()

    # 4. Clamp lightness/saturation so the border glows on dark themes
    h, l, s = colorsys.rgb_to_hls(*best_rgb)
    l, s = float(np.clip(l, 0.54, 0.72)), float(np.clip(s, 0.40, 0.90))
    rgb = (int(np.round(np.clip(c * 255, 0, 255))) for c in colorsys.hls_to_rgb(h, l, s))
    return "".join(f"{c:02x}" for c in rgb), f"hue bin {best_bin}"


def companion(hex_color):
    """A second colour that sits beside the accent: its hue turned 60 degrees,
    as the old sapphire/mauve prompt was. A grey accent has no hue to turn, so
    it gets a darker grey instead."""
    rgb = [int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    h, l, s = colorsys.rgb_to_hls(*rgb)
    if max(rgb) - min(rgb) < 0.08:  # same chroma cutoff as extract_color()
        l -= 0.25
    else:
        h = (h + 60 / 360) % 1.0
    return "".join(f"{round(c * 255):02x}" for c in colorsys.hls_to_rgb(h, l, s))


def on_accent(hex_color):
    """Text colour for the accent: near-black on a bright accent, white otherwise.
    Same brightness test and threshold as the Graphite theme's on(), so GTK,
    Qt and the theme's own fallbacks agree."""
    r, g, b = (int(hex_color[i:i + 2], 16) for i in (0, 2, 4))
    return "111111" if (r * 299 + g * 587 + b * 114) / 1000 >= 156 else "ffffff"


def shift_lightness(hex_color, dl):
    """The accent with its HLS lightness moved by dl (clamped to 0..1)."""
    rgb = [int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    h, l, s = colorsys.rgb_to_hls(*rgb)
    return "".join(f"{round(c * 255):02x}" for c in colorsys.hls_to_rgb(h, min(1.0, max(0.0, l + dl)), s))


def write_atomic(path, content):
    with open(path + ".tmp", "w") as f:
        f.write(content)
    os.replace(path + ".tmp", path)


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
        write_atomic(path, new)


def rewrite_ini(path, values):
    """Set existing `key=value` lines per [section] ({section: {key: value}}).
    Keys repeat across sections in Kvantum's kvconfig, so a plain regex can't."""
    path = os.path.expanduser(path)
    if not os.path.isfile(path):
        return
    with open(path) as f:
        content = f.read()
    lines = content.split("\n")
    section = None
    for i, line in enumerate(lines):
        if line.startswith("[") and line.rstrip().endswith("]"):
            section = line.strip()[1:-1]
        elif "=" in line and section in values:
            key = line.split("=", 1)[0].strip()
            if key in values[section]:
                lines[i] = f"{key}={values[section][key]}"
    new = "\n".join(lines)
    if new != content:
        write_atomic(path, new)


def render(template, path, tokens):
    """Write TEMPLATE to PATH with each @TOKEN@ replaced, if it changed."""
    template, path = os.path.expanduser(template), os.path.expanduser(path)
    if not os.path.isfile(template):
        return
    with open(template) as f:
        new = f.read()
    for token, value in tokens.items():
        new = new.replace(f"@{token}@", value)
    try:
        with open(path) as f:
            if f.read() == new:
                return
    except OSError:
        pass
    write_atomic(path, new)


def apply(hex_color):
    """Push the color to Hyprland, hyprlock, hyprtoolkit, quickshell, GTK, Qt,
    yazi, neovim, starship, kitty and OpenRGB."""
    # LEDs first, fire-and-forget: openrgb_color.sh owns every OpenRGB detail
    # (SDK server fast path, Static/Direct per device, latest-wins locking).
    # Own session so it isn't tied to this short-lived process.
    subprocess.Popen([os.path.join(SCRIPT_DIR, "openrgb_color.sh"), hex_color],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)

    rewrite("~/.config/hypr/hyprlock.conf", [
        (r"^\$accent\s*=.*$", f"$accent   = rgb({hex_color})"),
        (r"^\$accentAlpha\s*=.*$", f"$accentAlpha = {hex_color}"),
    ])
    rewrite("~/.config/hypr/hyprtoolkit.conf", [
        (r"^accent\s*=.*$", f"accent = 0xFF{hex_color}"),
    ])
    # quickshell: set live over IPC, and persist for its next start (Theme.qml
    # reads ACCENT_STATE once on load). This used to rewrite Theme.qml and rely
    # on quickshell's hot-reload, which missed a write that landed while the
    # previous reload was still running — the bar kept the old colour in 5 of
    # 10 rapid-change trials. IPC is one property change, ~20ms, no reload.
    os.makedirs(os.path.dirname(ACCENT_STATE), exist_ok=True)
    with open(ACCENT_STATE + ".tmp", "w") as f:
        f.write(hex_color + "\n")
    os.replace(ACCENT_STATE + ".tmp", ACCENT_STATE)
    try:  # quickshell not running (or not installed) must not block the border
        subprocess.run(["qs", "ipc", "call", "theme", "setAccent", hex_color],
                       capture_output=True, timeout=2.0)
    except (OSError, subprocess.TimeoutExpired):
        pass
    # GTK: ~/.themes/Graphite-Dark is built by build_gtk_theme.py to read these
    # two at runtime, so new windows pick them up; open ones keep their colours.
    fg = on_accent(hex_color)
    for css in ("~/.config/gtk-3.0/gtk.css", "~/.config/gtk-4.0/gtk.css", "~/.config/gtk-4.0/gtk-dark.css"):
        rewrite(css, [
            (r"@define-color\s+accent_color\s+#[0-9a-fA-F]+;", f"@define-color accent_color #{hex_color};"),
            (r"@define-color\s+accent_bg_color\s+#[0-9a-fA-F]+;", f"@define-color accent_bg_color #{hex_color};"),
            (r"@define-color\s+accent_fg_color\s+#[0-9a-fA-F]+;", f"@define-color accent_fg_color #{fg};"),
        ])
    # Qt (Kvantum GraphiteDark, via qt6ct): the SVG is rendered from its .in
    # template, where the stock grey accent (#e0e0e0, focused #f2f2f2, pressed
    # #cccccc) is @ACCENT@/@ACCENT_LIGHT@/@ACCENT_DARK@ -- edit the template,
    # not the SVG. The kvconfig keys are the palette highlight and the text
    # drawn on accent fills. The qt6ct stylesheet overrides Kvantum's progress
    # bar, so its `/* accent */` line follows too. New Qt apps only.
    render("~/.config/Kvantum/Graphite/GraphiteDark.svg.in", "~/.config/Kvantum/Graphite/GraphiteDark.svg", {
        "ACCENT": f"#{hex_color}",
        "ACCENT_LIGHT": f"#{shift_lightness(hex_color, 0.07)}",
        "ACCENT_DARK": f"#{shift_lightness(hex_color, -0.08)}",
    })
    rewrite_ini("~/.config/Kvantum/Graphite/GraphiteDark.kvconfig", {
        "GeneralColors": {"highlight.color": f"#{hex_color}", "inactive.highlight.color": f"#{hex_color}",
                          "highlight.text.color": f"#{fg}"},
        "PanelButtonCommand": {"text.toggle.color": f"#{fg}"},
        "PanelButtonTool": {"text.toggle.color": f"#{fg}"},
        "ItemView": {"text.press.color": f"#{fg}"},
        "MenuItem": {"text.focus.color": f"#{fg}"},
    })
    rewrite("~/.config/qt6ct/qss/hyprblur-round.qss", [
        (r"#[0-9a-fA-F]{6};([ \t]*/\* accent \*/)", rf"#{hex_color};\g<1>"),
    ])
    # neovim: chadrc reads ACCENT_STATE, but base46 draws from a compiled cache,
    # so each running nvim recompiles via ~/.config/nvim/lua/accent.lua. It
    # re-reads ACCENT_STATE itself, so order doesn't matter. New instances
    # recompile at startup if the cache is stale. One at a time, so no two
    # write the shared cache at once; a dead socket fails in milliseconds.
    for sock in sorted(glob.glob(os.path.join(RUNTIME_DIR, "nvim.*.0"))):
        try:
            subprocess.run(["nvim", "--server", sock, "--remote-expr", "v:lua.require'accent'.reload()"],
                           capture_output=True, stdin=subprocess.DEVNULL, timeout=2.0)
        except (OSError, subprocess.TimeoutExpired):
            pass
    # starship re-reads its config every prompt, so the file is all it needs.
    # The prompt icon is the accent and the ❯ its companion (see companion()).
    rewrite("~/.config/starship.toml", [
        (r'^accent[ \t]*=[ \t]*"#[0-9a-fA-F]{6}"[ \t]*$', f'accent = "#{hex_color}"'),
        (r'^accent2[ \t]*=[ \t]*"#[0-9a-fA-F]{6}"[ \t]*$', f'accent2 = "#{companion(hex_color)}"'),
    ])
    # kitty: cursor only. kitty auto-reloads kitty.conf on change; SIGUSR1 is
    # its documented reload, sent too in case the watcher misses os.replace().
    rewrite("~/.config/kitty/kitty.conf", [
        (r"^cursor[ \t]+#[0-9a-fA-F]{6}[ \t]*$", f"cursor                  #{hex_color}"),
    ])
    kitty_pids = subprocess.run(["pgrep", "-u", str(os.getuid()), "-x", "kitty"],
                                capture_output=True, text=True).stdout.split()
    for pid in kitty_pids:
        try:
            os.kill(int(pid), signal.SIGUSR1)
        except (OSError, ValueError):
            pass
    # yazi: only lines tagged `# accent: fg|bg` in theme.toml, and only that key
    # on each, so the #111111 text on accent badges stays dark. Yazi can't reload
    # its theme live; new instances get the colour.
    rewrite("~/.config/yazi/theme.toml", [
        (rf'^(.*\b{key} = ")#[0-9a-fA-F]{{6}}(".*#\s*accent: {key}\s*)$', rf"\g<1>#{hex_color}\g<2>")
        for key in ("fg", "bg")
    ])

    # Grouped windows draw group.col.border_active instead of the general border,
    # so it gets the same gradient; the active tab's indicator line takes the accent too.
    border = f'{{ colors = {{ "rgba({hex_color}ee)", "rgba({hex_color}00)" }}, angle = 45 }}'
    lua = (f"hl.config({{ general = {{ col = {{ active_border = {border} }} }}, "
           f"group = {{ col = {{ border_active = {border} }}, "
           f'groupbar = {{ col = {{ active = "rgba({hex_color}ff)" }} }} }} }})')
    subprocess.run(["hyprctl", "eval", lua], capture_output=True, timeout=2.0)


def claim_token():
    """Mark this run as the newest one; returns its token."""
    token = f"{os.getpid()}-{time.monotonic_ns()}"
    with open(TOKEN_FILE, "w") as f:
        f.write(token)
    return token


def is_latest(token):
    """False if a newer run started while this one was extracting."""
    try:
        with open(TOKEN_FILE) as f:
            return f.read() == token
    except OSError:
        return True


def main():
    parser = argparse.ArgumentParser(description="Sync Hyprland border and accents to the wallpaper color.")
    parser.add_argument("image", nargs="?", help="wallpaper to analyze (default: current awww wallpaper)")
    parser.add_argument("-d", "--dry-run", action="store_true", help="print the color without applying it")
    args = parser.parse_args()

    token = None if args.dry_run else claim_token()
    image = args.image or current_wallpaper()
    if image and not os.path.isfile(image):
        sys.exit(f"sync_border: no such file: {image}")
    hex_color, reason = extract_color(image) if image else (PLATINUM, "no wallpaper detected")

    if args.dry_run:
        print(f"{image or '-'}: #{hex_color} ({reason})")
    else:
        with open(LOCK_FILE, "w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            if is_latest(token):
                apply(hex_color)


if __name__ == "__main__":
    main()
