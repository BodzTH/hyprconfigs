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

    // White when idle, accent once it is working (≥ 50%), red when overloaded.
    function load(pct) { return pct >= 85 ? Theme.error : pct >= 50 ? Theme.accent : Theme.text; }

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

            StatBadge {
                label: "CPU"
                kind: "chip"
                tone: sysMonitorWidget.tint(sysMonitorWidget.load(SysMonitorService.cpuUsage))
            }
            Text {
                id: cpuText
                anchors.verticalCenter: parent.verticalCenter
                text: SysMonitorService.cpuUsage.toString().padStart(2, '0') + "%"
                color: sysMonitorWidget.tint(sysMonitorWidget.load(SysMonitorService.cpuUsage))
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

            StatBadge {
                label: "RAM"
                kind: "ram"
                tone: sysMonitorWidget.tint(sysMonitorWidget.load(SysMonitorService.memUsage))
            }
            Text {
                id: memText
                anchors.verticalCenter: parent.verticalCenter
                text: sysMonitorWidget.showMemGb ? (SysMonitorService.memUsed || (SysMonitorService.memUsage + "%")) : (SysMonitorService.memUsage.toString().padStart(2, '0') + "%")
                color: sysMonitorWidget.tint(sysMonitorWidget.load(SysMonitorService.memUsage))
                font.family: Theme.fontMain
                font.pixelSize: 10
                font.weight: Font.Bold
                renderType: Text.NativeRendering
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }
    }
}
