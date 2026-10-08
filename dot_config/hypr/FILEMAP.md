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
| `modules/keybindings.lua` | 312 | Every bind, via the local `bind()` helper: `Category: Action` descriptions (read by the quickshell cheatsheet) + the global `cheatsheet.actions` registry that lets it run a bind. `locked` binds are made `submap_universal`. Ends with the `lockscreen`/`lockscreen-armed` submaps + global `lockbuttons` (hyprlock keyboard buttons, see `context.md`). Largest file | `variables` |
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
| `scripts/sync_border.py` | 385 | `SUPER+SHIFT+W`, wallpaper change, `config.reloaded`, login | Wallpaper → accent color. **Rewrites** `hyprlock.conf`, `hyprtoolkit.conf`, GTK 3/4 CSS (`accent_color`/`accent_bg_color`/`accent_fg_color`), Kvantum `GraphiteDark.svg` (rendered from `.svg.in`) + `GraphiteDark.kvconfig` highlight/on-accent keys, qt6ct QSS `/* accent */` line, yazi `theme.toml` (`# accent:` lines), `starship.toml` palette `accent`/`accent2`, kitty `cursor` (+ `SIGUSR1`), btop `hyprland.theme` (rendered from `.theme.in`, + `SIGUSR2`), mpv.conf accent lines (by key); OpenRGB (via `openrgb_color.sh`), live border, quickshell accent over IPC, running nvims over RPC (`accent.reload()`). Latest-wins token + lock |
| `scripts/build_gtk_theme.py` | 169 | By hand, after reinstalling the GTK theme | Rebuilds `~/.themes/Graphite-Dark` GTK 3/4 CSS from pinned upstream Graphite with the accent as runtime `@accent_color` (see `context.md`). Needs `git`, `sassc` |
| `scripts/awww_transition.sh` | 25 | `SUPER+SHIFT+W`, quickshell WallpaperSelector | Random/explicit wallpaper at monitor refresh rate; calls `sync_border.py` |
| `scripts/lock_buttons.py` | 263 | hyprlock's three power-button labels (`cmd[update:0:1]`) and `onclick`; the `lockscreen` submap binds | Hover + keyboard for the lock-screen sleep/reboot/shutdown buttons, and their actions. Label mode prints the glyph (accent if lit); a watcher per hyprlock polls the cursor, takes ←/→/Enter/Esc from the submap binds over a datagram socket, switches `lockscreen`/`lockscreen-armed`, and `SIGUSR2`s hyprlock only on change. Offsets must match `hyprlock.conf` |
| `scripts/pick_rgb.fish` | 15 | `SUPER+SHIFT+P` | `hyprpicker` → `openrgb_color.sh` |
| `scripts/openrgb_color.sh` | 124 | `sync_border.py`, `pick_rgb.fish` | Every OpenRGB write. Server fast path (`--nodetect`), sRGB→linear gamma for LEDs, Static/Direct per device, `flock` + latest-wins (lock held 150ms, not the CLI's 1s idle), waits out server detection at login |
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
| `hyprlock.conf` | 137 | Lock screen; power buttons hover via `scripts/lock_buttons.py`. `$accent` is **rewritten by `sync_border.py`**; chezmoi template (accent + `displayName`) — edit via `chezmoi edit`, `re-add` skips it |
| `hyprtoolkit.conf` | 22 | Toolkit theme tokens. `accent` also rewritten at runtime; chezmoi template like `hyprlock.conf` |

## External trees this depends on

| Path | Relationship |
|---|---|
| `~/.config/quickshell/` | QML for bar/panels. Its `GlobalShortcut` names must match `keybindings.lua`'s `hl.dsp.global("quickshell:*")` strings. `panels/Cheatsheet.qml` (SUPER+H) reads this tree's bind descriptions. `Theme.qml`'s `accent` is set by `sync_border.py` over IPC (`qs ipc call theme setAccent`), persisted in `~/.local/state/hypr/accent` |
| `~/.local/share/chezmoi` | Dotfile source. 33 files under `.config/hypr` tracked — everything except `hyprwiki/` (see `context.md`). `showcase.sh` lives there rather than here, on purpose |
| `~/.config/systemd/user/` | Symlinks to `systemd/`, created by `bootstrap.sh` |
| `~/.config/gtk-3.0`, `gtk-4.0` | `gtk.css` accent defines rewritten by `sync_border.py`. `gtk-4.0/gtk.css` + `gtk-dark.css` end with `window { backdrop-filter: blur(20px); }`: GTK 4.24 binds ext-background-effect with an empty blur region, which makes Hyprland 0.56.2 skip blur for every GTK 4 window — the rule makes GTK send a full-window region. Not the opaque region (kitty is opaque and blurred). Hyprland#16508 |
| `~/.themes/Graphite-Dark` | Not chezmoi-tracked. GTK 3/4 CSS **built by `build_gtk_theme.py`** to read `@accent_color`/`@accent_fg_color` at runtime — reinstalling stock Graphite loses the accent |
| `~/.config/Kvantum/Graphite/` | `GraphiteDark.svg` is **generated** from `GraphiteDark.svg.in` (`@ACCENT@`, `@ACCENT_LIGHT@`, `@ACCENT_DARK@`) by `sync_border.py` — edit the `.in`. `GraphiteDark.kvconfig` highlight + on-accent text keys rewritten. New Qt apps only |
| `~/.config/qt6ct/qss/hyprblur-round.qss` | Line tagged `/* accent */` (progress chunk; the QSS overrides Kvantum there) rewritten by `sync_border.py` |
| `~/.config/yazi/theme.toml` | Lines tagged `# accent: fg\|bg` rewritten by `sync_border.py`; new yazi instances only (no live theme reload) |
| `~/.config/nvim/lua/accent.lua` | Accent → base46 `nord_blue` (read from `~/.local/state/hypr/accent` by `chadrc.lua`). `sync()` recompiles the base46 cache at startup if stale; `reload()` is what `sync_border.py` calls in each running nvim |
| `~/.config/starship.toml` | Palette keys `accent` (prompt icon) and `accent2` (`❯`, accent hue +60°, darker grey for grey accents) rewritten by `sync_border.py`. Live on the next prompt |
| `~/.config/kitty/kitty.conf` | `cursor` rewritten by `sync_border.py`; kitty auto-reloads, and gets `SIGUSR1` too |
| `~/.config/btop/themes/` | `hyprland.theme` is **generated** from `hyprland.theme.in` (`@ACCENT@`, `_LIGHT`/`_DIM`, `@ACCENT2@` + variants, `@ON_ACCENT@`) by `sync_border.py` — edit the `.in`. Running btops get `SIGUSR2`, which reloads config + theme live (verified 1.4.7). `btop.conf` sets `color_theme = "hyprland"`; a theme path outside btop's theme dirs is silently ignored |
| `~/.config/mpv/mpv.conf` | `osd-selected-color`, `osc-timecode_color`/`held_element_color`, `console-focused_back_color`/`focused_color`/`match_color` (accent2) and `stats-plot_color` (BBGGRR) rewritten by `sync_border.py`, matched by key. Script-opt values with `#` must stay single-quoted — unquoted, mpv reads `#` as a comment and the option comes out empty. New mpv instances only |
| `~/.config/mimeapps.list` + `~/.local/share/applications/{yazi,nvim}-kitty.desktop` | XDG defaults (2026-10-08): folders → yazi (`--class=org.yazi.fm`, as the SUPER file manager), text/code → nvim, images → swayimg, audio/video → mpv, PDF/web → Firefox, archives → Ark. The two launchers exist because the stock yazi/nvim ones are `Terminal=true` and xdg-open here has no `xdg-terminal-exec`. Outside this tree; chezmoi-managed |
| `~/Pictures/Wallpapers` | Source pool for `awww_transition.sh` |
| `~/.config/config_archive/` | Retired config, untracked and never loaded. `groups.lua` = old group theming draft (2026-09-21; superseded by the live `group` block, 2026-09-23); `quickshell/` = the old SUPER+H shortcuts cheatsheet (2026-09-23, since rebuilt as `panels/Cheatsheet.qml`) and the old network panel + bar widget + `NetworkService` + speed widget (2026-09-23, since rebuilt); the rest is a June snapshot of the old config |

## Keybinding groups

`modules/keybindings.lua`, in file order:

| Lines | Group |
|---|---|
| 12-52 | BIND HELPER + CHEATSHEET REGISTRY |
| 53-65 | APPLICATION LAUNCHER BINDINGS |
| 66-78 | QUICKSHELL PANEL TRIGGERS |
| 79-86 | WINDOW MANAGEMENT |
| 87-93 | GROUP TABS — SUPER+SHIFT+↑↓ moves the active tab's position; switching |
| 94-100 | KEYBOARD LAYOUT SWITCHING |
| 101-105 | CLIPBOARD MANAGEMENT |
| 106-125 | SCREENSHOT BINDINGS |
| 126-131 | ARROW NAVIGATION — ←→ cycles workspaces, ↑↓ cycles tabs in a group |
| 132-137 | WINDOW FOCUS NAVIGATION (directional) |
| 138-144 | WORKSPACE SWITCHING & MOVE WINDOW TO WORKSPACE |
| 145-152 | SPECIAL WORKSPACES (SCRATCHPADS) |
| 153-156 | WORKSPACE CYCLING (scroll wheel) |
| 157-160 | MOUSE BINDINGS — drag and resize windows |
| 161-176 | MULTIMEDIA & BRIGHTNESS (laptop function keys) |
| 177-185 | MEDIA CONTROL |
| 186-188 | WALLPAPER TRANSITION (SUPER + SHIFT + W) |
| 189-191 | OPENRGB COLOR PICKER (SUPER + SHIFT + P) |
| 192-201 | SESSION LOCK |
| 202-207 | WINDOW MOVE (direction) — SUPER+CTRL+arrows (SUPER+SHIFT+↑↓ is group tabs) |
| 208-214 | MULTI-MONITOR (matters once a laptop is docked) |
| 215-218 | WORKSPACE CYCLING (keyboard) |
| 219-225 | WINDOW UTILITIES |
| 226-228 | COLOR PICKER (SUPER + I) — hyprpicker is installed but was unbound |
| 229-231 | RELOAD CONFIG |
| 232-312 | LOCK SCREEN POWER BUTTONS (keyboard) |

## Not config

`hyprwiki/` — 120 vendored wiki files, reference only. Nothing loads it. Use it to
check claims before asserting something is broken.

**But the wiki tracks latest-git, not the installed 0.56.2** (`version-selector.md`).
Where it describes behaviour rather than syntax, confirm against the installed
binaries before trusting it — `configuring/extra/systemd.md` claims Hyprland starts
`graphical-session.target` automatically, which is false here and cost a whole
session's worth of daemons. Docs plus live evidence, never docs alone.
