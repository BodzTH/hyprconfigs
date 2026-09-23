# Context — `~/.config/hypr`

Orientation for agents working in this repo. Read this and `FILEMAP.md` before editing.

**Hyprland 0.56.2.** Config language is **Lua, not hyprlang.** Entry point is
`hyprland.lua`. If you write `general { gaps_in = 5 }` hyprlang-style, it is wrong here.

---

## The one rule

**Everything stays in one version-controlled tree.**

This is not style preference, it is the lesson from a real outage. Environment
variables used to live in `~/.config/uwsm/env`, outside this tree. Those files are
static shell and cannot read `hosts/`, so `AQ_DRM_DEVICES` — a workaround for an
Aquamarine crash on this dual-GPU box — fell into the gap between the two systems
and was silently absent for an unknown period. Nothing errored. It was found by
reading `/proc/<pid>/environ`.

uwsm was removed on 2026-09-21. Do not reintroduce config outside `~/.config/hypr`.
Systemd units live in `systemd/` here and are symlinked out by `scripts/bootstrap.sh`.

## Host portability

One tree runs on multiple machines. `hosts/init.lua` reads the hostname from
`/proc/sys/kernel/hostname` (the `hostname` binary is only a fallback — on Arch it
comes from `inetutils`, which is not in `base`) and loads `hosts/<hostname>.lua`,
falling back to `hosts/default.lua`.

A host profile supplies five keys — `monitors`, `gpu`, `env`, `apps`, `devices`.
Modules consume them; **modules never hardcode machine-specific values.** If you
are about to write a resolution, a GPU, a device name or a GPU-specific env var
into `modules/`, it belongs in the host profile instead.

`AMD_VULKAN_ICD` and `LIBVA_DRIVER_NAME` were exactly that — they sat in
`modules/environment.lua` until 2026-09-21, which would have handed an Intel laptop
`LIBVA_DRIVER_NAME=radeonsi` and broken its hardware video decoding. They live in
`hosts/hyprcachyos.lua` now. Only vendor-neutral Mesa driconf options stay in the
module.

Adding a machine = one new `hosts/<hostname>.lua` + run `scripts/bootstrap.sh`
(`chezmoi apply` also runs it whenever `systemd/` or the script changes, via
`run_onchange_after_hypr-user-units.sh.tmpl` in the source root). No
module edits. Keep it that way.

### GPU selection is resolved, not hardcoded

`/dev/dri/cardN` numbers are assigned at boot and move between boots. The wiki
warns against pinning them, and the stable `by-path` names can't go in
`AQ_DRM_DEVICES` because they contain `:`, which that variable uses as its own
separator.

So host profiles list **PCI addresses** and `modules/environment.lua` resolves them
at startup via `readlink -e`. Note `-e`, not `-f`: `-f` prints a canonicalized path
even when nothing exists there, which would export a nonexistent device — worse
than exporting nothing. An unresolvable address degrades to auto-detect. If you
touch that resolver, re-test it with a bogus address.

## Daemons are systemd units, not `exec_cmd`

`quickshell`, `awww-daemon`, both `cliphist` watchers and `openrgb-server` are
user units in `systemd/`, pulled in by `graphical-session.target`. They get `Restart=on-failure`
and their own cgroups.

### Something must start `graphical-session.target` — Hyprland 0.56.2 does not

This is the second outage caused by the same gap, and it is the one to remember.
The wiki page `hyprwiki/configuring/extra/systemd.md:12` says the session target is
"integrated into Hyprland and handled automatically" and tells you to *delete* any
`systemctl --user start` call from your config. **That page documents a newer
release than the one installed.** Verified on 0.56.2:

```sh
strings /usr/bin/Hyprland | grep -c graphical-session   # 0
pacman -Ql hyprland | grep /usr/lib/systemd             # nothing
```

Neither `graphical-session.target` nor `hyprland-session.target` appears in
`/usr/bin/Hyprland`, `/usr/bin/start-hyprland`, `/usr/bin/hyprctl` or any linked
`libhypr*`/`libaquamarine`, and the package ships no unit files. The binary only
runs `systemctl --user import-environment …`.

uwsm was doing it. Removing uwsm left nobody doing it, so every
`WantedBy=graphical-session.target` unit stayed `inactive` — no bar, no wallpaper,
no clipboard history, no polkit agent, no idle lock — while `systemctl --user
list-units --state=failed` stayed empty, because nothing failed. Nothing was ever
asked to start.

`systemd/hyprland-session.target` now fills the gap, started and stopped by
`modules/autostart.lua` on `hyprland.start` / `hyprland.shutdown`. **Do not delete
those handlers on the wiki's advice while Hyprland is 0.56.x.** Re-check after
every upgrade; only drop them once the `grep -c` above prints nonzero.

