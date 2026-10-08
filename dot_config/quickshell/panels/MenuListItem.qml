import QtQuick
import QtQuick.Layouts
import qs

Rectangle {
    id: root

    property string iconText: ""
    property string labelText: ""
    property bool isSelected: false
    property int itemIndex: -1
    property var parentMenu: null

    signal tapped()

    width: parent ? parent.width : 200
    height: 38
    radius: 12
    antialiasing: true

    // hyprlock power-button style: no row background; icon and label turn
    // accent while hovered or keyboard-selected.
    readonly property bool lit: itemHover.hovered || isSelected
    color: "transparent"

    RowLayout {
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        spacing: 10
        
        Text {
            text: root.iconText
            color: root.lit ? Theme.accent : Theme.text
            Behavior on color { ColorAnimation { duration: 120 } }
            font.family: Theme.fontMain
            font.pixelSize: 16
        }
        
        Text {
            text: root.labelText
            color: root.lit ? Theme.accent : Theme.text
            Behavior on color { ColorAnimation { duration: 120 } }
            font.family: Theme.fontMain
            font.pixelSize: 13
            Layout.fillWidth: true
        }
    }

    HoverHandler {
        id: itemHover
        onHoveredChanged: {
            if (hovered && root.parentMenu !== null && root.itemIndex !== -1) {
                root.parentMenu.selectedIndex = root.itemIndex
            }
        }
    }
    
    TapHandler {
        onTapped: {
            root.tapped()
        }
    }
}
