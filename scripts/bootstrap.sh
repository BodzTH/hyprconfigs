#!/usr/bin/env bash
# =============================================================================
# CachyOS Hyprland Environment Bootstrap
# =============================================================================
# One-command full setup script to restore packages, shells, and services.
# Run after: chezmoi init --apply BodzTH/hyprconfigs
# =============================================================================

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RESET='\033[0m'

log_info() {
    echo -e "${BLUE}${BOLD}[INFO]${RESET} $1"
}

log_success() {
    echo -e "${GREEN}${BOLD}[OK]${RESET} $1"
}

log_warn() {
    echo -e "${YELLOW}${BOLD}[WARN]${RESET} $1"
}

echo -e "\n${BOLD}====================================================${RESET}"
echo -e "${BOLD}   CachyOS Hyprland Environment Provisioner         ${RESET}"
echo -e "${BOLD}====================================================${RESET}\n"

# 1. Check pacman / CachyOS environment
if ! command -v pacman &>/dev/null; then
    echo "Error: pacman not found. This script requires an Arch/CachyOS system."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGES_DIR="$REPO_DIR/packages"

# Fallback to the chezmoi source directory if running outside the repo checkout
if [ ! -d "$PACKAGES_DIR" ] && command -v chezmoi &>/dev/null; then
    PACKAGES_DIR="$(chezmoi source-path)/packages"
fi

if [ ! -d "$PACKAGES_DIR" ]; then
    echo "Error: package manifests not found (looked in $PACKAGES_DIR)." >&2
    exit 1
fi

# 2. Synchronize package databases
log_info "Synchronizing pacman package databases..."
sudo pacman -Sy --noconfirm

# 3. Detect GPU vendor (needed to pick the right 80-gpu-*.txt manifest below)
GPU="amd"
if command -v chezmoi &>/dev/null; then
    chezmoi init    # regenerates chezmoi.toml (re-runs GPU detection)
    GPU="$(chezmoi execute-template '{{ .gpu }}')"
fi
log_info "Detected GPU vendor: ${BOLD}$GPU${RESET}"

# 4. Install packages category by category
log_info "Installing categorized packages from $PACKAGES_DIR..."
for manifest in "$PACKAGES_DIR"/*.txt; do
    [ -e "$manifest" ] || continue
    case "$(basename "$manifest")" in
        80-gpu-*.txt) continue ;;  # handled separately below, vendor-specific
    esac
    category="$(basename "$manifest" .txt)"
    log_info "Installing category: ${BOLD}$category${RESET}"
    sudo pacman -S --needed --noconfirm - < "$manifest"
done

GPU_MANIFEST="$PACKAGES_DIR/80-gpu-$GPU.txt"
if [ -e "$GPU_MANIFEST" ]; then
    log_info "Installing category: ${BOLD}80-gpu-$GPU${RESET}"
    sudo pacman -S --needed --noconfirm - < "$GPU_MANIFEST"
else
    log_warn "No GPU manifest for '$GPU', skipping driver install."
fi
log_success "All package categories installed successfully."

# 5. Refresh Font Cache
log_info "Updating system font cache..."
fc-cache -f &>/dev/null || true
log_success "Font cache refreshed."

# 6. Configure Default Shell
FISH_PATH="$(which fish 2>/dev/null || echo "/usr/bin/fish")"
if [ "$SHELL" != "$FISH_PATH" ] && [ -x "$FISH_PATH" ]; then
    log_info "Changing default user shell to fish ($FISH_PATH)..."
    sudo chsh -s "$FISH_PATH" "$USER" || chsh -s "$FISH_PATH" || log_warn "Could not change shell automatically. Run: chsh -s $FISH_PATH"
    log_success "Default shell set to fish."
fi

# 7. Install SDDM greeter (config + hypr-sddm theme; not covered by chezmoi/$HOME)
SDDM_SYSTEM_DIR="$REPO_DIR/system/usr/share/sddm/themes/hypr-sddm"
if [ -d "$SDDM_SYSTEM_DIR" ]; then
    log_info "Installing SDDM config and hypr-sddm greeter theme..."
    sudo install -Dm644 "$REPO_DIR/system/etc/sddm.conf" /etc/sddm.conf
    sudo cp -rT "$SDDM_SYSTEM_DIR" /usr/share/sddm/themes/hypr-sddm
    sudo install -Dm644 "$REPO_DIR/Pictures/Wallpapers/street.gif"   /usr/share/sddm/themes/hypr-sddm/Backgrounds/street.gif
    sudo install -Dm644 "$REPO_DIR/Pictures/Wallpapers/black_bg.jpg" /usr/share/sddm/themes/hypr-sddm/Backgrounds/black_bg.jpg
    log_success "SDDM greeter installed."
fi

# 8. Enable Essential Services
log_info "Enabling core system services..."
sudo systemctl enable --now NetworkManager.service 2>/dev/null || true
sudo systemctl enable --now bluetooth.service 2>/dev/null || true
sudo systemctl enable --now sddm.service

log_info "Enabling user audio/portal services..."
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true

# 9. Apply Chezmoi Configurations
if command -v chezmoi &>/dev/null; then
    log_info "Applying chezmoi dotfiles..."
    chezmoi apply --force
    log_success "Dotfiles applied."
fi

echo -e "\n${GREEN}${BOLD}====================================================${RESET}"
echo -e "${GREEN}${BOLD}   Setup Complete!                                  ${RESET}"
echo -e "${GREEN}${BOLD}====================================================${RESET}\n"
echo -e "You can now log into Hyprland via SDDM."
echo -e "To customize hardware profile for this machine:"
echo -e "  1. Check/edit: ${BOLD}~/.config/hypr/hosts/\$(hostname).lua${RESET}"
echo -e "  2. Edit:       ${BOLD}chezmoi edit ~/.config/uwsm/env${RESET}"
echo -e "  3. Apply:      ${BOLD}chezmoi apply${RESET}\n"
