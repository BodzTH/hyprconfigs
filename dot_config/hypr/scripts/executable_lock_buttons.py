#!/usr/bin/env python3
"""
Hover and keyboard control for hyprlock's sleep / reboot / shutdown buttons.

hyprlock 0.9.6 has `onclick` on labels but no hover state and no keybinds, so
this fakes both. Each button is a label whose text is
`cmd[update:0:1] lock_buttons.py NAME ACCENT`:

  label mode   prints the icon — accent if NAME is lit, white otherwise —
               and starts the watcher if this hyprlock doesn't have one yet.
  watch mode   one per hyprlock, exits with it. Polls the cursor over
               Hyprland's socket (~30 Hz, no forks) and takes keyboard commands
               on a datagram socket. Only when the lit buttons change does it
               record them and send hyprlock SIGUSR2, which re-runs the three
               `:1` labels. So the lock screen forks nothing while idle.
  key mode     run by the lock-screen submap binds (modules/keybindings.lua):
               next / prev / activate / clear, forwarded to the watcher.
  run mode     a button's action — hyprlock's onclick and Enter both land here.

Keyboard: the watcher puts Hyprland in the "lockscreen" submap (←/→ bound),
and in "lockscreen-armed" (Enter and Esc bound too) only while an arrow-key
selection exists, so Enter submits the password otherwise. Any other key drops
the selection. A hovered button is lit but never armed: Enter with the mouse
resting on shutdown still just submits the password. On exit the submap is
reset; if the watcher dies without that, the submap's catch-all heals it.

The geometry below must match the three `label` blocks in hyprlock.conf.

Usage: lock_buttons.py NAME ACCENT        (label mode, run by hyprlock)
       lock_buttons.py --watch PID        (watch mode, started by label mode)
       lock_buttons.py key PID CMD        (key mode, run by the submap binds)
       lock_buttons.py run NAME           (run mode)
"""

import fcntl
import json
import os
import select
import signal
import socket
import subprocess
import sys
import time

# NAME: (icon, x offset from the screen's centre, action). Order is ←/→ order.
# Offsets must match the label positions in hyprlock.conf.
BUTTONS = {
    "sleep":    ("\uf4ee", -100, ["systemctl", "suspend"]),
    "reboot":   ("󰜉", 0, ["systemctl", "reboot"]),
    "shutdown": ("󰐥", 100, ["systemctl", "poweroff"]),
}
NAMES = list(BUTTONS)
BOTTOM = 60      # label `position` y, valign = bottom
# Hover box, centred on the glyph and kept inside the label's clickable box
# (Pango extents of " ICON " at 26pt: 60x42) so "lit" always means "a click
# lands". All pixel values are physical pixels, like hyprlock's own layout.
HIT_W = 56
HIT_H = 40
GLYPH_Y = 21     # glyph centre above the label's bottom edge (measured at 26pt)
WHITE = "e5e5e5"
POLL = 1 / 30
SUBMAP, SUBMAP_ARMED = "lockscreen", "lockscreen-armed"

RUNTIME = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"


def hyprlock_pid():
    """The hyprlock this process descends from (label commands run under sh)."""
    pid = os.getppid()
    while pid > 1:
        try:
            with open(f"/proc/{pid}/stat") as f:
                stat = f.read()
        except OSError:
            return None
        # comm is parenthesised and may contain spaces; ppid follows it
        comm = stat[stat.index("(") + 1:stat.rindex(")")]
        if comm == "hyprlock":
            return pid
        pid = int(stat[stat.rindex(")") + 2:].split()[1])
    return None


def paths(pid):
    base = os.path.join(RUNTIME, f"hyprlock-buttons.{pid}")
    return base, base + ".lock", base + ".sock"


def hyprctl(sock_path, cmd):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.settimeout(1.0)
        s.connect(sock_path)
        s.sendall(cmd.encode())
        chunks = []
        while chunk := s.recv(65536):
            chunks.append(chunk)
    return json.loads(b"".join(chunks))


def set_submap(pid, submap):
    """lockbuttons.enter() is defined in modules/keybindings.lua; it records the
    pid its catch-all checks, then switches submap."""
    pid_lua = "nil" if submap == "reset" else str(pid)
    try:
        subprocess.run(["hyprctl", "eval", f'lockbuttons.enter({pid_lua}, "{submap}")'],
                       capture_output=True, timeout=2.0)
    except (OSError, subprocess.TimeoutExpired):
        pass


