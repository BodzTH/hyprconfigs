import QtQuick
import qs
import qs.services

// NotificationButton — bar bell. Left click opens the notification history,
// right click toggles Do Not Disturb. Shows the count of notifications that
// arrived since the history was last opened.
BarItem {
    id: bellBtn

    width: bellRow.implicitWidth + 16
    HoverHandler { id: btnHover; cursorShape: Qt.PointingHandCursor }

    Keys.onReturnPressed: root.toggleNotifications()
    Keys.onSpacePressed: root.toggleNotifications()


    readonly property int unread: root.unreadNotifications

    Row {
        id: bellRow
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: DndService.isEnabled ? "󰪑" : (bellBtn.unread > 0 ? "󰂟" : "󰂜")
            color: bellBtn.tint(DndService.isEnabled || bellBtn.unread > 0 ? Theme.accent : Theme.text)
            font.family: Theme.fontMain
            font.pixelSize: 14
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: bellBtn.unread > 0
            text: bellBtn.unread > 99 ? "99+" : bellBtn.unread
            color: bellBtn.tint(DndService.isEnabled || bellBtn.unread > 0 ? Theme.accent : Theme.text)
            font.family: Theme.fontMain
            font.pixelSize: Theme.fontSize
            font.weight: Font.Bold
            renderType: Text.NativeRendering
        }
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: root.toggleNotifications()
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: DndService.toggle()
    }
}
