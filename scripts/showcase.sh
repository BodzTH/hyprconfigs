#!/usr/bin/env bash
# Capture the desktop as the README preview image, then commit and push it.
# Bound to SUPER+Print: close every window first, then press it. Refuses to
# capture while windows are open, so a cluttered shot is never pushed.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="assets/screenshots/preview.png"

notify() { notify-send "Showcase" "$1" 2>/dev/null || true; echo "$1"; }
trap 'notify "Failed — run showcase.sh from a terminal to see why."' ERR

if [ "$(hyprctl clients -j | jq length)" -gt 0 ]; then
    notify "Close all windows first, then press SUPER+Print."
    exit 1
fi

MONITOR=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
grim -o "$MONITOR" "$REPO_DIR/$IMAGE"

# Commit only the screenshot, so unrelated uncommitted work is never swept in
git -C "$REPO_DIR" add "$IMAGE"
if git -C "$REPO_DIR" diff --cached --quiet -- "$IMAGE"; then
    notify "Screenshot unchanged, nothing to commit."
    exit 0
fi
git -C "$REPO_DIR" commit -q -m "docs: update showcase screenshot" -- "$IMAGE"
git -C "$REPO_DIR" push -q
notify "Preview updated and pushed to GitHub."
