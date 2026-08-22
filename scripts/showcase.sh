#!/usr/bin/env bash
# =============================================================================
# Automated Showcase Screenshot Generator for README
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$REPO_DIR/assets/screenshots"
mkdir -p "$OUT_DIR"

if ! command -v grim &>/dev/null; then
    echo "Error: grim is required for capturing screenshots."
    exit 1
fi

FOCUSED_MONITOR="$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name' 2>/dev/null || echo "")"

if [ -z "$FOCUSED_MONITOR" ]; then
    echo "Capturing full screen..."
    grim "$OUT_DIR/preview.png"
else
    echo "Capturing focused monitor ($FOCUSED_MONITOR)..."
    grim -o "$FOCUSED_MONITOR" "$OUT_DIR/preview.png"
fi

echo "✓ Showcase screenshot saved to: $OUT_DIR/preview.png"
echo "  Commit and push to GitHub to update your README."
