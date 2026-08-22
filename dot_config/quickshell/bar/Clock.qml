import QtQuick
import Quickshell
import ".."

Rectangle {
    id: clockWidget

    required property var parentWindow

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    height: Theme.barHeight
    width: timeText.implicitWidth + 20
    radius: Theme.widgetRadius
    antialiasing: true
    activeFocusOnTab: true
    color: clockHover.hovered || clockWidget.activeFocus ? Theme.hoverBg : "transparent"
    

    Keys.onReturnPressed: root.toggleCalendar()
    Keys.onSpacePressed: root.toggleCalendar()

    Behavior on color { ColorAnimation { duration: 150 } }

    Text {
        id: timeText
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "ddd h:mm:ss AP")
        color: Theme.accent
        
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
        onTapped: root.toggleCalendar()
    }
}
