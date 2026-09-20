#!/usr/bin/env bash
# Per-machine setup for this Hyprland config. Idempotent — safe to re-run.
#
# The Lua config is portable and needs nothing installed. This script handles the
# one part that is machine-local state rather than config: enabling the systemd
# user units that graphical-session.target pulls in at login.
#
# graphical-session.target itself is started by hyprland-session.target, which
# modules/autostart.lua triggers on hyprland.start. Hyprland 0.56.2 does not do
# this on its own -- see the comment block in systemd/hyprland-session.target.
#
# Run once on every new host:   ~/.config/hypr/scripts/bootstrap.sh

set -euo pipefail

UNIT_SRC="$HOME/.config/hypr/systemd"
UNIT_DST="$HOME/.config/systemd/user"

ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
skip() { printf '  \033[90m·\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }

echo "▓▒░ Linking units from ${UNIT_SRC/#$HOME/\~}"
mkdir -p "$UNIT_DST"
for unit in "$UNIT_SRC"/*.service "$UNIT_SRC"/*.target; do
    name=$(basename "$unit")
    if [ -L "$UNIT_DST/$name" ] && [ "$(readlink -f "$UNIT_DST/$name")" = "$unit" ]; then
        skip "$name already linked"
    elif [ -e "$UNIT_DST/$name" ] && [ ! -L "$UNIT_DST/$name" ]; then
        warn "$name exists as a real file — leaving it alone"
        continue
    else
        ln -sfn "$unit" "$UNIT_DST/$name"
        ok "linked $name"
    fi
done

systemctl --user daemon-reload

# Units this config owns, plus the ones shipped by their own packages. Anything
# not installed on this host is skipped rather than failing the run — that is what
# keeps the script portable across desktop and laptop.
echo
echo "▓▒░ Enabling units"
UNITS=(
    quickshell.service        # bar, launcher, clipboard, notifications
    awww-daemon.service       # wallpaper daemon
    cliphist-text.service     # clipboard history — text
    cliphist-image.service    # clipboard history — images
    hypridle.service          # idle management (package-provided)
    hyprpolkitagent.service   # polkit agent (package-provided)
    gcr-ssh-agent.socket      # ssh agent; SSH_AUTH_SOCK set in modules/environment.lua
)
for unit in "${UNITS[@]}"; do
    if ! systemctl --user cat "$unit" >/dev/null 2>&1; then
        warn "${unit%%.*} not installed — skipped"
    elif [ "$(systemctl --user is-enabled "$unit" 2>/dev/null)" = "enabled" ]; then
        skip "$unit already enabled"
    # `enable` must be tested as an elif condition, not run as `enable && ok`:
    # under `set -e` a failing AND-list exits the whole script mid-run with no
    # message. As a condition, a failure just falls through to the warn below.
    elif systemctl --user enable "$unit" >/dev/null 2>&1; then
        ok "enabled $unit"
    else
        warn "could not enable $unit — continuing"
    fi
done

echo
echo "▓▒░ Done. Units start with graphical-session.target at next login."
echo "    (started via hyprland-session.target from modules/autostart.lua)"
echo "    Check with:  systemctl --user status quickshell"
