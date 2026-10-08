#!/usr/bin/env python3
"""The icon Firefox itself shows for a tab, for the taskbar and overview
(services/AppIconService.qml). For every page title given, prints

    TITLE<TAB>PATH

where PATH is that page's favicon, written once to ~/.cache/quickshell/favicons.
Titles with no page or no icon print nothing.

A window title is all Hyprland knows of a tab, so the page is found in
Firefox's history by title (the most recent visit), and its icon in Firefox's
favicon store: the same icon the tab strip shows, as the site itself serves it.

Firefox holds both databases locked while it runs and keeps recent writes in
the -wal files, so they're copied, WAL and all, to a RAM-backed folder and read
there (a few ms for ~10 MB).
"""
import configparser
import hashlib
import os
import re
import shutil
import sqlite3
import sys

CACHE = os.path.expanduser("~/.cache/quickshell/favicons")
SNAP = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "quickshell-favicons")
ROOTS = [os.path.expanduser("~/.config/mozilla/firefox"), os.path.expanduser("~/.mozilla/firefox")]


def profile():
    """The default profile's folder: the install's Default=, else Default=1."""
    for root in ROOTS:
        ini = configparser.ConfigParser(interpolation=None)
        if not ini.read(os.path.join(root, "profiles.ini")):
            continue
        paths = [ini[s]["Default"] for s in ini if s.startswith("Install") and "Default" in ini[s]]
        paths += [ini[s]["Path"] for s in ini
                  if s.startswith("Profile") and ini[s].get("Default") == "1" and "Path" in ini[s]]
        for p in paths:
            full = p if os.path.isabs(p) else os.path.join(root, p)
            if os.path.exists(os.path.join(full, "places.sqlite")):
                return full
    return None


def snapshot(prof, name):
    os.makedirs(SNAP, exist_ok=True)
    for suffix in ("", "-wal"):
        src, dst = os.path.join(prof, name + suffix), os.path.join(SNAP, name + suffix)
        if os.path.exists(src):
            shutil.copyfile(src, dst)
        elif os.path.exists(dst):
            os.remove(dst)  # a stale WAL would be replayed onto the new copy
    return sqlite3.connect(os.path.join(SNAP, name))


def luminance(hexcolor):
    h = hexcolor.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def dark_svg(data):
    """An SVG drawn only in dark colours (GitHub's black Octocat) vanishes on
    the dark bar. Unpainted shapes default to black."""
    text = data.decode("utf-8", "replace")
    colors = re.findall(r"#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b", text)
    if re.search(r"\b(fill|stroke|stop-color)\s*[=:]\s*[\"']?\s*(white|currentColor)", text):
        return False
    return not colors or max(map(luminance, colors)) < 0.3


def is_svg(data):
    return data.lstrip()[:5] in (b"<svg ", b"<?xml") or b"<svg" in data[:300]


def pick(icons):
    """A light-enough SVG, else the largest raster (crisp at the bar's size)."""
    svgs = [d for _, w, d in icons if is_svg(d) and not dark_svg(d)]
    if svgs:
        return svgs[0]
    rasters = sorted(((w, d) for _, w, d in icons if not is_svg(d)), key=lambda t: t[0])
    return rasters[-1][1] if rasters else None


def extension(data):
    if is_svg(data):
        return ".svg"
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return ".png"
    if data[:3] == b"\xff\xd8\xff":
        return ".jpg"
    if data[:4] == b"\x00\x00\x01\x00":
        return ".ico"
    if data[:4] == b"GIF8":
        return ".gif"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return ".webp"
    return None


def save(data):
    ext = extension(data)
    if not ext:
        return None
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, hashlib.sha1(data).hexdigest()[:16] + ext)
    if not os.path.exists(path):
        tmp = path + ".tmp"
        with open(tmp, "wb") as f:
            f.write(data)
        os.replace(tmp, path)
    return path


LATEST = " ORDER BY last_visit_date DESC LIMIT 1"
SEPARATORS = (" - ", " | ", " · ", " – ", " — ")


def page_url(places, title):
    """The most recently visited page with this title. Failing that:
      - without a "(3) " unread counter, which history doesn't keep
      - by its start, for a long title Firefox cut short in the window title
      - any page of the same site, from the name a title ends with
        ("New chat - Claude" → "… - Claude"), for a page history hasn't got yet
    """
    def one(sql, arg):
        row = places.execute("SELECT url FROM moz_places WHERE " + sql + LATEST, (arg,)).fetchone()
        return row[0] if row else None

    def like(text):
        return text.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")

    title = re.sub(r"^\(\d+\+?\)\s+", "", title)
    url = one("title = ?", title)
    if not url and len(title) >= 80:
        url = one("title LIKE ? ESCAPE '\\'", like(title) + "%")
    if not url:
        cut = max((title.rfind(sep), sep) for sep in SEPARATORS)
        if cut[0] > 0:
            site = title[cut[0] + len(cut[1]):]
            url = one("title = ?", site) or one("title LIKE ? ESCAPE '\\'", "%" + like(cut[1] + site))
    return url


def main(titles):
    prof = profile()
    if not prof or not titles:
        return
    places, favicons = snapshot(prof, "places.sqlite"), snapshot(prof, "favicons.sqlite")
    for title in titles:
        url = page_url(places, title)
        if not url:
            continue
        icons = favicons.execute(
            "SELECT i.icon_url, i.width, i.data FROM moz_pages_w_icons p"
            " JOIN moz_icons_to_pages ip ON ip.page_id = p.id"
            " JOIN moz_icons i ON i.id = ip.icon_id"
            " WHERE p.page_url = ? AND i.data IS NOT NULL", (url,)).fetchall()
        if not icons:
            # The site's own /favicon.ico, which Firefox keeps per origin.
            origin = re.match(r"^[a-z]+://[^/]+", url)
            if origin:
                icons = favicons.execute(
                    "SELECT icon_url, width, data FROM moz_icons"
                    " WHERE root = 1 AND icon_url LIKE ? AND data IS NOT NULL",
                    (origin.group(0) + "/%",)).fetchall()
        data = pick(icons)
        path = save(data) if data else None
        if path:
            print(f"{title}\t{path}")


if __name__ == "__main__":
    main([t for t in sys.argv[1:] if t])