Diagnose this class of failure with the target, not the units:

```sh
systemctl --user is-active graphical-session.target   # inactive = nothing started it
```

Units use `app.slice` / `background.slice`. **Never `app-graphical.slice` or
`background-graphical.slice`** — those are shipped by the uwsm package, which is gone.

`modules/autostart.lua` holds only what systemd cannot express: a step sequenced
after awww-daemon's socket is accepting connections. Do not add daemons to it.

### quickshell is the single point of failure

It is simultaneously the bar, launcher, clipboard panel, power menu, screenshot
panel, notification server + history, volume OSD, window overview, keybind
cheatsheet and network panel. **Eight keybinds** route to it through
the `global_shortcuts` protocol (`quickshell:toggle-launcher` and friends in
`modules/keybindings.lua`). Its QML lives in `~/.config/quickshell/` — a separate
tree, outside this one. Renaming a shortcut here silently breaks it unless the QML
`GlobalShortcut` is renamed to match.

## Locking

The locker is named in exactly one place: `hypridle.conf`'s `general:lock_cmd`.
Everything else — sleep, the idle timer, SUPER+L — emits `loginctl lock-session`,
and hypridle runs `lock_cmd` in response.

Do not call `hyprlock` directly from a keybind or listener. It duplicates the
definition and breaks hypridle's sleep-inhibit detection, which needs to recognize
the `lock_cmd`/`before_sleep_cmd` pairing to hold the inhibitor until the session is
genuinely locked. Confirm the strong mode in the log:

```
Sleep inhibition enabled - inhibiting until the wayland session gets locked
```

Lock fires at 600s, display blanks at 630s. **Keep that order.** It was previously
inverted — blank at 600, lock at 900 — leaving five minutes where the screen was
dark and unlocked, which reads as locked and is not.

There is deliberately **no lid-switch bind**. Lid handling belongs to logind; closing
the lid raises `PrepareForSleep`, which `before_sleep_cmd` already locks on.

`misc.allow_session_lock_restore` is on (`modules/layouts.lua`). If hyprlock
crashes, the session stays locked behind Hyprland's "lockscreen app died" screen;
recover from a TTY with
`hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'`. Without that option
no replacement locker is accepted.

## Runtime border color

`scripts/sync_border.py` extracts a color from the wallpaper and writes it into
`hyprlock.conf`, `hyprtoolkit.conf`, the GTK 3/4 stylesheets, Qt's Kvantum theme and qt6ct
stylesheet, yazi's `theme.toml`
(only lines tagged `# accent: fg|bg`), `starship.toml`'s palette `accent`/`accent2`, kitty's
`cursor` (then `SIGUSR1` to every kitty to reload), OpenRGB, and the
live border via `hyprctl eval`, and sets quickshell's accent live over IPC
(`qs ipc call theme setAccent RRGGBB`). Neovim is not rewritten: its `chadrc.lua`
reads the accent state file into base46's `nord_blue`, and `sync_border.py`
calls `require'accent'.reload()` in each `$XDG_RUNTIME_DIR/nvim.*.0` socket to
recompile base46's cache; a new nvim recompiles at startup if the cache is stale. Group borders are
deliberately not synced — group theming is archived (see below).

The colour is picked by a chroma²-weighted hue histogram, so a small vivid accent
beats a large dull backdrop. The earlier count-weighted scorer turned muted
bluish-grey backgrounds into a steel blue that appeared nowhere in the image.
Rapid wallpaper changes are latest-wins: each run claims a token in
`$XDG_RUNTIME_DIR/sync_border.token` before loading numpy/PIL, and the
check-and-`apply()` is serialised on `sync_border.lock`, so an older run can
neither skip ahead nor finish after a newer one. Stress-tested 2026-09-23:
20/20 last-wins at click pace, 10/10 consistent across targets when launched
simultaneously.

**GTK and Qt follow the accent (2026-09-23).** Stock Graphite compiles one of nine
preset accents into its CSS, so the `@define-color accent_color` in
`~/.config/gtk-*/gtk.css` used to reach one dialog-border rule and nothing else.
`scripts/build_gtk_theme.py` rebuilds `~/.themes/Graphite-Dark` (dark, `--tweaks
black`, the installed variant) with the preset replaced by the literal
`@accent_color`; sass colour builtins are wrapped so the accent's maths becomes
GTK's runtime `alpha()`/`mix()`/`shade()`. Text on the accent is
`@accent_fg_color`, which `sync_border.py` sets to `#111111` or `#ffffff` using
Graphite's own brightness threshold (156). Verified: every accent-driven line of
two stock builds with different blues is `@accent`-based here (GTK3 and GTK4), 0
parse errors in `Gtk.CssProvider`. Qt uses Kvantum `GraphiteDark`: its SVG's grey
accent (`#e0e0e0`, focused `#f2f2f2`, pressed `#cccccc`) became placeholders in
`GraphiteDark.svg.in`, rendered on each change, plus the kvconfig highlight and
on-accent text keys. Both apply to newly opened windows only. A grey wallpaper's
Platinum accent reproduces the old monochrome look.

