#!/usr/bin/env python3
"""
Data for the keybind cheatsheet (panels/Cheatsheet.qml). Prints one JSON
document: {"categories": [...], "rows": [...]}.

Sources, all read live so the sheet never drifts from the real config:
  Hyprland  `hyprctl binds -j`. Each description is "Category: Action" (see the
            bind() helper in ~/.config/hypr/modules/keybindings.lua); runnable
            rows are run with `hyprctl eval 'cheatsheet.run(mask, "key")'`.
  Panels    keys inside quickshell's own panels — hand-listed below from the
            panels' Keys handlers, since QML exposes no keymap to read.
  Neovim    every mapping with a description, dumped from a headless nvim
            (-V1 makes nvim record each mapping's source file, which is how
            "yours" is told apart from NvChad's). ~1.5s, so it is cached and
            only redone when a file under ~/.config/nvim changes.
  Yazi      the built-in [mgr] keymap, parsed out of the yazi binary (the
            preset is embedded, not shipped as a file), with your keymap.toml
            prepends layered on top. Cached per yazi binary + keymap.toml.
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tomllib

HOME = os.path.expanduser("~")
CACHE_DIR = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.join(HOME, ".cache"), "quickshell", "cheatsheet")
NVIM_DIR = os.path.join(HOME, ".config", "nvim")
YAZI_KEYMAP = os.path.join(HOME, ".config", "yazi", "keymap.toml")

CATEGORIES = [
    {"id": "Apps",       "icon": "󰀻"},
    {"id": "Panels",     "icon": "󰕮"},
    {"id": "Windows",    "icon": "󰖯"},
    {"id": "Workspaces", "icon": "󰍹"},
    {"id": "Capture",    "icon": "󰹑"},
    {"id": "Media",      "icon": "󰝚"},
    {"id": "System",     "icon": "󰒓"},
    {"id": "Neovim",     "icon": "\uf36f"},   # nf-linux-neovim (escaped: the literal glyph was lost once)
    {"id": "Yazi",       "icon": "󰉋"},
]

# ▓▒░ HYPRLAND ────────────────────────────────────────────────────────────────

MOD_ORDER = [(64, "SUPER"), (4, "CTRL"), (8, "ALT"), (1, "SHIFT")]
ARROWS = {"left": "←", "right": "→", "up": "↑", "down": "↓"}
HYPR_KEYS = {
    "Return": "Enter", "Space": "Space", "space": "Space", "Backspace": "Backspace",
    "BackSpace": "Backspace", "Tab": "Tab", "grave": "`", "comma": ",", "period": ".",
    "bracketleft": "[", "bracketright": "]", "Print": "Print", "Escape": "Esc",
    "mouse:272": "Left drag", "mouse:273": "Right drag",
    "mouse_down": "Scroll ↓", "mouse_up": "Scroll ↑",
    "XF86AudioRaiseVolume": "Vol +", "XF86AudioLowerVolume": "Vol −",
    "XF86AudioMute": "Mute", "XF86AudioMicMute": "Mic mute",
    "XF86MonBrightnessUp": "Bright +", "XF86MonBrightnessDown": "Bright −",
    "XF86AudioNext": "Next", "XF86AudioPrev": "Prev",
    "XF86AudioPlay": "Play", "XF86AudioPause": "Pause",
}
DIRECTION_WORDS = {"left", "right", "up", "down"}


def hypr_key_label(key):
    if key in HYPR_KEYS:
        return HYPR_KEYS[key]
    if key in ARROWS:
        return ARROWS[key]
    return key.upper() if len(key) == 1 else key


def mods_of(mask):
    return [name for bit, name in MOD_ORDER if mask & bit]


def hyprland_rows():
    try:
        binds = json.loads(subprocess.run(["hyprctl", "binds", "-j"], capture_output=True,
                                          text=True, timeout=3).stdout)
    except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError):
        return []

    # Group binds that differ only by a trailing direction word or number, or
    # that share an identical title (Play / Pause) — one row each.
    groups, order = {}, []
    for b in binds:
        desc = b.get("description") or ""
        cat, _, title = desc.partition(": ")
        if not title or cat not in {c["id"] for c in CATEGORIES}:
            cat, title = "System", desc or b["key"]
        words = title.split(" ")
        tail = words[-1].lower()
        variant = tail if (tail in DIRECTION_WORDS or tail.isdigit()) and len(words) > 1 else None
        base = " ".join(words[:-1]) if variant else title
        gkey = (cat, b["modmask"], base)
        if gkey not in groups:
            groups[gkey] = []
            order.append(gkey)
        groups[gkey].append((b, title, variant))

    rows = []
    # Panel-opening binds sit above the in-panel keys, under their own header.
    group_of = {"Panels": "Open a panel"}
    for gkey in order:
        cat, mask, base = gkey
        members = groups[gkey]
        first = members[0][0]
        mods = mods_of(mask)
        is_mouse = first["key"].startswith("mouse:")
        if len(members) == 1:
            b, title, _ = members[0]
            rows.append({
                "cat": cat, "group": group_of.get(cat, ""), "title": title,
                "subtitle": flags_text(b),
                "keys": mods + [hypr_key_label(b["key"])],
                "run": None if is_mouse else {"mask": mask, "key": b["key"]},
            })
            continue
        variants = [v for _, _, v in members]
        keys = [m[0]["key"] for m in members]
        if all(v and v.isdigit() for v in variants):
            nums = sorted(int(v) for v in variants)
            title = f"{base} {nums[0]}–{nums[-1]}"
            by_num = sorted(members, key=lambda m: int(m[2]))
            chip = f"{hypr_key_label(by_num[0][0]['key'])}–{hypr_key_label(by_num[-1][0]['key'])}"
        elif all(v in DIRECTION_WORDS for v in variants):
            title = base
            if all(k in ARROWS for k in keys):   # always ←→↑↓, whatever the file order
                chip = "".join(ARROWS[k] for k in ARROWS if k in keys)
            else:
                chip = " / ".join(hypr_key_label(k) for k in keys)
        else:
            title = base
            chip = " / ".join(hypr_key_label(k) for k in keys)
        # A series has no single action to run; identical titles (Play / Pause) do.
        same_action = all(v is None for v in variants)
        rows.append({
            "cat": cat, "group": group_of.get(cat, ""), "title": title,
            "subtitle": f"{len(members)} binds" + (" · " + flags_text(first) if flags_text(first) else ""),
            "keys": mods + [chip],
            "run": {"mask": mask, "key": first["key"]} if same_action and not is_mouse else None,
        })
    return rows


def flags_text(b):
    flags = []
    if b.get("locked"):
        flags.append("works when locked")
    if b.get("repeat"):
        flags.append("repeats")
    return " · ".join(flags)


# ▓▒░ QUICKSHELL PANELS ──────────────────────────────────────────────────────
# Keys handled *inside* panels. Taken from each panel's Keys.* handlers; keep
# in step when a panel's keys change.

PANEL_KEYS = [
    ("App launcher", [("Move selection", ["↑↓"]), ("Launch app", ["Enter"])]),
    ("Clipboard history", [("Move selection", ["↑↓"]), ("Copy entry to the clipboard", ["Enter"])]),
    ("Wallpaper selector", [("Move selection", ["←→↑↓"]), ("Set wallpaper", ["Enter"])]),
    ("Window overview", [("Select window", ["←→↑↓"]), ("Select next / previous", ["Tab / Shift+Tab"]),
                         ("Focus selected window", ["Enter"]), ("Jump to workspace", ["1–0"])]),
    ("Power menu", [("Move selection", ["←→↑↓"]), ("Confirm", ["Enter"])]),
    ("Screenshot panel", [("Move selection", ["←→↑↓"]), ("Confirm", ["Enter"])]),
    ("Calendar", [("Previous / next month", ["← / →"])]),
    ("Bar (after SUPER+B)", [("Move between widgets", ["Tab / Shift+Tab"]), ("Activate widget", ["Enter / Space"]),
                             ("Volume on the audio / mic widget", ["↑↓"]), ("Leave the bar", ["Esc"])]),
    ("Network panel", [("Move between rows", ["Tab / ↑↓"]), ("Toggle / connect / expand", ["Enter / Space"]),
                       ("Connect with typed password", ["Enter"])]),
    ("Notifications", [("Toggle Do Not Disturb", ["Right-click bell"]), ("Open from the clock", ["Right-click clock"])]),
    ("This cheatsheet", [("Search", ["type"]), ("Move selection", ["↑↓"]), ("Next / previous category", ["Tab / Shift+Tab"]),
                         ("Run bind, or copy keys", ["Enter"]), ("Clear search, then close", ["Esc"])]),
    ("Every panel", [("Close", ["Esc"])]),
]


def panel_rows():
    rows = []
    for panel, entries in PANEL_KEYS:
        for title, keys in entries:
            rows.append({"cat": "Panels", "group": f"Inside: {panel}", "title": title,
                         "subtitle": "", "keys": keys, "run": None})
    return rows


# ▓▒░ NEOVIM ─────────────────────────────────────────────────────────────────

NVIM_DUMP = r"""
vim.defer_fn(function()
  local out, seen = {}, {}
  for _, mode in ipairs({ "n", "i", "x", "s", "o", "t", "c" }) do
    for _, k in ipairs(vim.api.nvim_get_keymap(mode)) do
      if k.desc and k.desc ~= "" and not k.lhs:match("^<Plug>") then
        local src = ""
        if k.sid and k.sid > 0 then
          local info = vim.fn.getscriptinfo({ sid = k.sid })[1]
          src = info and info.name or ""
        end
        local id = k.lhs .. "\0" .. k.desc
        if seen[id] then
          table.insert(seen[id].modes, mode)
        else
          seen[id] = { lhs = k.lhs, desc = k.desc, src = src, modes = { mode } }
          table.insert(out, seen[id])
        end
      end
    end
  end
  io.stdout:write(vim.json.encode(out))
  vim.cmd("qa!")
end, 300)
"""

MODE_NAMES = {"n": "normal", "i": "insert", "x": "visual", "s": "select", "o": "operator",
              "t": "terminal", "c": "command"}
NVIM_SPECIAL = {"CR": "Enter", "Esc": "Esc", "Tab": "Tab", "BS": "Backspace", "Space": "Space",
                "Up": "↑", "Down": "↓", "Left": "←", "Right": "→", "leader": "Space"}


def newest_mtime(root):
    newest = 0.0
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d != ".git"]
        for f in filenames:
            try:
                newest = max(newest, os.path.getmtime(os.path.join(dirpath, f)))
            except OSError:
                pass
    return newest


def cached(name, stamp, build):
    """Return build()'s result, reusing the cache while `stamp` is unchanged."""
    path = os.path.join(CACHE_DIR, name + ".json")
    try:
        with open(path) as f:
            data = json.load(f)
        if data.get("stamp") == stamp:
            return data["rows"]
    except (OSError, ValueError, KeyError):
        pass
    rows = build()
    if rows:
        os.makedirs(CACHE_DIR, exist_ok=True)
        with open(path + ".tmp", "w") as f:
            json.dump({"stamp": stamp, "rows": rows}, f)
        os.replace(path + ".tmp", path)
    return rows


