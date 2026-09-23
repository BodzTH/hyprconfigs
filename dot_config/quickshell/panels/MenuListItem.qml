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

    color: (itemHover.hovered || isSelected) ? Theme.bgSelection : "transparent"
    border.color: (itemHover.hovered || isSelected) ? Theme.glassBorder : "transparent"
    border.width: 1
    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    RowLayout {
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        spacing: 10
        
        Text {
            text: root.iconText
            color: Theme.text
            font.family: Theme.fontMain
            font.pixelSize: 16
        }
        
        Text {
            text: root.labelText
            color: Theme.text
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
