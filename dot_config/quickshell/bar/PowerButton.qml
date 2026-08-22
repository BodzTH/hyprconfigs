import QtQuick
import Quickshell
import ".."

Rectangle {
    id: powerBtnWidget

    required property var parentWindow

    height: 28
    width: 28
    radius: 6
    antialiasing: true
    activeFocusOnTab: true
    HoverHandler { id: btnHover }
    property bool isHoveredOrFocused: btnHover.hovered || powerBtnWidget.activeFocus
    color: isHoveredOrFocused ? Theme.hoverBg : "transparent"
    

    Keys.onReturnPressed: root.togglePowerMenu()
    Keys.onSpacePressed: root.togglePowerMenu()

    Behavior on color { ColorAnimation { duration: 150 } }

    Text {
        anchors.centerIn: parent
        text: "󰐥"
        color: Theme.error
        font.family: Theme.fontMain
        font.pixelSize: 14
    }

    TapHandler {
        onTapped: root.togglePowerMenu()
    }
}