def hovered(cursor, monitors):
    """The button under the cursor, or "". The cursor arrives in logical
    layout coordinates, but hyprlock lays widgets out in physical pixels (a
    nested test at scale 2 drew them at the same pixel size and offset as at
    scale 1), so the cursor is converted to the monitor's pixels first."""
    for m in monitors:
        w, h = m["width"], m["height"]
        if m["transform"] % 2:
            w, h = h, w
        px = (cursor["x"] - m["x"]) * m["scale"]
        py = (cursor["y"] - m["y"]) * m["scale"]
        if not (0 <= px < w and 0 <= py < h):
            continue
        gy = h - BOTTOM - GLYPH_Y
        for name, (_, dx, _) in BUTTONS.items():
            if abs(px - (w / 2 + dx)) <= HIT_W / 2 and abs(py - gy) <= HIT_H / 2:
                return name
        return ""
    return ""


def watch(pid):
    state, lock, cmd_path = paths(pid)
    lock_fd = os.open(lock, os.O_CREAT | os.O_RDWR, 0o600)
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return  # another label already started one
    # SIGTERM/SIGHUP must still run the finally below, or the submap sticks.
    for s in (signal.SIGTERM, signal.SIGHUP):
        signal.signal(s, lambda *_: sys.exit(0))

    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    sock_path = os.path.join(RUNTIME, "hypr", sig, ".socket.sock")
    cmds = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    try:
        os.unlink(cmd_path)
    except OSError:
        pass
    cmds.bind(cmd_path)

    hover, selected = "", ""
    lit, armed = None, None  # what hyprlock and Hyprland were last told
    monitors, monitors_at = [], 0.0
    try:
        while True:
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                break
            try:
                now = time.monotonic()
                if now - monitors_at > 1.0:  # hotplug while locked
                    monitors, monitors_at = hyprctl(sock_path, "j/monitors"), now
                hover = hovered(hyprctl(sock_path, "j/cursorpos"), monitors)
            except (OSError, ValueError, KeyError):
                hover = ""

            ready, _, _ = select.select([cmds], [], [], 0)
            while ready:
                cmd = cmds.recv(64).decode(errors="replace")
                if cmd in ("next", "prev"):
                    step = 1 if cmd == "next" else -1
                    base = selected or hover
                    if base:
                        selected = NAMES[(NAMES.index(base) + step) % len(NAMES)]
                    else:
                        selected = NAMES[0] if step == 1 else NAMES[-1]
                elif cmd == "activate" and selected:
                    target, selected = selected, ""
                    # Disarm before acting, so Enter after waking from
                    # suspend goes to the password field again.
                    set_submap(pid, SUBMAP)
                    armed = False
                    subprocess.Popen([sys.executable, os.path.abspath(__file__), "run", target],
                                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                     stderr=subprocess.DEVNULL, start_new_session=True)
                elif cmd == "clear":
                    selected = ""
                ready, _, _ = select.select([cmds], [], [], 0)

            now_lit = " ".join(n for n in NAMES if n in (hover, selected))
            if now_lit != lit:
                with open(state + ".tmp", "w") as f:
                    f.write(now_lit)
                os.replace(state + ".tmp", state)
                os.kill(pid, signal.SIGUSR2)
                lit = now_lit
            if bool(selected) != armed:
                armed = bool(selected)
                set_submap(pid, SUBMAP_ARMED if armed else SUBMAP)

            select.select([cmds], [], [], POLL)  # sleep, but wake for a key
    finally:
        set_submap(pid, "reset")
        cmds.close()
        for p in (state, lock, cmd_path):
            try:
                os.unlink(p)
            except OSError:
                pass


def key(pid, cmd):
    with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as s:
        try:
            s.sendto(cmd.encode(), paths(pid)[2])
        except OSError:
            pass  # no watcher: the submap's catch-all resets it


def label(name, accent):
    icon = BUTTONS[name][0]
    pid = hyprlock_pid()
    lit = []
    if pid:
        state, lock, _ = paths(pid)
        try:
            with open(state) as f:
                lit = f.read().split()
        except OSError:
            pass
        # A free lock means no watcher yet. Several labels may race here; the
        # watcher's own flock lets exactly one survive.
        try:
            fd = os.open(lock, os.O_CREAT | os.O_RDWR, 0o600)
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            os.close(fd)
            subprocess.Popen([sys.executable, os.path.abspath(__file__), "--watch", str(pid)],
                             stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True)
        except BlockingIOError:
            pass
    color = accent if name in lit else WHITE
    # Padded both sides: Nerd glyphs overhang their cell and get clipped on the
    # right without a trailing space, and the leading one keeps the glyph on the
    # label's centre. It also widens the click target.
    print(f'<span foreground="#{color}"> {icon} </span>')


if __name__ == "__main__":
    args = sys.argv[1:]
    if len(args) == 2 and args[0] == "--watch":
        watch(int(args[1]))
    elif len(args) == 3 and args[0] == "key":
        key(int(args[1]), args[2])
    elif len(args) == 2 and args[0] == "run" and args[1] in BUTTONS:
        cmd = BUTTONS[args[1]][2]
        os.execvp(cmd[0], cmd)
    elif len(args) == 2 and args[0] in BUTTONS:
        label(args[0], args[1])
    else:
        sys.exit(__doc__)
