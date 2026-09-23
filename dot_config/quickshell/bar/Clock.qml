import QtQuick
import Quickshell
import qs

BarItem {
    id: clockWidget

    required property var parentWindow

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    width: timeText.implicitWidth + 20
    

    Keys.onReturnPressed: root.toggleCalendar()
    Keys.onSpacePressed: root.toggleCalendar()


    Text {
        id: timeText
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "ddd h:mm:ss AP")
        // Text, not accent: the accent follows the wallpaper now (sync_border.py)
        // and a mid-tone blue clock on a dark bar reads worse than platinum did.
        color: Theme.text

        font.family: Theme.fontMain
        font.pixelSize: Theme.fontSize
        font.weight: Font.Bold
        renderType: Text.NativeRendering
    }

    HoverHandler {
        id: clockHover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: root.toggleCalendar()
    }
    // Right click: notification history (the bar bell does the same)
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: root.toggleNotifications()
    }
}
