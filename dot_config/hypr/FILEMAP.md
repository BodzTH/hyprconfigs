# File Map — `~/.config/hypr`

Where things live and what owns what. Companion to `context.md` (read that for the
architecture and the rules). Line counts are current as of 2026-09-21.

```
hyprland.lua              entry point — requires the 9 modules in dependency order
├── hosts/                per-machine profiles, selected by hostname
├── modules/              the config proper, one concern per file
├── scripts/              runtime helpers + per-host setup
├── systemd/              user units + session target (symlinked by scripts/bootstrap.sh)
├── *.conf                sibling hypr-ecosystem tools — hyprlang, NOT Lua
└── hyprwiki/             vendored Hyprland wiki, 120 files, reference only
```

## Load order

`hyprland.lua:18-26` requires modules in this order; dependencies must come first.

```
environment → monitors → appearance → animations → input
            → layouts → autostart → keybindings → windowrules
```

`variables.lua` and `hosts/` are not in that list — they are `require`d by the
modules that need them.

## Modules

| File | L | Owns | Reads |
|---|---:|---|---|
| `modules/environment.lua` | 100 | All `hl.env()`. GPU PCI→cardN resolver. Cursor, GTK, Qt, toolkit, `SSH_AUTH_SOCK`. Mesa gaming vars commented out. No vendor-specific vars — those are host `env` | `hosts` (`.gpu`, `.env`) |
| `modules/variables.lua` | 35 | App aliases — terminal, browser, editor, file manager | `hosts` (`.apps`) |
| `modules/monitors.lua` | 14 | Thin loop calling `hl.monitor()` | `hosts` (`.monitors`) |
| `modules/appearance.lua` | 92 | Borders, floating-window snap, rounding, blur, shadow, opacity, dim, render (`direct_scanout` commented out) | — |
| `modules/animations.lua` | 44 | 8 bezier curves, 17 animation leaves | — |
| `modules/input.lua` | 54 | Keyboard (`us,ara`), touchpad, cursor (gaming VRR lines commented out), gestures, per-device | `hosts` (`.devices`) |
| `modules/layouts.lua` | 71 | Dwindle, `misc` (incl. `font_family`, lock-restore), `binds`, `ecosystem` | — |
| `modules/autostart.lua` | 90 | Starts/stops `hyprland-session.target`; awww-socket-sequenced wallpaper restore + border sync | — |
| `modules/keybindings.lua` | 172 | Every bind. Largest file | `variables` |
| `modules/windowrules.lua` | 119 | Window/layer/workspace rules, smart gaps, quickshell blur, auth prompts keep focus, clipboard panel hidden from screenshare | — |

**There are exactly these 10 modules.** A consolidation into `session.lua` /
`look.lua` / `keys.lua` (plus a top-level `host.lua`) was started and purged on
2026-09-21 — it was never wired into `hyprland.lua`, and while it sat there
`input.lua` had already been switched to `require("host")`, so per-device config
came from a different file than everything else. One concern per file, and
`hosts/` is the only host profile loader. Don't reintroduce a merged module.

**`input` settings are no longer split.** `repeat_rate`, `repeat_delay` and
`follow_mouse_threshold` used to be duplicated in `layouts.lua`; every `input`
key now lives in `input.lua` alone, and `layouts.lua` carries a NOTE to keep it
that way.

## Hosts

| File | L | Notes |
|---|---:|---|
| `hosts/init.lua` | 34 | Reads `/proc/sys/kernel/hostname` (`hostname` binary as fallback), loads matching profile, falls back to `default` |
| `hosts/hyprcachyos.lua` | 56 | Main desktop. Acer VG240Y S matched by `desc:` at 1080p@165Hz + catch-all for other displays. RX 7700 XT `0000:03:00.0` + Raphael iGPU `0000:0e:00.0`, AMD vendor env (`DXVK_FILTER_DEVICE_NAME` commented out), G305 mouse |
| `hosts/laptop.lua` | 33 | Template. Rename to the laptop's hostname to activate. `gpu` and `LIBVA_DRIVER_NAME` commented out |
| `hosts/default.lua` | 17 | Fallback — empty everything, auto-detect |

Profile keys: `monitors`, `gpu` (PCI addresses, primary first), `env`, `apps`, `devices`.

## Scripts

| File | L | Trigger | Does |
|---|---:|---|---|
| `scripts/bootstrap.sh` | 72 | **Manual, once per host** | Symlinks `systemd/*.service` and `*.target` → `~/.config/systemd/user`, enables 7 units. Idempotent; skips units not installed, warns and continues on a failed enable |
| `scripts/sync_border.py` | 160 | `SUPER+SHIFT+W`, wallpaper change, `config.reloaded`, login | Wallpaper → accent color. **Rewrites** `hyprlock.conf`, `hyprtoolkit.conf`, GTK 3/4 CSS, OpenRGB, live border |
| `scripts/awww_transition.sh` | 25 | `SUPER+SHIFT+W`, quickshell WallpaperSelector | Random/explicit wallpaper at monitor refresh rate; calls `sync_border.py` |
| `scripts/pick_rgb.fish` | 14 | `SUPER+SHIFT+P` | `hyprpicker` → OpenRGB static LED color |
| `scripts/showcase.sh` | — | `SUPER+Print` | Lives in the **chezmoi source tree**, not here — resolved via `chezmoi source-path` |

