#!/usr/bin/env python3
"""
Build ~/.themes/Graphite-Dark's GTK 3/4 CSS with the wallpaper accent.

Stock Graphite bakes one of nine preset accents into its CSS at compile time,
so sync_border.py's `@define-color accent_color` reached almost nothing. This
builds vinceliuice/Graphite-gtk-theme (dark, standard, `--tweaks black` -- the
variant installed before, byte-identical GTK3 CSS) with the "blue" preset
replaced by the literal `@accent_color`. Sass can't do colour maths on that,
so each colour builtin goes through a wrapper that calls the builtin for real
colours and, for the accent, emits GTK's runtime alpha()/mix()/shade(). GTK
then resolves @accent_color and @accent_fg_color (text on the accent) from
~/.config/gtk-{3,4}.0/gtk.css, which sync_border.py rewrites.

Checked 2026-09-23 at the pinned commit: compiling stock twice with two
different blues, every line that differs is @accent-based here (0 missed, GTK3
and GTK4), and both files parse in Gtk.CssProvider with 0 errors. Only the
slider tick-mark PNGs keep a fixed colour.

Usage: build_gtk_theme.py [--commit REF] [--dest DIR]
Needs git and sassc. Only gtk-3.0/ and gtk-4.0/ CSS in DEST are replaced.
"""

import argparse
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile

REPO = "https://github.com/vinceliuice/Graphite-gtk-theme.git"
COMMIT = "364173f47407164948788e4abb5e2eb46600f71a"  # 2026-08-24

WRAPPERS = r"""
// --- runtime accent (patched in by ~/.config/hypr/scripts/build_gtk_theme.py)
@function _is-color($c) { @return type-of($c) == 'color'; }
@function _frac($w) { @if (unit($w) == '%') { @return $w / 100%; } @return $w; }

@function crgba($args...) {
  @if (length($args) == 2 and not _is-color(nth($args, 1))) {
    @return unquote("alpha(#{nth($args, 1)}, #{nth($args, 2)})");
  }
  @return rgba($args...);
}
@function ctransparentize($c, $t) {
  @if _is-color($c) { @return transparentize($c, $t); }
  @return unquote("alpha(#{$c}, #{1 - $t})");
}
@function copacify($c, $t) {
  @if _is-color($c) { @return opacify($c, $t); }
  @return $c;
}
// sass mix(a, b, w) = w*a + (1-w)*b; GTK mix(a, b, f) = (1-f)*a + f*b
@function cmix($a, $b, $w: 50%) {
  @if (_is-color($a) and _is-color($b)) { @return mix($a, $b, $w); }
  @return unquote("mix(#{$b}, #{$a}, #{_frac($w)})");
}
// shade() scales HLS lightness; sync_border.py keeps the accent near L=0.6,
// so +p% of lightness is roughly a factor of 1 + p/60.
@function clighten($c, $p) {
  @if _is-color($c) { @return lighten($c, $p); }
  @return unquote("shade(#{$c}, #{1 + _frac($p) / 0.6})");
}
@function cdarken($c, $p) {
  @if _is-color($c) { @return darken($c, $p); }
  @return unquote("shade(#{$c}, #{1 - _frac($p) / 0.6})");
}
@function cdesaturate($c, $p) {
  @if _is-color($c) { @return desaturate($c, $p); }
  @return $c;
}
@function csaturate($c, $p) {
  @if _is-color($c) { @return saturate($c, $p); }
  @return $c;
}
// Text on the accent: @accent_fg_color (black or white, picked by
// sync_border.py) at the alphas on() uses for white text.
@function accent-on($state) {
  $a: map-get(('primary': 1, 'secondary': 0.7, 'disabled': 0.5, 'secondary-disabled': 0.3,
               'track': 0.3, 'track-disabled': 0.12, 'divider': 0.12,
               'secondary-fill': 0.08, 'fill': 0.04), $state);
  @if ($a == 1) { @return unquote("@accent_fg_color"); }
  @return unquote("alpha(@accent_fg_color, #{$a})");
}
// ------------------------------------------------------------------------
"""