def vim_keys(lhs):
    """'<C-S>' -> ['Ctrl+S'], ' ff' -> ['Space', 'f', 'f'], '<S-M-Down>' -> ['Shift+Alt+↓']."""
    chips = []
    for tok in re.findall(r"<[^<>]+>|.", lhs):
        if tok == " ":
            chips.append("Space")
        elif tok.startswith("<") and len(tok) > 2:
            parts = tok[1:-1].split("-")
            key = NVIM_SPECIAL.get(parts[-1], parts[-1])
            mods = [{"C": "Ctrl", "M": "Alt", "A": "Alt", "S": "Shift", "D": "Super"}.get(p.upper(), p) for p in parts[:-1]]
            chips.append("+".join(mods + [key]))
        else:
            chips.append(tok)
    return chips


def build_nvim():
    if not shutil.which("nvim"):
        return []
    try:
        out = subprocess.run(["nvim", "--headless", "-V1", "-c", "lua " + NVIM_DUMP.replace("\n", " ")],
                             capture_output=True, text=True, timeout=20, cwd=HOME).stdout
        maps = json.loads(out[out.index("["):])
    except (OSError, subprocess.TimeoutExpired, ValueError):
        return []
    rows = []
    for m in maps:
        src = m["src"]
        if src.startswith(NVIM_DIR):
            group, rank = "Yours", 0
        # Built-ins report a pseudo-path like "vim/_core/defaults", not a
        # runtime file, so match that as well as a real runtime path.
        elif not src or "/runtime/" in src or "vim/_core/" in src:
            group, rank = "Neovim built-in", 2
        else:
            group, rank = "NvChad & plugins", 1
        modes = " · ".join(MODE_NAMES.get(x, x) for x in m["modes"])
        lhs = m["lhs"]
        copy = ("<leader>" + lhs[1:]) if lhs.startswith(" ") else lhs
        rows.append({"cat": "Neovim", "group": group, "rank": rank, "title": m["desc"],
                     "subtitle": modes, "keys": vim_keys(lhs), "run": None, "copy": copy})
    rows.sort(key=lambda r: r.pop("rank"))
    return rows


