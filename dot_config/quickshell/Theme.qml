pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Singleton (not QtObject) so it can hold the FileView and IpcHandler below.
Singleton {
    id: theme

    // Graphite-Dark (GTK Theme Matched) Palette
    readonly property color base: "#111111"       // Matches @theme_bg_color
    readonly property color bgContainer: "#181818"     // Matches @headerbar_backdrop_color / container background
    readonly property color bgSelection: Qt.rgba(1, 1, 1, 0.12) // Translucent glass selection matching blur theme
    readonly property color borderBase: Qt.rgba(1, 1, 1, 0.12) // Matches @borders
    readonly property color text: "#ffffff"       // Matches @theme_fg_color
    readonly property color subtext0: Qt.rgba(1, 1, 1, 0.5) // Matches @insensitive_fg_color
    // Wallpaper accent — the same colour as the window border and hyprlock.
    // Set live by ~/.config/hypr/scripts/sync_border.py over IPC:
    //   qs ipc call theme setAccent RRGGBB
    // It used to rewrite this file and let quickshell hot-reload, but a write
    // landing while the previous reload was still running was missed — the
    // bar kept the old colour in 5 of 10 rapid-change trials (2026-09-23) —
    // and every change rebuilt the whole shell. IPC changes one property.
    // The literal below is only the fallback before the state file is read.
    property color accent: "#e5e5e5"
    readonly property color success: "#81c995"      // Matches @success_color
    readonly property color error: "#f28b82"        // Matches @error_color

    readonly property color hoverBg: Qt.rgba(1, 1, 1, 0.1)  // matches @wm_highlight
    readonly property color borderMuted: Qt.rgba(1, 1, 1, 0.12) // matches @borders

    readonly property color glassBg: Qt.rgba(0.05, 0.05, 0.05, 0.25) // Frosted translucent glass matching base with blur
    readonly property color glassBorder: Qt.rgba(1, 1, 1, 0.08)    // Ultra-thin luminous border
    readonly property color activeGlow: Qt.rgba(1, 1, 1, 0.15)    // Active highlight backdrop glow

    // Caskaydia Cove Typographic Stack
    readonly property string fontMain: "CaskaydiaCove Nerd Font, CaskaydiaCove NF, Cascadia Code, monospace"

    // Metrics
    readonly property int barHeight: 28
    readonly property int widgetRadius: 6
    readonly property int fontSize: 11
    readonly property int padding: 4

    function applyAccent(hex) {
        var h = String(hex).trim().replace(/^#/, "");
        if (/^[0-9a-fA-F]{6}$/.test(h)) theme.accent = "#" + h;
    }

    // Survives quickshell restarts: sync_border.py also writes the accent here,
    // and it is read once at startup (no watch — IPC covers live changes).
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/hypr/accent"
        onLoaded: theme.applyAccent(text())
    }

    IpcHandler {
        target: "theme"
        function setAccent(hex: string): void { theme.applyAccent(hex); }
    }
}
