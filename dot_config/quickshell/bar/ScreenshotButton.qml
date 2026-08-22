import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../panels"

// ScreenshotButton — lives in the bar, triggers ScreenshotPanel popup
Rectangle {
    id: screenshotBtn

    required property var parentWindow

    height: 28
    width: 28
    radius: 6
    antialiasing: true
    activeFocusOnTab: true
    HoverHandler { id: btnHover }
    property bool isHoveredOrFocused: btnHover.hovered || screenshotBtn.activeFocus
    color: isHoveredOrFocused ? Theme.hoverBg : "transparent"
    

    Keys.onReturnPressed: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.global(\"quickshell:toggle-screenshot\")"])
    Keys.onSpacePressed: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.global(\"quickshell:toggle-screenshot\")"])

    Behavior on color { ColorAnimation { duration: 150 } }

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
