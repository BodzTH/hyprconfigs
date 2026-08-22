import QtQuick
import ".."
import "../services"

Rectangle {
    id: netSpeedWidget

    height: 28
    width: contentRow.implicitWidth
    radius: 6
    antialiasing: true
    color: "transparent"

    function formatSpeed(kbps) {
        return (kbps / 1024).toFixed(1) + "M"
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        // Download
        Row {
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: "󰇚"
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.success
                font.family: Theme.fontMain
                font.pixelSize: 14
                renderType: Text.NativeRendering
            }
            Text {
                text: netSpeedWidget.formatSpeed(SysMonitorService.downloadSpeed)
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.text
                font.family: Theme.fontMain
                font.pixelSize: 11
                font.weight: Font.Bold
                renderType: Text.NativeRendering
            }
        }

        // Upload
        Row {
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: "󰕒"
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.subtext0
                font.family: Theme.fontMain
                font.pixelSize: 14
                renderType: Text.NativeRendering
            }
            Text {
                text: netSpeedWidget.formatSpeed(SysMonitorService.uploadSpeed)
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.text
                font.family: Theme.fontMain
                font.pixelSize: 11
                font.weight: Font.Bold
                renderType: Text.NativeRendering
            }
        }
    }
}
