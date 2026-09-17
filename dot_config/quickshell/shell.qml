//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire as Pw
import Quickshell.Services.Notifications as Notifs
import "bar"
import "panels"

ShellRoot {
    id: root

    signal togglePowerMenu()
    signal toggleBarFocus()
    signal toggleCalendar()
    signal toggleNetwork()
    signal toggleWallpaperSelector()

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
    onToggleNetwork: togglePanel(networkPanel)
    onToggleWallpaperSelector: wallpaperSelectorPanel.toggle(getFocusedScreen())

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
    Notifs.NotificationServer {
        id: notificationServer
        keepOnReload: true
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
    }

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

    NetworkPanel {
        id: networkPanel
    }

    WallpaperSelector {
        id: wallpaperSelectorPanel
    }
}
