import QtQuick
import Quickshell.Hyprland
import qs

Rectangle {
    id: submapWidget

    property string submap: ""

    height: 28
    width: submapText.implicitWidth + 16
    radius: 4
    antialiasing: true
    color: Theme.accent
    visible: submap !== "" && submap !== "default"

    Text {
        id: submapText
        anchors.centerIn: parent
        text: submapWidget.submap.toUpperCase()
        color: Theme.base
        
        font.family: Theme.fontMain
        font.pixelSize: 12
        font.weight: Font.ExtraBold
        renderType: Text.NativeRendering
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "submap") {
                submapWidget.submap = event.data.trim();
            }
        }
    }
}