**quickshell is not rewritten.** `Theme.qml` used to be patched in place and
hot-reloaded, but a write landing while the previous reload was still running
was missed — the bar kept the old colour in 5 of 10 rapid trials — and each
change rebuilt the whole shell. Now `Theme.accent` is a plain property set over
IPC (~20ms, no reload), and the colour is persisted to
`~/.local/state/hypr/accent`, which `Theme.qml` reads once at start.

### OpenRGB goes through one helper and a server

Every LED write goes through `scripts/openrgb_color.sh` — `sync_border.py` and
`pick_rgb.fish` both call it. It talks to `openrgb-server.service` with
`--nodetect`: a standalone `openrgb` call redid full hardware detection (~3.9s)
and two overlapping calls fought over the same devices, which is why colours
used to need several tries. It picks Static per device where available and
Direct otherwise (a blanket `-m static` errors on Direct-only devices). Calls
are serialised with `flock` and latest-wins. The CLI sends at ~33ms, then idles
~1s before exiting; the helper backgrounds it (with the lock fd closed) and holds
the lock only 150ms, so back-to-back changes take ~0.22s each instead of ~1.1s.
Verified on the hardware by reading controller colours back over the SDK:
bursts of three changes always left the last colour, never an earlier one.

The Skyloong keyboard is **not** OpenRGB's: it has its own vendor software.
Both Skyloong detectors are off in `~/.config/OpenRGB/OpenRGB.json`
(`Detectors` → `"Skyloong GK104 Pro": false`), so OpenRGB never opens it and
only the motherboard and G305 get the accent. That file is OpenRGB's own,
outside this tree — re-toggle it there (or in the GUI's Settings → Supported
Devices) if it is ever reset.
The server opens its port ~3s before detection finishes, so the helper waits
out the first 6s of the server's life (login only).

Two consequences. First, **those files are rewritten at runtime** — a border/accent
color you read there is not necessarily what the repo intends. Second, a config
reload re-applies `appearance.lua`'s static border and wipes it, which is why
`modules/autostart.lua` re-runs the script on `config.reloaded`.

## Archived and commented-out config

This machine isn't used for gaming, so gaming-only settings are **commented out in
place**, each with a NOTE: `render.direct_scanout` (`modules/appearance.lua`),
`cursor.no_break_fs_vrr` and `min_refresh_rate` (`modules/input.lua`), the Mesa
`mesa_glthread` / `vk_xwayland_wait_ready` env (`modules/environment.lua`) and
`DXVK_FILTER_DEVICE_NAME` (`hosts/hyprcachyos.lua`). Uncomment to bring them back.
`misc.vrr = 3` stays on deliberately: mode 3 also covers fullscreen video, which mpv
reports as content type `video`.

The old quickshell shortcuts cheatsheet is archived in
`~/.config/config_archive/quickshell/`; it was rebuilt the same day (see below).
The old quickshell network panel, its bar widget, `NetworkService` and the
separate speed widget are archived there too. The network panel was rebuilt
the same day on NetworkManager alone: live state over D-Bus
(`Quickshell.Networking`), `nmcli` only for one-shot actions (details, hidden
networks, VPN, WireGuard import), and no outside tools — no nmtui, applet or
editor. It opens from the bar item only (no keybind); `qs ipc call network
toggle` opens it from a script. Its layer namespace `quickshell-network` is in
`windowrules.lua`'s blur rule.

Retired config goes to `~/.config/config_archive/` — outside this tree and outside
chezmoi, and nothing loads it. Group (tabbed window) theming, its tab navigation and
`sync_border.py`'s group accent were archived there on 2026-09-21 as
`config_archive/hypr/groups.lua`; groups (SUPER+CTRL+G) use stock colors meanwhile.
To restore, paste its pieces back into this tree as its header describes. Never
`require()` it from there — that would put live config outside the tree, which is
exactly what the one rule forbids.

## Keybind descriptions feed the cheatsheet

