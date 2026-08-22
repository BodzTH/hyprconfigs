#!/usr/bin/env bash
# =============================================================================
# CachyOS Hyprland Environment Bootstrap
# =============================================================================
# One-command full setup script to restore packages, shells, and services.
# Run after: chezmoi init --apply <github-username>
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

# Fallback to ~/.config/packages if running outside repo
if [ ! -d "$PACKAGES_DIR" ] && [ -d "$HOME/.config/packages" ]; then
    PACKAGES_DIR="$HOME/.config/packages"
fi

# 2. Synchronize package databases
log_info "Synchronizing pacman package databases..."
sudo pacman -Sy --noconfirm

# 3. Install packages category by category
log_info "Installing categorized packages from $PACKAGES_DIR..."
for manifest in "$PACKAGES_DIR"/*.txt; do
    [ -e "$manifest" ] || continue
    category="$(basename "$manifest" .txt)"
    log_info "Installing category: ${BOLD}$category${RESET}"
    sudo pacman -S --needed --noconfirm - < "$manifest"
done
log_success "All package categories installed successfully."

# 4. Refresh Font Cache
log_info "Updating system font cache..."
fc-cache -f &>/dev/null || true
log_success "Font cache refreshed."

# 5. Configure Default Shell
FISH_PATH="$(which fish 2>/dev/null || echo "/usr/bin/fish")"
if [ "$SHELL" != "$FISH_PATH" ] && [ -x "$FISH_PATH" ]; then
    log_info "Changing default user shell to fish ($FISH_PATH)..."
    sudo chsh -s "$FISH_PATH" "$USER" || chsh -s "$FISH_PATH" || log_warn "Could not change shell automatically. Run: chsh -s $FISH_PATH"
    log_success "Default shell set to fish."
fi

# 6. Enable Essential Services
log_info "Enabling core system services..."
sudo systemctl enable --now NetworkManager.service 2>/dev/null || true
sudo systemctl enable --now bluetooth.service 2>/dev/null || true
sudo systemctl enable --now sddm.service 2>/dev/null || true

log_info "Enabling user audio/portal services..."
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true

# 7. Apply Chezmoi Configurations
if command -v chezmoi &>/dev/null; then
    log_info "Re-applying chezmoi dotfiles..."
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
