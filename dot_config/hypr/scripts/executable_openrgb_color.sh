#!/usr/bin/env bash
# Set every OpenRGB device to one colour. Usage: openrgb_color.sh RRGGBB
#
# The single place that talks to OpenRGB — sync_border.py (wallpaper accent)
# and pick_rgb.fish (SUPER+SHIFT+P) both call this.
#
# Fast path: the openrgb-server.service SDK server already holds the devices,
# so `--nodetect` skips hardware detection and the colour lands in
# milliseconds. Without the server it falls back to standalone detection
# (~4s per call) — slow, but correct.
#
# Mode per device: Static where the device has it (stored in the device, so it
# survives OpenRGB exiting), Direct otherwise. A blanket `-m static` fails on
# Direct-only devices with "Mode 'static' not available", so the mode is read
# from the device list rather than assumed.
#
# Devices with their own vendor software are excluded in OpenRGB itself, not
# here: the Skyloong keyboard's detectors are switched off in
# ~/.config/OpenRGB/OpenRGB.json (Detectors -> "Skyloong ...": false), so
# OpenRGB never opens it and can't fight the keyboard's own lighting.
#
# Latest wins: calls are serialised with flock, and a call that finds a newer
# colour requested while it waited exits without applying — rapid wallpaper
# changes can no longer land out of order and leave a stale colour.

set -u
hex="${1#\#}"
[[ "$hex" =~ ^[0-9a-fA-F]{6}$ ]] || { echo "usage: $0 RRGGBB" >&2; exit 2; }
command -v openrgb >/dev/null || exit 0

state="${XDG_RUNTIME_DIR:-/tmp}/openrgb-color"
echo "$hex" > "$state.want"

exec 9> "$state.lock"
flock 9
[ "$(cat "$state.want" 2>/dev/null)" = "$hex" ] || exit 0   # superseded

server_up() { ss -ltn 2>/dev/null | grep -q ':6742 '; }

# At login the server may still be detecting; give it a moment before
# falling back to the slow path.
if ! server_up && systemctl --user -q is-active openrgb-server.service 2>/dev/null; then
    for _ in $(seq 50); do server_up && break; sleep 0.1; done
fi

# The server opens its port before detection finishes. Measured 2026-09-23:
# port at ~0.1s, 1 device at 1.0s, all 3 only at 3.5s — with a 2.4s gap in
# between, so "wait until the count stops changing" stops too early. A client
# arriving in that window (the login-time wallpaper sync does) sees a partial
# list and colours only some devices. So a call made while the server is
# younger than DETECT_US waits out the remainder first; later calls pay nothing.
DETECT_US=6000000
server_age_us() {
    local started now
    started=$(systemctl --user show -P ActiveEnterTimestampMonotonic openrgb-server.service 2>/dev/null)
    [[ "$started" =~ ^[0-9]+$ && "$started" -gt 0 ]] || { echo "$DETECT_US"; return; }
    # CLOCK_MONOTONIC, the clock systemd's *Monotonic stamps use — not
    # /proc/uptime, which also counts time spent suspended.
    now=$(python3 -c 'import time; print(time.monotonic_ns() // 1000)')
    echo $(( now - started ))
}

if server_up; then
    age=$(server_age_us)
    if (( age < DETECT_US )); then
        sleep "$(awk -v us=$(( DETECT_US - age )) 'BEGIN { printf "%.2f", us / 1000000 }')"
    fi
fi

# Re-check after that wait. At login two sync_border.py runs start together
# (hyprland.start and config.reloaded): the early one can run before awww
# restore and send Platinum or a stale colour. The first check above passed
# before the wait, so that colour reached the LEDs ~200ms ahead of the accent.
[ "$(cat "$state.want" 2>/dev/null)" = "$hex" ] || exit 0   # superseded

if server_up; then
    base=(openrgb --nodetect)
else
    base=(openrgb --noautoconnect)
fi

# `-ld` prints "N: name" then "  Modes: ..." per device; build -d/-m/-c args.
# "Static" as a whole mode name, bare or [active]. In a POSIX bracket
# expression `]` must come first to be literal, hence `[] ]`.
static_re='(^|[[ ])Static($|[] ])'
args=()
idx=""
while IFS= read -r line; do
    if [[ "$line" =~ ^([0-9]+):\  ]]; then
        idx="${BASH_REMATCH[1]}"
    elif [[ -n "$idx" && "$line" =~ ^\ \ Modes: ]]; then
        if [[ "$line" =~ $static_re ]]; then mode=static; else mode=direct; fi
        args+=(-d "$idx" -m "$mode" -c "$hex")
        idx=""
    fi
done < <("${base[@]}" -ld 2>/dev/null)

[ ${#args[@]} -gt 0 ] || exit 0

# The CLI puts the colour on the wire ~33ms after it starts, then idles ~1s
# before exiting (timestamped with -vv, 2026-09-23). Holding the lock through
# that idle second made every quick follow-up change queue for a full second.
# So the CLI runs in the background and the lock is held only SEND_GRACE — ~5x
# the measured send time. The next change's CLI therefore starts after this
# colour is already sent, which keeps them in order; the idle tail is harmless.
SEND_GRACE=0.15
# 9>&-: the child must not inherit the lock fd, or the lock lives as long as
# the CLI's idle second and nothing is gained.
"${base[@]}" "${args[@]}" >/dev/null 2>&1 9>&- &
disown
sleep "$SEND_GRACE"
