import QtQuick
import Quickshell
import ".."

Rectangle {
    id: qsWidget

    required property var parentWindow

    height: 28
    width: 28
    radius: 6
    antialiasing: true
    color: widgetHover.hovered ? Theme.hoverBg : "transparent"
    

    Behavior on color { ColorAnimation { duration: 150 } }

    Text {
        anchors.centerIn: parent
        text: "󰒓"
        color: Theme.subtext0
        font.family: Theme.fontMain
        font.pixelSize: 14
    }

    HoverHandler { id: widgetHover }

    TapHandler {
        onTapped: root.toggleQuickSettings()
    }
}
