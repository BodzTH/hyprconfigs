import QtQuick
import Quickshell
import ".."
import "../services"
import "../panels"

Rectangle {
    id: networkWidget

    required property var parentWindow

    readonly property string netType: NetworkService.type
    readonly property string netSsid: NetworkService.ssid
    readonly property bool isConnected: netType !== "none"

    function getIcon() {
        if (NetworkService.vpnActive) return "󰌾";
        if (netType === "wifi") return "󰖩";
        if (netType === "ethernet") return "󰈀";
        return "󰖪";
    }

    function getText() {
        if (netType === "wifi") return netSsid || "WiFi";
        if (netType === "ethernet") return netSsid || "Ethernet";
        return "Disconnected";
    }

    height: 28
    width: contentRow.implicitWidth + 16
    radius: 6
    antialiasing: true

    activeFocusOnTab: true
    HoverHandler { id: networkHover }
    property bool isHoveredOrFocused: networkHover.hovered || networkWidget.activeFocus
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
                id: networkIcon
                anchors.centerIn: parent
                verticalAlignment: Text.AlignVCenter
                color: NetworkService.vpnActive ? Theme.success
                    : isConnected ? Theme.accent : Theme.error
                font.family: Theme.fontMain
                font.pixelSize: 14
                renderType: Text.NativeRendering
                text: networkWidget.getIcon()
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }

        Text {
            id: networkText
            anchors.verticalCenter: parent.verticalCenter
            verticalAlignment: Text.AlignVCenter
            color: isConnected ? Theme.text : Theme.error
            font.family: Theme.fontMain
            font.pixelSize: 10
            font.weight: Font.Bold
            renderType: Text.NativeRendering

            clip: true
            width: isHoveredOrFocused ? implicitWidth : 0
            opacity: isHoveredOrFocused ? 1.0 : 0.0

            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200 } }

            text: networkWidget.getText()
        }
    }

    Keys.onReturnPressed: root.toggleNetwork()
    Keys.onSpacePressed: root.toggleNetwork()

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                root.toggleNetwork();
            } else if (mouse.button === Qt.RightButton) {
                NetworkService.openManager();
            }
        }
    }
}