# ▓▒░ YAZI ───────────────────────────────────────────────────────────────────

def yazi_default_keymap():
    """The [mgr] keymap preset, cut out of the yazi binary's embedded strings."""
    yazi = shutil.which("yazi")
    out = subprocess.run(["strings", "-n", "1", yazi], capture_output=True, text=True).stdout.splitlines()
    start = next(i for i in range(len(out) - 1) if out[i] == "[mgr]" and out[i + 1].startswith("keymap = ["))
    end = start + 1
    while not out[end].startswith("]"):
        end += 1
    return tomllib.loads("\n".join(out[start:end + 1]))["mgr"]["keymap"]


def yazi_keys(on):
    seq = on if isinstance(on, list) else [on]
    chips = []
    for tok in seq:
        m = re.fullmatch(r"<(.+)>", tok)
        if m:
            parts = m.group(1).split("-")
            key = NVIM_SPECIAL.get(parts[-1], parts[-1])
            mods = [{"C": "Ctrl", "A": "Alt", "S": "Shift", "D": "Super"}.get(p, p) for p in parts[:-1]]
            chips.append("+".join(mods + [key]))
        else:
            chips.append(tok)
    return chips


def build_yazi():
    if not shutil.which("yazi"):
        return []
    try:
        defaults = yazi_default_keymap()
    except (OSError, StopIteration, tomllib.TOMLDecodeError, KeyError):
        defaults = []
    try:
        with open(YAZI_KEYMAP, "rb") as f:
            mine = tomllib.load(f).get("mgr", {}).get("prepend_keymap", [])
    except (OSError, tomllib.TOMLDecodeError):
        mine = []

    def on_id(on):
        return tuple(on) if isinstance(on, list) else (on,)

    overridden = {on_id(k["on"]) for k in mine}
    rows = []
    for group, entries in (("Yours", mine), ("Defaults", [k for k in defaults if on_id(k["on"]) not in overridden])):
        for k in entries:
            if not k.get("desc"):
                continue
            seq = k["on"] if isinstance(k["on"], list) else [k["on"]]
            rows.append({"cat": "Yazi", "group": group, "title": k["desc"], "subtitle": "",
                         "keys": yazi_keys(k["on"]), "run": None, "copy": " ".join(seq)})
    return rows


def yazi_stamp():
    parts = []
    for p in (shutil.which("yazi"), YAZI_KEYMAP):
        try:
            parts.append(f"{p}:{os.path.getmtime(p)}")
        except (OSError, TypeError):
            parts.append(f"{p}:-")
    return "|".join(parts)


def main():
    rows = hyprland_rows() + panel_rows()
    rows += cached("nvim", str(newest_mtime(NVIM_DIR)), build_nvim)
    rows += cached("yazi", yazi_stamp(), build_yazi)
    json.dump({"categories": CATEGORIES, "rows": rows}, sys.stdout, ensure_ascii=False)


if __name__ == "__main__":
    main()
