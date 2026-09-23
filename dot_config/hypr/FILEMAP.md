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
| `modules/variables.lua` | 46 | App aliases — terminal, browser, editor, file manager; personal apps (`thePlan`, `antigravity`) are nil where not installed, so their binds are skipped | `hosts` (`.apps`) |
| `modules/monitors.lua` | 14 | Thin loop calling `hl.monitor()` | `hosts` (`.monitors`) |
| `modules/appearance.lua` | 92 | Borders, floating-window snap, rounding, blur, shadow, opacity, dim, render (`direct_scanout` commented out) | — |
| `modules/animations.lua` | 44 | 8 bezier curves, 17 animation leaves | — |
| `modules/input.lua` | 62 | Keyboard (`us,ara`), touchpad, cursor (gaming VRR lines commented out), gestures, per-device | `hosts` (`.input` overrides, `.devices`) |
| `modules/layouts.lua` | 71 | Dwindle, `misc` (incl. `font_family`, lock-restore), `binds`, `ecosystem` | — |
| `modules/autostart.lua` | 90 | Starts/stops `hyprland-session.target`; awww-socket-sequenced wallpaper restore + border sync | — |
| `modules/keybindings.lua` | 213 | Every bind, via the local `bind()` helper: `Category: Action` descriptions (read by the quickshell cheatsheet) + the global `cheatsheet.actions` registry that lets it run a bind. Largest file | `variables` |
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
| `scripts/bootstrap.sh` | 73 | Once per host (repo `scripts/bootstrap.sh`), and by `chezmoi apply` whenever `systemd/` or this script changes | Symlinks `systemd/*.service` and `*.target` → `~/.config/systemd/user`, enables 8 units. Idempotent; skips units not installed, warns and continues on a failed enable |
| `scripts/sync_border.py` | 348 | `SUPER+SHIFT+W`, wallpaper change, `config.reloaded`, login | Wallpaper → accent color. **Rewrites** `hyprlock.conf`, `hyprtoolkit.conf`, GTK 3/4 CSS (`accent_color`/`accent_bg_color`/`accent_fg_color`), Kvantum `GraphiteDark.svg` (rendered from `.svg.in`) + `GraphiteDark.kvconfig` highlight/on-accent keys, qt6ct QSS `/* accent */` line, yazi `theme.toml` (`# accent:` lines), `starship.toml` palette `accent`/`accent2`, kitty `cursor` (+ `SIGUSR1`); OpenRGB (via `openrgb_color.sh`), live border, quickshell accent over IPC, running nvims over RPC (`accent.reload()`). Latest-wins token + lock |
| `scripts/build_gtk_theme.py` | 169 | By hand, after reinstalling the GTK theme | Rebuilds `~/.themes/Graphite-Dark` GTK 3/4 CSS from pinned upstream Graphite with the accent as runtime `@accent_color` (see `context.md`). Needs `git`, `sassc` |
| `scripts/awww_transition.sh` | 25 | `SUPER+SHIFT+W`, quickshell WallpaperSelector | Random/explicit wallpaper at monitor refresh rate; calls `sync_border.py` |
| `scripts/pick_rgb.fish` | 15 | `SUPER+SHIFT+P` | `hyprpicker` → `openrgb_color.sh` |
| `scripts/openrgb_color.sh` | 111 | `sync_border.py`, `pick_rgb.fish` | Every OpenRGB write. Server fast path (`--nodetect`), Static/Direct per device, `flock` + latest-wins (lock held 150ms, not the CLI's 1s idle), waits out server detection at login |
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
| `systemd/openrgb-server.service` | `background.slice` | `openrgb --server --noautoconnect`. `ConditionPathExists=/usr/bin/openrgb` skips it on hosts without OpenRGB |

Package-provided units `bootstrap.sh` also enables: `hypridle.service`,
`hyprpolkitagent.service`, `gcr-ssh-agent.socket`.

## Ecosystem configs — hyprlang syntax, not Lua

| File | L | Notes |
|---|---:|---|
| `hypridle.conf` | 50 | 600s lock → 630s blank → 2700s suspend. Sole definition of `lock_cmd` |
| `hyprlock.conf` | 94 | Lock screen. `$accent` is **rewritten by `sync_border.py`**; chezmoi template (accent + `displayName`) — edit via `chezmoi edit`, `re-add` skips it |
| `hyprtoolkit.conf` | 22 | Toolkit theme tokens. `accent` also rewritten at runtime; chezmoi template like `hyprlock.conf` |

## External trees this depends on

| Path | Relationship |
|---|---|
| `~/.config/quickshell/` | QML for bar/panels. Its `GlobalShortcut` names must match `keybindings.lua`'s `hl.dsp.global("quickshell:*")` strings. `panels/Cheatsheet.qml` (SUPER+H) reads this tree's bind descriptions. `Theme.qml`'s `accent` is set by `sync_border.py` over IPC (`qs ipc call theme setAccent`), persisted in `~/.local/state/hypr/accent` |
| `~/.local/share/chezmoi` | Dotfile source. 33 files under `.config/hypr` tracked — everything except `hyprwiki/` (see `context.md`). `showcase.sh` lives there rather than here, on purpose |
| `~/.config/systemd/user/` | Symlinks to `systemd/`, created by `bootstrap.sh` |
| `~/.config/gtk-3.0`, `gtk-4.0` | `gtk.css` accent defines rewritten by `sync_border.py` |
| `~/.themes/Graphite-Dark` | Not chezmoi-tracked. GTK 3/4 CSS **built by `build_gtk_theme.py`** to read `@accent_color`/`@accent_fg_color` at runtime — reinstalling stock Graphite loses the accent |
| `~/.config/Kvantum/Graphite/` | `GraphiteDark.svg` is **generated** from `GraphiteDark.svg.in` (`@ACCENT@`, `@ACCENT_LIGHT@`, `@ACCENT_DARK@`) by `sync_border.py` — edit the `.in`. `GraphiteDark.kvconfig` highlight + on-accent text keys rewritten. New Qt apps only |
| `~/.config/qt6ct/qss/hyprblur-round.qss` | Line tagged `/* accent */` (progress chunk; the QSS overrides Kvantum there) rewritten by `sync_border.py` |
| `~/.config/yazi/theme.toml` | Lines tagged `# accent: fg\|bg` rewritten by `sync_border.py`; new yazi instances only (no live theme reload) |
| `~/.config/nvim/lua/accent.lua` | Accent → base46 `nord_blue` (read from `~/.local/state/hypr/accent` by `chadrc.lua`). `sync()` recompiles the base46 cache at startup if stale; `reload()` is what `sync_border.py` calls in each running nvim |
| `~/.config/starship.toml` | Palette keys `accent` (prompt icon) and `accent2` (`❯`, accent hue +60°, darker grey for grey accents) rewritten by `sync_border.py`. Live on the next prompt |
| `~/.config/kitty/kitty.conf` | `cursor` rewritten by `sync_border.py`; kitty auto-reloads, and gets `SIGUSR1` too |
| `~/Pictures/Wallpapers` | Source pool for `awww_transition.sh` |
| `~/.config/config_archive/` | Retired config, untracked and never loaded. `groups.lua` = archived group theming + tab navigation + `sync_border.py` group accent (2026-09-21); `quickshell/` = the old SUPER+H shortcuts cheatsheet (2026-09-23, since rebuilt as `panels/Cheatsheet.qml`) and the old network panel + bar widget + `NetworkService` + speed widget (2026-09-23, since rebuilt); the rest is a June snapshot of the old config |

## Keybinding groups

`modules/keybindings.lua`, in file order:

| Lines | Group |
|---|---|
| 12-48 | BIND HELPER + CHEATSHEET REGISTRY |
| 49-59 | APPLICATION LAUNCHER BINDINGS |
| 60-72 | QUICKSHELL PANEL TRIGGERS |
| 73-80 | WINDOW MANAGEMENT |
| 81-86 | WINDOW RESIZE (repeating) |
| 87-90 | KEYBOARD LAYOUT SWITCHING |
| 91-95 | CLIPBOARD MANAGEMENT |
| 96-115 | SCREENSHOT BINDINGS |
| 116-121 | WINDOW FOCUS NAVIGATION |
| 122-128 | WORKSPACE SWITCHING & MOVE WINDOW TO WORKSPACE |
| 129-136 | SPECIAL WORKSPACES (SCRATCHPADS) |
| 137-140 | WORKSPACE CYCLING (scroll wheel + arrow key overrides) |
| 141-144 | MOUSE BINDINGS — drag and resize windows |
| 145-157 | MULTIMEDIA & BRIGHTNESS (laptop function keys) |
| 158-167 | MEDIA CONTROL |
| 168-170 | WALLPAPER TRANSITION (SUPER + SHIFT + W) |
| 171-173 | OPENRGB COLOR PICKER (SUPER + SHIFT + P) |
| 174-185 | SESSION LOCK |
| 186-191 | WINDOW MOVE (direction) — SUPER+SHIFT+arrows stays resize, unchanged |
| 192-197 | MULTI-MONITOR (matters once a laptop is docked) |
| 198-201 | WORKSPACE CYCLING (keyboard) |
| 202-208 | WINDOW UTILITIES |
| 209-211 | COLOR PICKER (SUPER + I) — hyprpicker is installed but was unbound |
| 212-213 | RELOAD CONFIG |

## Not config

`hyprwiki/` — 120 vendored wiki files, reference only. Nothing loads it. Use it to
check claims before asserting something is broken.

**But the wiki tracks latest-git, not the installed 0.56.2** (`version-selector.md`).
Where it describes behaviour rather than syntax, confirm against the installed
binaries before trusting it — `configuring/extra/systemd.md` claims Hyprland starts
`graphical-session.target` automatically, which is false here and cost a whole
session's worth of daemons. Docs plus live evidence, never docs alone.