Every bind in `modules/keybindings.lua` goes through a local `bind()` helper and
carries a description of the form **`Category: Action`** (Apps, Panels, Windows,
Workspaces, Capture, Media, System). The quickshell cheatsheet (SUPER+H,
`~/.config/quickshell/panels/Cheatsheet.qml`) reads them live from
`hyprctl binds -j` and splits them into its left-rail category and the row
title. A bind with no description, or an unknown category, lands under System
with its raw key — so **give every new bind a description in that shape**.
Binds whose descriptions differ only by a trailing direction word or number
collapse into one row ("Focus window ←→↑↓", "Go to workspace 1–10").

`bind()` also records each action in the global `cheatsheet.actions`, keyed by
modmask + key, so the cheatsheet can run a bind:
`hyprctl eval 'cheatsheet.run(64, "Q")'`. `hyprctl binds -j` alone can't — it
shows Lua binds as dispatcher `__lua` with an opaque id. The global is on
purpose (`hyprctl eval` only reaches globals) and is rebuilt on every reload.
Quick check that nothing lost its description:

```sh
hyprctl binds -j | jq '[.[] | select(.description == "")] | length'   # want 0
```

## Verifying a change

The vendored **`hyprwiki/`** (120 files) is a full copy of the Hyprland wiki. Check
it before asserting something is broken — a previous audit flagged
`hyprctl dispatch 'hl.dsp.dpms(...)'` as invalid syntax when the wiki documents that
exact form. Cite `file:line`.

```sh
luac -p hyprland.lua modules/*.lua hosts/*.lua   # syntax, no reload needed
hyprctl reload && hyprctl configerrors           # semantics; empty output = clean
systemctl --user status quickshell               # any managed daemon
systemctl --user show-environment | grep AQ_DRM  # env only applies at launch
```

`hl.env()` takes effect **at launch only.** A reload will not change it — verifying
an env change requires a relogin.

## chezmoi

`chezmoi managed` covers **32 files** under `.config/hypr` — every file in this
tree except `hyprwiki/`, which is vendored upstream documentation and is
deliberately left out rather than putting 120 upstream files in the dotfile repo.
`systemd/`, `scripts/bootstrap.sh`, `hosts/laptop.lua`, `context.md` and this
file's companion `FILEMAP.md` were added on 2026-09-21; they are what a new host
actually needs.

(`scripts/showcase.sh` is not here at all — it lives in the chezmoi source tree and
is reached via `chezmoi source-path` from `keybindings.lua`. That is intentional.)

### The source tree drifts, and `apply` is the dangerous direction

Being *tracked* is not the same as being *current*. On 2026-09-21 the source was
found to be **pre-uwsm-purge** for 11 tracked files: it still held the
commented-out `hl.env()` block labelled "managed by UWSM", `vars.bar`, and host
profiles with no `gpu`/`env` keys. `chezmoi apply` would have restored exactly the
outage the rest of this file documents — `AQ_DRM_DEVICES` gone, daemons back to
`exec_cmd`. Fixed with `chezmoi re-add`.

Editing happens **here**, in `~/.config/hypr`, so the live tree is the source of
truth and chezmoi has to be pushed to match it. Check before trusting `apply`:

```sh
chezmoi verify ~/.config/hypr   # exit 0 = source matches live
chezmoi diff   ~/.config/hypr   # a/ = live, b/ = what apply would write
chezmoi re-add ~/.config/hypr   # pull live changes INTO the source
```

Run `re-add` after every editing session.

### Accent files are templates — `re-add` skips them

Every file `scripts/sync_border.py` rewrites is a chezmoi **template** that renders
its accent from `~/.local/state/hypr/accent` (`.chezmoitemplates/accent` in the
source): `hyprlock.conf`, `hyprtoolkit.conf`, GTK 3/4 CSS, kitty, starship, yazi's
`theme.toml`. So a wallpaper change is not drift, `chezmoi apply --force` never
reverts the colour, and the source no longer commits whichever accent happened to
be up. `hyprlock.conf` also renders the chezmoi `displayName` (asked on
`chezmoi init`) into the lock-screen greeting.

The cost: `chezmoi re-add` silently skips templates. Edit these through the source —
`chezmoi edit --apply ~/.config/hypr/hyprlock.conf` — or, after a live edit, fold
it back with `chezmoi merge ~/.config/hypr/hyprlock.conf`. `chezmoi status` still
flags a live edit to them, since it no longer hides behind accent noise.

## Conventions

ASCII-art banner + `-- ═══` rule at the top of each module; `-- ▓▒░` section
headers. Comments explain **why**, especially where something looks redundant or
was deliberately removed — several `NOTE:` comments exist to stop a future reader
"helpfully" re-adding a thing that was taken out on purpose. Preserve them.