BUILTINS = ("rgba", "transparentize", "opacify", "mix", "lighten", "darken", "desaturate", "saturate")
CALL = re.compile(r"(?<![\w$@-])(" + "|".join(BUILTINS) + r")\(")


def wrap_calls(text):
    return CALL.sub(lambda m: "c" + m.group(1) + "(", text)


def patch(src):
    """Make the checkout's blue preset the runtime @accent_color."""
    colors_path = os.path.join(src, "src/sass/_colors.scss")
    with open(colors_path) as f:
        c = f.read()
    c, n = re.subn(r"^\$theme_blue_color:.*$", '$theme_blue_color:    unquote("@accent_color");',
                   c, count=1, flags=re.M)
    assert n == 1, "$theme_blue_color not found -- upstream changed, re-check the patch"
    head, sep, body = c.partition("@import 'color-palette';\n")
    assert sep, "color-palette import not found"
    body = wrap_calls(body)
    # Helpers that inspect the colour itself need a branch for the accent.
    for old, new in (
        ("@function on($color, $state: 'primary') {",
         "@function on($color, $state: 'primary') {\n"
         "  @if (not _is-color($color) and $color != 'light' and $color != 'dark') { @return accent-on($state); }"),
        ("@function highlight($color) {",
         "@function highlight($color) {\n"
         "  @if not _is-color($color) { @return rgba(white, 0.2); }"),
    ):
        assert old in body, f"not found: {old}"
        body = body.replace(old, new, 1)
    with open(colors_path, "w") as f:
        f.write(head + sep + WRAPPERS + body)

    for path in glob.glob(os.path.join(src, "src/sass/gtk/**/*.scss"), recursive=True):
        with open(path) as f:
            t = f.read()
        new = wrap_calls(t)
        if path.endswith("_colors-public.scss"):
            # These would read "@define-color accent_color @accent_color;", a
            # loop. Fallbacks only: ~/.config/gtk-{3,4}.0/gtk.css overrides them.
            new, k = re.subn(r"^@define-color accent_(bg_|fg_)?color .*$",
                             lambda m: f"@define-color accent_{m.group(1) or ''}color "
                                       f"{'white' if m.group(1) == 'fg_' else '#5294e2'};",
                             new, flags=re.M)
            assert k == 3, "accent public colours not found"
        if new != t:
            with open(path, "w") as f:
                f.write(new)


def main():
    parser = argparse.ArgumentParser(description="Build Graphite-Dark GTK CSS with a runtime accent.")
    parser.add_argument("--commit", default=COMMIT, help=f"upstream ref (default: pinned {COMMIT[:12]})")
    parser.add_argument("--dest", default=os.path.expanduser("~/.themes/Graphite-Dark"))
    args = parser.parse_args()

    with tempfile.TemporaryDirectory(prefix="graphite-") as work:
        src, out = os.path.join(work, "src"), os.path.join(work, "out")
        subprocess.run(["git", "clone", "-q", REPO, src], check=True)
        subprocess.run(["git", "-C", src, "checkout", "-q", args.commit], check=True)
        patch(src)
        os.makedirs(out)
        # install.sh also compiles gnome-shell and cinnamon, which the patch
        # doesn't cover and which fail on the accent string. Unused here, so
        # their errors are only shown if the GTK CSS didn't build either.
        log = subprocess.run([os.path.join(src, "install.sh"), "-d", out, "-c", "dark", "-s", "standard",
                              "-t", "blue", "--tweaks", "black"],
                             cwd=src, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True).stderr
        built = os.path.join(out, "Graphite-blue-Dark")
        if not all(os.path.isfile(os.path.join(built, v, "gtk.css")) for v in ("gtk-3.0", "gtk-4.0")):
            sys.exit(f"build_gtk_theme: GTK CSS not built\n{log}")
        for v in ("gtk-3.0", "gtk-4.0"):
            os.makedirs(os.path.join(args.dest, v), exist_ok=True)
            for name in ("gtk.css", "gtk-dark.css"):
                shutil.copyfile(os.path.join(built, v, name), os.path.join(args.dest, v, name))
                print(f"{os.path.join(args.dest, v, name)}")


if __name__ == "__main__":
    main()
