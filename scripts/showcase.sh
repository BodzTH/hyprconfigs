#!/usr/bin/env bash
# Capture a clean desktop (empty workspace, focused monitor) as the README
# preview image, then commit and push just that image.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="assets/screenshots/preview.png"

for cmd in grim hyprctl jq git; do
    command -v "$cmd" >/dev/null || { echo "Error: $cmd is required." >&2; exit 1; }
done

# Switch to an empty workspace, and always come back afterwards
# Optional delay (seconds) to close windows first: showcase.sh 5
notify() { notify-send "Showcase" "$1" 2>/dev/null || true; }
trap 'notify "Failed — run showcase.sh from a terminal to see why."' ERR
sleep "${1:-0}"

PREV=$(hyprctl activeworkspace -j | jq .id)
trap 'hyprctl dispatch "hl.dsp.focus({ workspace = $PREV })" >/dev/null' EXIT
hyprctl dispatch 'hl.dsp.focus({ workspace = "empty" })' >/dev/null
sleep 1  # let the workspace animation finish

MONITOR=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
mkdir -p "$REPO_DIR/$(dirname "$IMAGE")"
grim -o "$MONITOR" "$REPO_DIR/$IMAGE"
echo "✓ Captured $MONITOR -> $IMAGE"

# Commit only the screenshot, so unrelated uncommitted work is never swept in
git -C "$REPO_DIR" add "$IMAGE"
if git -C "$REPO_DIR" diff --cached --quiet -- "$IMAGE"; then
    echo "Screenshot unchanged, nothing to commit."
    notify "Screenshot unchanged, nothing to commit."
    exit 0
fi
git -C "$REPO_DIR" commit -m "docs: update showcase screenshot" -- "$IMAGE"
git -C "$REPO_DIR" push
echo "✓ Pushed to GitHub."
notify "Preview updated and pushed to GitHub."
