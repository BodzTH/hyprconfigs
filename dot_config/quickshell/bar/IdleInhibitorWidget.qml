import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

BarItem {
    id: idleInhibitorWidget

    width: contentRow.implicitWidth + 16
    
    HoverHandler { id: hover }
    

    Keys.onReturnPressed: idleInhibitorWidget.isCaffeineActive = !idleInhibitorWidget.isCaffeineActive
    Keys.onSpacePressed: idleInhibitorWidget.isCaffeineActive = !idleInhibitorWidget.isCaffeineActive


    property bool isCaffeineActive: false

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            verticalAlignment: Text.AlignVCenter
            color: idleInhibitorWidget.isCaffeineActive ? Theme.accent : Theme.subtext0
            font.family: Theme.fontMain
            font.pixelSize: 14
            renderType: Text.NativeRendering
            text: idleInhibitorWidget.isCaffeineActive ? "󰅶" : "󰛊"
        }
    }

    // Native Wayland Idle Inhibitor. Toggling this dynamically instantiates/destroys it,
    // sending idle inhibitor signals directly to the Wayland compositor.
    Loader {
        active: idleInhibitorWidget.isCaffeineActive
        sourceComponent: Component {
            IdleInhibitor {}
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            idleInhibitorWidget.isCaffeineActive = !idleInhibitorWidget.isCaffeineActive;
        }
    }
}
