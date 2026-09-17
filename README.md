# CachyOS Hyprland Environment — Dotfiles

> Modular, reproducible, and hardware-portable **Onyx & Platinum** monochrome Hyprland desktop environment powered by **Chezmoi** and **Lua**.

![Desktop Showcase](assets/screenshots/preview.png)

---

This repo configures the **desktop environment only**: Hyprland, the shell, theming, and the
SDDM greeter. It assumes a working Arch-family install with its own bootloader already in
place — it does not install or modify one. `system/boot/` carries this machine's limine config
as reference documentation, never applied automatically (see [System Files](#system-files-not-in-home)).

## Quick Start & Reproduction

To reproduce this exact environment on any Arch-based Linux installation (CachyOS, Arch, EndeavourOS, etc.):

```bash
# 1. Install chezmoi and git
sudo pacman -S --needed chezmoi git

# 2. Initialize and apply dotfiles
chezmoi init --apply BodzTH/hyprconfigs

# 3. Run the bootstrap script to install all packages and enable services
~/.local/share/chezmoi/scripts/bootstrap.sh
```

---

## System & Application Stack

| Component | Choice | Description |
| :--- | :--- | :--- |
| **Compositor** | [Hyprland](https://hyprland.org/) | Modular Lua configuration (`hyprland.lua`) |
| **Session Manager** | [UWSM](https://github.com/Vladimir-csp/uwsm) | Universal Wayland Session Manager with systemd integration |
| **Greeter** | [SDDM](https://github.com/sddm/sddm) | Custom `hypr-sddm` theme (fork of sddm-astronaut), autologin into Hyprland |
| **Status Bar & UI** | [QuickShell](https://quickshell.outfoxxed.me/) | Custom QML bar, app launcher, clipboard, and notifications |
| **Terminal** | [Kitty](https://sw.kovidgoyal.net/kitty/) | Default terminal everywhere (Ghostty also installed, not default) |
| **Shell** | [Fish](https://fishshell.com/) | Modular `conf.d/` + `functions/` with [Starship](https://starship.rs/) prompt |
| **Editor** | [Neovim](https://neovim.io/) | Custom [NvChad](https://nvchad.com/) setup with Treesitter & LSP |
| **File Manager** | [Yazi](https://yazi-rs.github.io/) | Blazing fast terminal file manager |
| **Wallpaper** | [awww](https://github.com/awww-project/awww) | Dynamic wallpaper daemon with smooth transitions |
| **Lock Screen** | [hyprlock](https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/) | Onyx & Platinum minimal lock screen |
| **Idle Daemon** | [hypridle](https://wiki.hypr.land/Hypr-Ecosystem/hypridle/) | Automated screen blanking & DPMS |
| **Theming** | Onyx & Platinum | Monochrome palette with Catppuccin Mocha Dark cursors |

`hypr/scripts/sync_border.py` watches the active wallpaper and rewrites the accent color into `hyprlock.conf`, `hyprtoolkit.conf`, and the `gtk-3.0`/`gtk-4.0` CSS on every change. The repo tracks those files with the static `#e5e5e5` accent as a seed — a live diff there after the daemon runs is expected, not drift.

---

## Hardware Portability System

This repository dynamically adapts to different hardware configurations (monitors, GPUs, device sensitivities) without polluting common configs.

### 1. Hyprland Host Profiles (`~/.config/hypr/hosts/`)
Hyprland automatically queries the machine hostname at startup and loads `~/.config/hypr/hosts/<hostname>.lua`. If no profile exists, it seamlessly falls back to `~/.config/hypr/hosts/default.lua`.

```
~/.config/hypr/hosts/
├── init.lua              # Dynamic host profile loader
├── default.lua           # Sane fallback (auto display detection)
└── hyprcachyos.lua       # Main desktop profile (1080p@165Hz, G305 flat accel, app paths)
```

#### Adding a New Machine (e.g., Laptop):
Create `~/.config/hypr/hosts/<your-hostname>.lua`:
```lua
return {
    monitors = {
        -- "preferred" picks the panel's native mode -- no need to hardcode a
        -- resolution/refresh rate you'd have to look up per machine.
        { output = "eDP-1", mode = "preferred", position = "auto", scale = 1 },
        -- Catch-all: any docked/external display, auto-placed to the right.
        { output = "",      mode = "preferred", position = "auto", scale = 1 },
    },
    apps = {},
    devices = {
        { name = "synps/2-synaptics-touchpad", sensitivity = 0.2 },
    },
}
```

### 2. Environment Variables & GPU Profiles (`~/.config/uwsm/`)
UWSM environment files are managed with Chezmoi Go templates (`dot_config/uwsm/env.tmpl` and `dot_config/uwsm/env-hyprland.tmpl`). The GPU vendor is detected automatically at `chezmoi init` time by reading `/sys/class/drm/*/device/vendor` (discrete beats integrated on hybrid setups); it's cached in `~/.config/chezmoi/chezmoi.toml`, so re-run `chezmoi init` after swapping GPUs.
- **AMD**: Activates RADV, `radeonsi`, DXVK device filter, and dual-GPU AQ_DRM_DEVICES.
- **NVIDIA**: Activates `nvidia-drm`, `__GLX_VENDOR_LIBRARY_NAME=nvidia`, and `NVD_BACKEND=direct`.
- **Intel**: Activates `iHD` VA-API drivers.

---

## Categorized Package Manifests

Packages are split into logical manifests in `packages/`:

| Manifest | Purpose |
| :--- | :--- |
| `10-hyprland.txt` | Hyprland ecosystem, QuickShell, SDDM, screen capture (`grim`, `slurp`, `satty`), daemons |
| `20-apps.txt` | User GUI & CLI applications (Firefox, Obsidian, OBS, Inkscape, Neovim, etc.) |
| `30-shell.txt` | Fish, Git, Starship, Yazi, Bat, Eza, Fzf, Ripgrep, Zoxide, Btop |
| `40-terminals.txt` | Ghostty and Kitty |
| `50-fonts.txt` | Adwaita, Cantarell, Noto, Cascadia Code Nerd Font |
| `60-audio-media.txt` | Pipewire, Wireplumber, ALSA, GStreamer codecs |
| `70-theming.txt` | Kvantum, Qt6ct, Nwg-look, GTK stylesheets |
| `80-gpu-amd.txt` / `80-gpu-intel.txt` / `80-gpu-nvidia.txt` | GPU driver stack — `bootstrap.sh` installs only the one matching the detected vendor |
| `90-networking.txt` | NetworkManager, Bluetooth, OpenSSH, UFW |
| `95-extra.txt` | Spellcheck, mail, and account-services supplementary utilities |

Bootloader, kernel, and base-OS packages (limine, mkinitcpio, plymouth, `linux-*`, etc.) are
**not** in these manifests — that's the base install's job, done once before this repo comes
into play. **Not covered by the manifests** either (not packaged in the official repos, so
`bootstrap.sh` can't install them — set these up manually before applying): the
[Graphite GTK theme](https://github.com/vinceliuice/Graphite-gtk-theme) into
`~/.themes/Graphite-Dark`, and the `catppuccin-mocha-dark-cursors` cursor theme.

---

## Keybinding Highlights

| Keybinding | Action |
| :--- | :--- |
| <kbd>SUPER</kbd> + <kbd>T</kbd> | Launch Kitty terminal |
| <kbd>SUPER</kbd> + <kbd>E</kbd> | Launch Yazi file manager |
| <kbd>SUPER</kbd> + <kbd>F</kbd> | Launch Firefox |
| <kbd>SUPER</kbd> + <kbd>C</kbd> | Launch Neovim (NvChad) |
| <kbd>SUPER</kbd> + <kbd>A</kbd> | Toggle QuickShell App Launcher |
| <kbd>SUPER</kbd> + <kbd>Space</kbd> | Toggle QuickShell Wallpaper Selector |
| <kbd>SUPER</kbd> + <kbd>V</kbd> | Toggle QuickShell Clipboard Panel |
| <kbd>SUPER</kbd> + <kbd>Backspace</kbd> | Toggle QuickShell Power Menu |
| <kbd>SUPER</kbd> + <kbd>S</kbd> | Drop-down Scratchpad Terminal |
| <kbd>SUPER</kbd> + <kbd>N</kbd> | Drop-down Notes (Obsidian) |
| <kbd>SUPER</kbd> + <kbd>Shift</kbd> + <kbd>W</kbd> | Transition Wallpaper (`awww`) |
| <kbd>F11</kbd> | Fast region screenshot → clipboard (`grim` + `slurp`) |
| <kbd>F12</kbd> | Annotate screenshot (`grim` + `slurp` + `satty`) |

---

## System Files (not in `$HOME`)

Chezmoi only manages `$HOME`. A handful of files live outside it — the SDDM greeter and the
bootloader config — and are tracked separately under `system/`, `.chezmoiignore`'d so chezmoi
never tries to apply them into `~/system/...`.

```
system/
├── etc/sddm.conf                          # autologin, hypr-sddm theme, cursor
├── etc/default/limine                     # reference only — this machine's ESP path/cmdline
├── boot/limine.conf.header                # reference only — never written to /boot
└── usr/share/sddm/themes/hypr-sddm/       # custom greeter theme (fork of sddm-astronaut)
```

- **`etc/sddm.conf`** and **`usr/share/sddm/themes/hypr-sddm/`** are installed by
  `scripts/bootstrap.sh` (`sudo install`/`cp`, same pattern as the package manifests). The
  theme's `Backgrounds/` isn't vendored — bootstrap copies `street.gif` and `black_bg.jpg` in
  from `Pictures/Wallpapers/` on every run, so the wallpaper stays in one place.
- **`boot/limine.conf.header`** and **`etc/default/limine`** are **reference only**. Nothing in
  this repo writes to `/boot` or runs `limine-install`/`limine-enroll-config` — copy them by
  hand on a fresh machine, and change the `root=UUID=` line to that disk's actual UUID first.
  The header's boot wallpaper is `Pictures/Wallpapers/white_mountain.png`, already tracked
  elsewhere in the repo — copy it to the ESP as `limine_bg.png` rather than duplicating it here.

---

## Dotfiles Management Cheatsheet

```bash
# Check modified files against repo
chezmoi status
chezmoi diff

# Edit a managed file
chezmoi edit ~/.config/hypr/hyprland.lua

# Add a newly created configuration file
chezmoi add ~/.config/newapp/config

# Re-apply repository state to the system
chezmoi apply

# Commit and push changes to GitHub
chezmoi cd
git add .
git commit -m "Update configurations"
git push
```

---

## Updating the Showcase Screenshot

Whenever you update your wallpaper or styling, run:
```bash
~/.local/share/chezmoi/scripts/showcase.sh
chezmoi cd && git commit -am "Update preview screenshot" && git push
```