## Systemd units

All `PartOf=` + `WantedBy=graphical-session.target`, `Restart=on-failure`.
Edit here, not in `~/.config/systemd/user` — those are symlinks.

| File | Slice | Process |
|---|---|---|
| `systemd/hyprland-session.target` | — | **Not a service.** Starts `graphical-session.target`, which 0.56.2 does not do itself. Started by `autostart.lua` on `hyprland.start` |
| `systemd/quickshell.service` | `app.slice` | `/usr/bin/quickshell` |
| `systemd/awww-daemon.service` | `background.slice` | `/usr/bin/awww-daemon` |
| `systemd/cliphist-text.service` | `background.slice` | `wl-paste --type text --watch cliphist store` |
| `systemd/cliphist-image.service` | `background.slice` | `wl-paste --type image --watch cliphist store` |

Package-provided units `bootstrap.sh` also enables: `hypridle.service`,
`hyprpolkitagent.service`, `gcr-ssh-agent.socket`.

## Ecosystem configs — hyprlang syntax, not Lua

| File | L | Notes |
|---|---:|---|
| `hypridle.conf` | 50 | 600s lock → 630s blank → 2700s suspend. Sole definition of `lock_cmd` |
| `hyprlock.conf` | 94 | Lock screen. `$accent` is **rewritten by `sync_border.py`** |
| `hyprtoolkit.conf` | 22 | Toolkit theme tokens. `accent` also rewritten at runtime |

## External trees this depends on

| Path | Relationship |
|---|---|
| `~/.config/quickshell/` | QML for bar/panels. Its `GlobalShortcut` names must match `keybindings.lua`'s `hl.dsp.global("quickshell:*")` strings |
| `~/.local/share/chezmoi` | Dotfile source. 34 files under `.config/hypr` tracked — everything except `hyprwiki/` (see `context.md`). `showcase.sh` lives there rather than here, on purpose |
| `~/.config/systemd/user/` | Symlinks to `systemd/`, created by `bootstrap.sh` |
| `~/.config/gtk-3.0`, `gtk-4.0` | `gtk.css` rewritten by `sync_border.py` |
| `~/Pictures/Wallpapers` | Source pool for `awww_transition.sh` |
| `~/.config/config_archive/hypr/` | Retired config, untracked and never loaded. `groups.lua` = archived group theming + tab navigation + `sync_border.py` group accent (2026-09-21); the rest is a June snapshot of the old config |

## Keybinding groups

`modules/keybindings.lua`, in file order:

| Lines | Group |
|---|---|
| 12-21 | APPLICATION LAUNCHER BINDINGS |
| 22-31 | QUICKSHELL PANEL TRIGGERS |
| 32-39 | WINDOW MANAGEMENT |
| 40-45 | WINDOW RESIZE (repeating) |
| 46-49 | KEYBOARD LAYOUT SWITCHING |
| 50-54 | CLIPBOARD MANAGEMENT |
| 55-69 | SCREENSHOT BINDINGS |
| 70-75 | WINDOW FOCUS NAVIGATION |
| 76-82 | WORKSPACE SWITCHING & MOVE WINDOW TO WORKSPACE |
| 83-90 | SPECIAL WORKSPACES (SCRATCHPADS) |
| 91-94 | WORKSPACE CYCLING (scroll wheel + arrow key overrides) |
| 95-98 | MOUSE BINDINGS — drag and resize windows |
| 99-106 | MULTIMEDIA & BRIGHTNESS (laptop function keys) |
| 107-112 | MEDIA CONTROL |
| 113-115 | WALLPAPER TRANSITION (SUPER + SHIFT + W) |
| 116-118 | OPENRGB COLOR PICKER (SUPER + SHIFT + P) |
| 119-130 | SESSION LOCK |
| 131-136 | WINDOW MOVE (direction) — SUPER+SHIFT+arrows stays resize, unchanged |
| 137-142 | MULTI-MONITOR (matters once a laptop is docked) |
| 143-146 | WORKSPACE CYCLING (keyboard) |
| 147-153 | WINDOW UTILITIES |
| 154-156 | COLOR PICKER (SUPER + I) — hyprpicker is installed but was unbound |
| 157-158 | RELOAD CONFIG |

## Not config

`hyprwiki/` — 120 vendored wiki files, reference only. Nothing loads it. Use it to
check claims before asserting something is broken.

**But the wiki tracks latest-git, not the installed 0.56.2** (`version-selector.md`).
Where it describes behaviour rather than syntax, confirm against the installed
binaries before trusting it — `configuring/extra/systemd.md` claims Hyprland starts
`graphical-session.target` automatically, which is false here and cost a whole
session's worth of daemons. Docs plus live evidence, never docs alone.
