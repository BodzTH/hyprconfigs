import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../services"
import "../panels"

Rectangle {
    id: bluetoothWidget

    required property var parentWindow

    readonly property bool isEnabled: BluetoothService.isEnabled
    readonly property bool isConnected: BluetoothService.isConnected
    readonly property string connectedDevice: BluetoothService.connectedDevice

    function getIcon() {
        if (!isEnabled) return "󰂲";
        if (isConnected) return "󰂱";
        return "󰂯";
    }

    function getText() {
        if (!isEnabled) return "Off";
        if (isConnected) return connectedDevice || "Connected";
        return "On";
    }

    height: 28
    width: contentRow.implicitWidth + 16
    radius: 6
    antialiasing: true

    activeFocusOnTab: true
    HoverHandler { id: bluetoothHover }
    property bool isHoveredOrFocused: bluetoothHover.hovered || bluetoothWidget.activeFocus
    color: isHoveredOrFocused ? Theme.hoverBg : "transparent"


    Behavior on color { ColorAnimation { duration: 150 } }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: isHoveredOrFocused ? 4 : 0

        Behavior on spacing { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 16; height: 16

            Text {
                id: bluetoothIcon
                anchors.centerIn: parent
                verticalAlignment: Text.AlignVCenter
                color: !isEnabled ? Theme.subtext0
                    : isConnected ? Theme.success : Theme.accent
                font.family: Theme.fontMain
                font.pixelSize: 14
                renderType: Text.NativeRendering
                text: bluetoothWidget.getIcon()
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }

        Text {
            id: bluetoothText
            anchors.verticalCenter: parent.verticalCenter
            verticalAlignment: Text.AlignVCenter
            color: !isEnabled ? Theme.subtext0 : Theme.text
            font.family: Theme.fontMain
            font.pixelSize: 10
            font.weight: Font.Bold
            renderType: Text.NativeRendering

            clip: true
            width: isHoveredOrFocused ? implicitWidth : 0
            opacity: isHoveredOrFocused ? 1.0 : 0.0

            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200 } }

            text: bluetoothWidget.getText()
        }
    }

    Keys.onReturnPressed: BluetoothService.toggle()
    Keys.onSpacePressed: BluetoothService.toggle()

    // Own scope, not quickshell.service's cgroup — see panels/AppLauncher.qml.
    function openManager() {
        Quickshell.execDetached([
            "systemd-run", "--user", "--scope", "--quiet", "--collect",
            "--slice=app.slice", "--description=bluetooth manager",
            "sh", "-c", "blueman-manager || overskride || gnome-control-center bluetooth || ghostty -e bluetoothctl || kitty -e bluetoothctl || alacritty -e bluetoothctl || foot -e bluetoothctl || xterm -e bluetoothctl"
        ]);
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                BluetoothService.toggle();
            } else if (mouse.button === Qt.RightButton) {
                bluetoothWidget.openManager();
            }
        }
    }
}
