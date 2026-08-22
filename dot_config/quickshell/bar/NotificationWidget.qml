import QtQuick
import Quickshell
import ".."

Rectangle {
    id: notifWidget

    required property var parentWindow
    required property var notificationServer

    readonly property int notifCount: (notificationServer && notificationServer.trackedNotifications) ? notificationServer.trackedNotifications.count : 0
    readonly property bool hasNotifs: notifCount > 0

    height: 28
    width: 28
    radius: 6
    antialiasing: true
    color: widgetHover.hovered ? Theme.hoverBg : "transparent"
    

    Behavior on color { ColorAnimation { duration: 150 } }

    Text {
        anchors.centerIn: parent
        text: hasNotifs ? "󰇯" : "󰇮"
        color: hasNotifs ? Theme.accent : Theme.subtext0
        font.family: Theme.fontMain
        font.pixelSize: 14
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    // Badge showing unread count
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 2
        anchors.rightMargin: 2
        width: 12
        height: 12
        radius: 6
        antialiasing: true
        color: Theme.text
        border.color: Theme.base
        border.width: 1
        visible: hasNotifs

        Text {
            anchors.centerIn: parent
            text: notifCount.toString()
            color: Theme.base
            font.family: Theme.fontMain
            font.pixelSize: 8
            font.weight: Font.Bold
            renderType: Text.NativeRendering
        }
    }

    HoverHandler { id: widgetHover }

    TapHandler {
        onTapped: root.toggleNotifications()
    }
}
