import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services

BarItem {
    id: sysMonitorWidget

    width: contentLayout.implicitWidth + 20
    
    HoverHandler { id: sysMonitorHover }
    property bool isHoveredOrFocused: sysMonitorHover.hovered || sysMonitorWidget.activeFocus

    


    property bool showMemGb: true

    TapHandler {
        onTapped: {
            // Own scope, not quickshell.service's cgroup — see panels/AppLauncher.qml.
            Quickshell.execDetached([
                "systemd-run", "--user", "--scope", "--quiet", "--collect",
                "--slice=app.slice", "--description=btop",
                "kitty", "-e", "btop"
            ])
        }
    }

    Row {
        id: contentLayout
        anchors.centerIn: parent
        spacing: 10

        // CPU Section
        Row {
            spacing: 4

            Text {
                text: ""
                anchors.verticalCenter: parent.verticalCenter
                color: SysMonitorService.cpuUsage >= 85 ? Theme.error : Theme.subtext0
                font.family: Theme.fontMain
                font.pixelSize: 13
                renderType: Text.NativeRendering
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            Text {
                id: cpuText
                anchors.verticalCenter: parent.verticalCenter
                text: SysMonitorService.cpuUsage.toString().padStart(2, '0') + "%"
                color: SysMonitorService.cpuUsage >= 85 ? Theme.error : Theme.text
                font.family: Theme.fontMain
                font.pixelSize: 10
                font.weight: Font.Bold
                renderType: Text.NativeRendering
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        // Memory Section
        Row {
            spacing: 4

            Text {
                text: "󰘚"
                anchors.verticalCenter: parent.verticalCenter
                color: SysMonitorService.memUsage >= 85 ? Theme.error : Theme.subtext0
                font.family: Theme.fontMain
                font.pixelSize: 13
                renderType: Text.NativeRendering
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            Text {
                id: memText
                anchors.verticalCenter: parent.verticalCenter
                text: sysMonitorWidget.showMemGb ? (SysMonitorService.memUsed || (SysMonitorService.memUsage + "%")) : (SysMonitorService.memUsage.toString().padStart(2, '0') + "%")
                color: SysMonitorService.memUsage >= 85 ? Theme.error : Theme.text
                font.family: Theme.fontMain
                font.pixelSize: 10
                font.weight: Font.Bold
                renderType: Text.NativeRendering
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }
    }
}
