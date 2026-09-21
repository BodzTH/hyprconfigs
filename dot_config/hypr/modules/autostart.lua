-- ▄▀█ █░█ ▀█▀ █▀█ █▀ ▀█▀ ▄▀█ █▀█ ▀█▀
-- █▀█ █▄█ ░█░ █▄█ ▄█ ░█░ █▀█ █▀▄ ░█░
--
-- MODULE 4: AUTOSTART
-- See: https://wiki.hypr.land/Configuring/Core/Autostart/
--
-- Long-running daemons are NOT spawned from here. They are systemd user units
-- in ../systemd/, symlinked and enabled once per machine by scripts/bootstrap.sh,
-- and pulled in by graphical-session.target. That buys Restart=on-failure and
-- ordered shutdown, neither of which hl.exec_cmd children get.
--
--   quickshell.service      bar, launcher, clipboard, power menu, screenshot,
--                           notifications, network widget  (6 keybinds depend on it)
--   awww-daemon.service     wallpaper daemon
--   cliphist-text.service   clipboard history — text
--   cliphist-image.service  clipboard history — images
--
--   systemctl --user status quickshell    to check any of them
--
-- What's left here is the one thing systemd can't express: a step that has to
-- run *after* awww-daemon is accepting connections.
-- ═══════════════════════════════════════════════════════════════

-- ▓▒░ SESSION TARGET
-- Hyprland 0.56.2 does NOT start graphical-session.target on its own. The wiki
-- (Configuring/Extra/Systemd) says it is "integrated into Hyprland and handled
-- automatically", but that page tracks a newer release. Verified against the
-- installed binaries: `graphical-session.target` / `hyprland-session.target`
-- appear nowhere in /usr/bin/Hyprland, /usr/bin/start-hyprland, /usr/bin/hyprctl
-- or any linked libhypr*/libaquamarine, and the hyprland package ships no units.
-- Without this handler, nothing starts the target -- quickshell, awww-daemon
-- and both cliphist watchers stay dead, with nothing logged as an error
-- anywhere (see context.md for how that was found).
--
-- import-environment first: Hyprland runs the same import itself, but the
-- ordering against this handler is not guaranteed, and a unit that starts
-- without WAYLAND_DISPLAY fails instead of waiting. It is idempotent, so doing
-- it here costs nothing and removes the race on a cold boot.
--
-- NOTE: this is exactly the `systemctl --user start` call that the wiki tells
--       you to delete. Do not delete it while Hyprland is 0.56.x -- re-check
--       with `strings /usr/bin/Hyprland | grep -c graphical-session` after an
--       upgrade, and only drop it once that prints nonzero.
hl.on("hyprland.start", function()
    hl.exec_cmd([[sh -c '
        systemctl --user import-environment \
            WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP DISPLAY
        systemctl --user start hyprland-session.target
    ']])
end)

-- BindsTo in the target means stopping it tears down graphical-session.target
-- and everything PartOf it, in order, instead of leaving daemons orphaned.
hl.on("hyprland.shutdown", function()
    os.execute("systemctl --user stop hyprland-session.target")
end)

-- ▓▒░ WALLPAPER RESTORE + BORDER SYNC
-- Waits for the daemon's socket instead of guessing at a sleep. The old
-- `awww-daemon & sleep 0.5 && awww restore && ...` chain lost the race on a slow
-- boot, and because it was &&-chained a failed restore silently skipped the
-- border sync too -- leaving the default platinum border with no error anywhere.
-- Border sync now runs unconditionally: worst case it falls back to Platinum
-- on its own terms.
hl.on("hyprland.start", function()
    hl.exec_cmd([[sh -c '
        for _ in $(seq 100); do
            awww query >/dev/null 2>&1 && break
            sleep 0.1
        done
        awww restore
        python3 "$HOME/.config/hypr/scripts/sync_border.py"
    ']])
end)

-- A reload re-applies appearance.lua's default border, wiping the wallpaper
-- color sync_border.py set at runtime -- re-apply it after every reload.
hl.on("config.reloaded", function()
    hl.exec_cmd('python3 "$HOME/.config/hypr/scripts/sync_border.py"')
end)

-- NOTE: gnome-keyring is socket-activated by systemd (gnome-keyring-daemon.socket);
--       starting it here was a no-op. Its ssh component no longer exists upstream --
--       gcr-ssh-agent.socket replaces it, enabled by scripts/bootstrap.sh, with
--       SSH_AUTH_SOCK exported in modules/environment.lua.
-- NOTE: hypridle and hyprpolkitagent ship their own units, both already
--       WantedBy=graphical-session.target. bootstrap.sh enables them; the old
--       `systemctl --user start` calls here are what Systemd tells you to remove.
-- NOTE: nm-applet, dunst, hyprpaper and waybar are all intentionally absent —
--       quickshell and awww cover those roles.
