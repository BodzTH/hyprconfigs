pragma Singleton
import QtQuick

QtObject {
    // Graphite-Dark (GTK Theme Matched) Palette
    readonly property color base: "#111111"       // Matches @theme_bg_color
    readonly property color bgContainer: "#181818"     // Matches @headerbar_backdrop_color / container background
    readonly property color bgSelection: Qt.rgba(1, 1, 1, 0.12) // Translucent glass selection matching blur theme
    readonly property color borderBase: Qt.rgba(1, 1, 1, 0.12) // Matches @borders
    readonly property color text: "#ffffff"       // Matches @theme_fg_color
    readonly property color subtext0: Qt.rgba(1, 1, 1, 0.5) // Matches @insensitive_fg_color
    readonly property color accent: "#e0e0e0"      // Matches @accent_color / active highlight
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
}
