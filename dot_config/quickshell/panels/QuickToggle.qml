import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root

    property string iconText: ""
    property string titleText: ""
    property string subtitleText: ""
    property bool isEnabled: false

    signal toggled()

    Layout.fillWidth: true
    height: 44
    radius: 12
    antialiasing: true
    color: toggleMouse.hovered ? Theme.borderBase : Theme.bgSelection
    border.color: isEnabled ? Theme.text : "transparent"
    border.width: 1

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 2
        Text {
            text: root.iconText
            color: Theme.text
            font.family: Theme.fontMain
            font.pixelSize: 14
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        Text {
            text: root.subtitleText || root.titleText
            color: Theme.subtext0
            font.family: Theme.fontMain
            font.pixelSize: 9
            font.weight: Font.Bold
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            Layout.maximumWidth: 70
        }
    }

    HoverHandler { id: toggleMouse }
    TapHandler {
        onTapped: {
            root.toggled()
        }
    }
}
