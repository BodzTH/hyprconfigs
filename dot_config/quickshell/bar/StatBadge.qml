import QtQuick
import qs

// CPU / RAM icon for SysMonitor: the label drawn inside a small outline of the
// part — a chip with side pins for "chip", a module with a row of contact pins
// for "ram" — so it reads as an icon in the bar's outline style, not loose caps
// text (Bodz, 2026-10-09; the Nerd chip / RAM-stick glyphs were rejected).
//
// Everything sits on whole pixels: a 1px outline on a half-pixel renders as a
// soft 2px grey line, which is what made the first boxed version look off.
// `tone` colours the whole icon; SysMonitor passes it through tint().
Item {
    id: icon
    property string label: ""
    property string kind: "chip"          // "chip" | "ram"
    property color tone: Theme.text

    readonly property bool isChip: kind === "chip"
    readonly property int pin: 2           // pin length
    // Sized and centred on the label's ink, not its advance box: centring the
    // advance box left the letters 1px right of centre (measured).
    readonly property rect ink: metrics.tightBoundingRect
    readonly property int bodyW: Math.ceil(ink.width) + 8   // border + 3px each side
    readonly property int bodyH: isChip ? 12 : 10

    implicitWidth: bodyW + (isChip ? pin * 2 : 0)
    implicitHeight: 12
    // Whole-pixel vertical centring in the parent Row (anchors could land on .5).
    // RAM drops 1px so its frame, not frame + pins, centres on the value text.
    y: parent ? Math.round((parent.height - height) / 2) + (isChip ? 0 : 1) : 0

    TextMetrics {
        id: metrics
        text: icon.label
        font: labelText.font
    }

    Behavior on tone { ColorAnimation { duration: 150 } }

    Rectangle {
        id: body
        x: icon.isChip ? icon.pin : 0
        y: 0
        width: icon.bodyW
        height: icon.bodyH
        radius: 2
        color: "transparent"
        border.width: 1
        border.color: icon.tone

        Text {
            id: labelText
            x: Math.round((icon.bodyW - icon.ink.width) / 2 - icon.ink.x)
            y: Math.round((icon.bodyH - icon.ink.height) / 2 - icon.ink.y - baselineOffset)
            text: icon.label
            color: icon.tone
            font.family: Theme.fontMain
            font.pixelSize: 8
            font.weight: Font.Bold
            renderType: Text.NativeRendering
        }
    }

    // Chip: two pins out of each side.
    Repeater {
        model: icon.isChip ? [3, 8] : []
        delegate: Item {
            required property int modelData
            Rectangle { x: 0; y: modelData; width: icon.pin; height: 1; color: icon.tone }
            Rectangle { x: icon.pin + icon.bodyW; y: modelData; width: icon.pin; height: 1; color: icon.tone }
        }
    }

    // RAM: contact pins along the bottom edge, with a gap for the key notch.
    Repeater {
        model: icon.isChip ? 0 : Math.floor((icon.bodyW - 4) / 3) + 1
        delegate: Rectangle {
            required property int index
            readonly property int notch: Math.floor((icon.bodyW - 4) / 3 * 0.35)
            visible: index !== notch
            x: 2 + index * 3
            y: icon.bodyH
            width: 1
            height: icon.pin
            color: icon.tone
        }
    }
}
