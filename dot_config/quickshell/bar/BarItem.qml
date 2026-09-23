import QtQuick
import qs

// BarItem — the shared look of every interactive item in the bar.
//
// Before this, each widget carried its own copy of the same few lines: a
// flat white 10% background on hover *or* keyboard focus, 150ms, no accent, no
// press feedback, and a hand cursor on only some of them. Now one place
// decides:
//
//   hover     a quiet glass lift — soft white tint + hairline edge, easing in.
//             No accent: accent on every hover read as "gamey" (Bodz,
//             2026-09-23); the accent is kept for things that *mean* something.
//   focus     (keyboard, SUPER+B) solid accent outline — the one accent here,
//             so the focus is findable while the mouse also rests on the bar
//   press     a touch brighter — no scale change; any squish, even a gentle
//             one, read as bouncy next to the calm hover
//
// Widgets use `BarItem { ... }` as their root instead of `Rectangle` and keep
// their own content, clicks and hover-reveal logic. `hovered` / `pressed` are
// exposed for widgets that want them.
Rectangle {
    id: item

    readonly property bool hovered: hoverHandler.hovered
    // PointHandler takes only a passive grab, so it still sees the press when
    // a widget's own MouseArea / TapHandler takes the click.
    readonly property bool pressed: pressHandler.active
    readonly property bool focused: activeFocus
    // A resting "this one is current" state (e.g. the active window in the
    // taskbar): neutral glow, under hover/focus/press.
    property bool selected: false

    // White with a given alpha. The resting state is alpha 0 of the same
    // white, so the fade never passes through a darker colour.
    function glass(a) { return Qt.rgba(1, 1, 1, a); }

    height: 28
    radius: 6
    antialiasing: true
    activeFocusOnTab: true

    color: pressed ? glass(0.13)
         : hovered ? glass(0.08)
         : focused ? glass(0.06)
         : selected ? Theme.activeGlow
         : glass(0)
    border.width: 1
    border.color: focused ? Theme.accent
                : hovered ? glass(0.10)
                : glass(0)

    Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.InOutQuad } }
    Behavior on border.color { ColorAnimation { duration: 180; easing.type: Easing.InOutQuad } }

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
    }

    PointHandler {
        id: pressHandler
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    }
}
