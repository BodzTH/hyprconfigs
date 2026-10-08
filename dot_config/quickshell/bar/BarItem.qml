import QtQuick
import qs

// BarItem — the shared look of every interactive item in the bar.
//
// Same style as the hyprlock power buttons (2026-10-09, replacing the glass
// lift of 2026-09-23): no background, no border. Resting colour is state:
// white = idle / off, accent = active or consuming (mic live, traffic,
// charging, caffeine, unread…), red = a problem (muted, overloaded). While
// lit — hovered, or keyboard-focused (SUPER+B) — the item turns accent, and an
// item already accent turns a brighter accent, so hover still shows.
// Widgets colour their Text with `tint(restingColour)`.
//
// Widgets use `BarItem { ... }` as their root instead of `Rectangle` and keep
// their own content, clicks and hover-reveal logic. `hovered` / `pressed` /
// `lit` are exposed for widgets that want them.
Rectangle {
    id: item

    readonly property bool hovered: hoverHandler.hovered
    // PointHandler takes only a passive grab, so it still sees the press when
    // a widget's own MouseArea / TapHandler takes the click.
    readonly property bool pressed: pressHandler.active
    readonly property bool focused: activeFocus
    // A resting "this one is current" state (e.g. the active window in the
    // taskbar). Drawn by the widget itself (the taskbar's accent underline);
    // kept as a property so widgets can still read it.
    property bool selected: false

    readonly property bool lit: hovered || focused
    function tint(rest) {
        if (!lit) return rest;
        return Qt.colorEqual(rest, Theme.accent) ? Qt.lighter(Theme.accent, 1.35) : Theme.accent;
    }

    height: 28
    radius: 6
    antialiasing: true
    activeFocusOnTab: true

    color: "transparent"

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
    }

    PointHandler {
        id: pressHandler
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    }
}
