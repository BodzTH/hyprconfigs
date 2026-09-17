import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import ".."

Row {
    id: systemTrayWidget

    spacing: 6

    required property var parentWindow

    Repeater {
        model: SystemTray.items

        Rectangle {
            id: trayItem
            required property var modelData

            width: 28
            height: 28
            radius: 4
            antialiasing: true
            
            activeFocusOnTab: true
            HoverHandler { id: trayHover }
            color: trayHover.hovered || trayItem.activeFocus ? Theme.hoverBg : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }

            Keys.onReturnPressed: modelData.activate()
            Keys.onSpacePressed: modelData.activate()

            Image {
                anchors.centerIn: parent
                source: modelData.icon
                width: 22
                height: 22
                sourceSize: Qt.size(22, 22)
                fillMode: Image.PreserveAspectFit
            }

            QsMenuAnchor {
                id: menuAnchor
                menu: modelData.menu
                anchor.window: systemTrayWidget.parentWindow
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor

                onClicked: (mouse) => {
                    if (mouse.button !== Qt.RightButton) {
                        modelData.activate();
                        return;
                    }
                    if (modelData.hasMenu) {
                        // Map coordinates to parentWindow
                        var pos = parent.mapToItem(systemTrayWidget.parentWindow.contentItem, mouse.x, mouse.y);
                        menuAnchor.anchor.rect.x = pos.x;
                        menuAnchor.anchor.rect.y = pos.y;
                        menuAnchor.open();
                    }
                }
            }
        }
    }
}
