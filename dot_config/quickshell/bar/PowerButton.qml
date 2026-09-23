import QtQuick
import Quickshell
import qs

BarItem {
    id: powerBtnWidget

    required property var parentWindow

    width: 28
    HoverHandler { id: btnHover }
    property bool isHoveredOrFocused: btnHover.hovered || powerBtnWidget.activeFocus
    

    Keys.onReturnPressed: root.togglePowerMenu()
    Keys.onSpacePressed: root.togglePowerMenu()


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
