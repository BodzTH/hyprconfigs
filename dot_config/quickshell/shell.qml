//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire as Pw
import Quickshell.Services.Notifications as Notifs
import qs.bar
import qs.panels

ShellRoot {
    id: root

    signal togglePowerMenu()
    signal toggleBarFocus()
    signal toggleCalendar()
    signal toggleWallpaperSelector()
    signal toggleNotifications()
    signal toggleCheatsheet()
    signal toggleNetwork(var scr, real anchorX)
    signal toggleOverview()

    // Notifications that arrived since the history panel was last opened —
    // the count on the bar bell.
    property int unreadNotifications: 0
    // Arrival time per notification id; Notification itself has no timestamp.
    property var receivedTimes: ({})

    /**
     * Finds the screen matching the currently focused Hyprland monitor.
     * @returns {var} Screen object or null if not found.
     */
    function getFocusedScreen() {
        if (!Hyprland.focusedMonitor) return null;
        var name = Hyprland.focusedMonitor.name;
        return Quickshell.screens.find(scr => scr.name === name) || null;
    }

    /**
     * Shows a singleton overlay panel on the focused screen, or hides it if
     * already visible. Shared by every toggleX signal below.
     * @param {var} panel Panel instance with `visible` and `screen` properties.
     */
    function togglePanel(panel) {
        if (panel.visible) {
            panel.visible = false;
            return;
        }
        var scr = getFocusedScreen();
        if (scr) panel.screen = scr;
        panel.visible = true;
    }

    onTogglePowerMenu: togglePanel(powerMenuPanel)
    onToggleCalendar: togglePanel(calendarPanel)
    onToggleWallpaperSelector: wallpaperSelectorPanel.toggle(getFocusedScreen())
    onToggleNotifications: {
        togglePanel(notificationCenter);
        if (notificationCenter.visible) unreadNotifications = 0;
    }
    onToggleOverview: overviewPanel.toggle(getFocusedScreen())
    onToggleCheatsheet: cheatsheetPanel.toggle(getFocusedScreen())
    onToggleNetwork: (scr, anchorX) => networkPanel.toggle(scr, anchorX)

    // ▓▒░ POWER MENU — SUPER+Backspace (GlobalShortcut registered here to avoid duplication per-monitor)
    GlobalShortcut {
        appid: "quickshell"
        name: "toggle-power-menu"
        description: "Toggle power menu"
        onPressed: root.togglePowerMenu()
    }

    // ▓▒░ TOP BAR NAVIGATION — SUPER+B
    GlobalShortcut {
        appid: "quickshell"
        name: "focus-bar"
        description: "Focus the top bar for keyboard navigation"
        onPressed: root.toggleBarFocus()
    }

    // ▓▒░ WALLPAPER SELECTOR
    GlobalShortcut {
        appid: "quickshell"
        name: "toggle-wallpaper-selector"
        description: "Toggle wallpaper selector"
        onPressed: root.toggleWallpaperSelector()
    }

    // ▓▒░ KEYBIND CHEATSHEET — SUPER+H (also the bar's keyboard button)
    // Rebuilt 2026-09-23 (panels/Cheatsheet.qml); the old ShortcutsPanel is in
    // ~/.config/config_archive/quickshell/. Name kept so the bind is unchanged.
    GlobalShortcut {
        appid: "quickshell"
        name: "toggle-shortcuts"
        description: "Toggle keybind cheatsheet"
        onPressed: root.toggleCheatsheet()
    }

    // ▓▒░ NOTIFICATION HISTORY — SUPER+comma (also the bar bell / right-click clock)
    GlobalShortcut {
        appid: "quickshell"
        name: "toggle-notifications"
        description: "Toggle notification history"
        onPressed: root.toggleNotifications()
    }

    // ▓▒░ WINDOW OVERVIEW — SUPER+grave
    GlobalShortcut {
        appid: "quickshell"
        name: "toggle-overview"
        description: "Toggle window overview"
        onPressed: root.toggleOverview()
    }

    // ▓▒░ PIPEWIRE — track default audio sink for volume controls in child components
    Pw.PwObjectTracker {
        objects: {
            var list = [];
            if (Pw.Pipewire.defaultAudioSink) list.push(Pw.Pipewire.defaultAudioSink);
            if (Pw.Pipewire.defaultAudioSource) list.push(Pw.Pipewire.defaultAudioSource);
            return list;
        }
    }

    // ▓▒░ NOTIFICATION SERVER — native Wayland notification daemon
    // Replaces dunst. Receives notifications from all apps via the
    // org.freedesktop.Notifications DBus interface.
    //
    // Every capability below is advertised on purpose: apps check them before
    // sending, and without them Firefox, Chromium and Discord fall back to bare
    // title+body notifications — no buttons, no avatars, no site icons.
    Notifs.NotificationServer {
        id: notificationServer
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true

        // tracked = true is what keeps a notification alive past this handler.
        // Without it quickshell destroys the object on return — there was no
        // history, and every later dismiss() threw "is not a function".
        onNotification: (notification) => {
            notification.tracked = true;
            root.receivedTimes[notification.id] = new Date();
            root.receivedTimesChanged();
            if (!notificationCenter.visible) root.unreadNotifications++;
        }
    }

    // ▓▒░ STATUS BAR — spawned on every connected monitor
    Variants {
        model: Quickshell.screens

        Bar {
            modelData: modelData
        }
    }

    // ▓▒░ NOTIFICATION OSD — floating popups (independent of per-screen bar)
    NotificationOSD {
        notificationServer: notificationServer
        receivedTimes: root.receivedTimes
    }

    // ▓▒░ VOLUME / MIC OSD — follows PipeWire, whatever changed the level
    VolumeOSD {}

    // ▓▒░ APP LAUNCHER — SUPER+A (GlobalShortcut registered inside AppLauncher.qml)
    // Replaces: rofi -show drun
    AppLauncher {}

    // ▓▒░ SCREENSHOT PANEL — Print key (GlobalShortcut registered inside ScreenshotPanel.qml)
    // Replaces: ~/.config/rofi/screenshot.sh
    ScreenshotPanel {
        notificationServer: notificationServer
    }

    // ▓▒░ CLIPBOARD PANEL — SUPER+V (GlobalShortcut registered inside ClipboardPanel.qml)
    // Replaces: cliphist list | wofi --dmenu
    ClipboardPanel {}

    // ▓▒░ OVERLAY PANELS (Layer-shell frosted blur matching bar)
    PowerMenu {
        id: powerMenuPanel
    }

    CalendarPanel {
        id: calendarPanel
    }

    // ▓▒░ NETWORK PANEL — drops down from the bar's network item (no shortcut)
    // Rebuilt 2026-09-23; the old one is in ~/.config/config_archive/quickshell/.
    NetworkPanel {
        id: networkPanel
    }

    WallpaperSelector {
        id: wallpaperSelectorPanel
    }

    NotificationCenter {
        id: notificationCenter
        notificationServer: notificationServer
        receivedTimes: root.receivedTimes
    }

    Overview {
        id: overviewPanel
    }

    Cheatsheet {
        id: cheatsheetPanel
    }
}
