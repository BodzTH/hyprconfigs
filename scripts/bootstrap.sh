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

# 2. Bring the system up to date. A bare -Sy followed by -S is a partial
#    upgrade, which Arch does not support and which can break library links.
log_info "Upgrading the system (pacman -Syu)..."
sudo pacman -Syu --noconfirm

# 3. Detect GPU vendor (needed to pick the right 80-gpu-*.txt manifest below)
#    and the display name; `chezmoi init` asks for the name once per machine.
GPU="none"
DISPLAY_NAME="$USER"
if command -v chezmoi &>/dev/null; then
    chezmoi init    # regenerates chezmoi.toml (re-runs GPU detection)
    GPU="$(chezmoi execute-template '{{ .gpu }}')"
    DISPLAY_NAME="$(chezmoi execute-template '{{ .displayName }}')"
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
if [ "$GPU" = "none" ]; then
    log_warn "No AMD/Intel/NVIDIA GPU found (VM?), skipping driver install."
elif [ -e "$GPU_MANIFEST" ]; then
    log_info "Installing category: ${BOLD}80-gpu-$GPU${RESET}"
    sudo pacman -S --needed --noconfirm - < "$GPU_MANIFEST"
else
    log_warn "No GPU manifest for '$GPU', skipping driver install."
fi
log_success "All package categories installed successfully."

# 5. Themes that aren't in the Arch repos, fetched from upstream. Skipped when
#    already present, so re-runs don't touch a theme you've customised.
if [ -d "$HOME/.themes/Graphite-Dark" ]; then
    log_info "Graphite-Dark GTK theme already installed."
else
    log_info "Installing Graphite-Dark GTK theme into ~/.themes..."
    tmp="$(mktemp -d)"
    # --tweaks black: the near-black #0F0F0F variant HyprBlur is built on.
    # No -l/--libadwaita: that symlinks the theme over ~/.config/gtk-4.0/gtk.css,
    # which chezmoi manages (it @imports the theme instead).
    if git clone --quiet --depth 1 https://github.com/vinceliuice/Graphite-gtk-theme "$tmp/graphite" \
        && "$tmp/graphite/install.sh" -c dark --tweaks black -d "$HOME/.themes" >/dev/null; then
        log_success "Graphite-Dark installed."
    else
        log_warn "Graphite-Dark install failed; GTK apps fall back to Adwaita."
    fi
    rm -rf "$tmp"
fi

CURSOR_THEME="catppuccin-mocha-dark-cursors"
if [ -d "$HOME/.local/share/icons/$CURSOR_THEME" ] || [ -d "/usr/share/icons/$CURSOR_THEME" ]; then
    log_info "$CURSOR_THEME already installed."
else
    log_info "Installing $CURSOR_THEME into ~/.local/share/icons..."
    mkdir -p "$HOME/.local/share/icons"
    # bsdtar (libarchive, a pacman dependency) reads zip; no unzip needed.
    if curl -fsSL "https://github.com/catppuccin/cursors/releases/latest/download/$CURSOR_THEME.zip" \
        | bsdtar -xf - -C "$HOME/.local/share/icons"; then
        log_success "$CURSOR_THEME installed."
    else
        log_warn "$CURSOR_THEME install failed; the default cursor is used instead."
    fi
fi

# 6. Refresh Font Cache
log_info "Updating system font cache..."
fc-cache -f &>/dev/null || true
log_success "Font cache refreshed."

# 7. Configure Default Shell
FISH_PATH="$(which fish 2>/dev/null || echo "/usr/bin/fish")"
if [ "$SHELL" != "$FISH_PATH" ] && [ -x "$FISH_PATH" ]; then
    log_info "Changing default user shell to fish ($FISH_PATH)..."
    sudo chsh -s "$FISH_PATH" "$USER" || chsh -s "$FISH_PATH" || log_warn "Could not change shell automatically. Run: chsh -s $FISH_PATH"
    log_success "Default shell set to fish."
fi

# 8. Install SDDM greeter (config + hypr-sddm theme; not covered by chezmoi/$HOME)
SDDM_SYSTEM_DIR="$REPO_DIR/system/usr/share/sddm/themes/hypr-sddm"
if [ -d "$SDDM_SYSTEM_DIR" ]; then
    log_info "Installing SDDM config and hypr-sddm greeter theme..."
    sudo install -Dm644 "$REPO_DIR/system/etc/sddm.conf" /etc/sddm.conf
    sudo cp -rT "$SDDM_SYSTEM_DIR" /usr/share/sddm/themes/hypr-sddm
    sudo install -Dm644 "$REPO_DIR/Pictures/Wallpapers/street.gif"   /usr/share/sddm/themes/hypr-sddm/Backgrounds/street.gif
    sudo install -Dm644 "$REPO_DIR/Pictures/Wallpapers/black_bg.jpg" /usr/share/sddm/themes/hypr-sddm/Backgrounds/black_bg.jpg
    # SDDM layers theme.conf.user over the theme's theme.conf: the per-machine
    # greeter header lives there, so the tracked theme stays generic.
    printf '[General]\nHeaderText="%s"\n' "${DISPLAY_NAME//\"/}" \
        | sudo install -Dm644 /dev/stdin /usr/share/sddm/themes/hypr-sddm/theme.conf.user
    log_success "SDDM greeter installed."
fi

# 9. Enable Essential Services
log_info "Enabling core system services..."
sudo systemctl enable --now NetworkManager.service 2>/dev/null || true
sudo systemctl enable --now bluetooth.service 2>/dev/null || true
sudo systemctl enable sddm.service  # no --now: starting it here would take over the screen mid-bootstrap

log_info "Enabling user audio/portal services..."
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true

# 10. Apply Chezmoi Configurations
if command -v chezmoi &>/dev/null; then
    log_info "Applying chezmoi dotfiles..."
    chezmoi apply --force
    log_success "Dotfiles applied."
fi

# 11. Hyprland session units (quickshell, wallpaper, clipboard, idle, polkit).
#     chezmoi apply runs this too when the units change, but the first apply
#     predates the packages above, so the package-provided units were skipped.
HYPR_BOOTSTRAP="$HOME/.config/hypr/scripts/bootstrap.sh"
if [ -x "$HYPR_BOOTSTRAP" ]; then
    log_info "Linking and enabling Hyprland session user units..."
    "$HYPR_BOOTSTRAP" || log_warn "Unit setup incomplete; re-run $HYPR_BOOTSTRAP after logging in."
fi

echo -e "\n${GREEN}${BOLD}====================================================${RESET}"
echo -e "${GREEN}${BOLD}   Setup Complete!                                  ${RESET}"
echo -e "${GREEN}${BOLD}====================================================${RESET}\n"
echo -e "Reboot to log into Hyprland via SDDM."
echo -e "To customize hardware profile for this machine:"
echo -e "  1. Copy:       ${BOLD}~/.config/hypr/hosts/default.lua${RESET} to ${BOLD}hosts/$(cat /proc/sys/kernel/hostname).lua${RESET}"
echo -e "  2. Edit it, then track it: ${BOLD}chezmoi add ~/.config/hypr/hosts/$(cat /proc/sys/kernel/hostname).lua${RESET}\n"
