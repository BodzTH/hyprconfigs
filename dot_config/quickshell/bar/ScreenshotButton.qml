import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.panels

// ScreenshotButton — lives in the bar, triggers ScreenshotPanel popup
BarItem {
    id: screenshotBtn

    required property var parentWindow

    width: 28
    HoverHandler { id: btnHover }
    property bool isHoveredOrFocused: btnHover.hovered || screenshotBtn.activeFocus
    

    Keys.onReturnPressed: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.global(\"quickshell:toggle-screenshot\")"])
    Keys.onSpacePressed: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.global(\"quickshell:toggle-screenshot\")"])


    Text {
        anchors.centerIn: parent
        text: "󰹑"
        color: Theme.text
        font.family: Theme.fontMain
        font.pixelSize: 14
    }

    // HoverHandler moved up

    TapHandler {
        onTapped: {
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.global(\"quickshell:toggle-screenshot\")"]);
        }
    }
}
