import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import ".."

PanelWindow {
    id: bar
    required property var modelData
    required property var notificationServer

    screen: modelData
    implicitHeight: 44
    exclusiveZone: 48 // Account for top margin and height
    color: "transparent"

    property bool isKeyboardFocused: false
    WlrLayershell.keyboardFocus: isKeyboardFocused ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Connections {
        target: root
        function onToggleBarFocus() {
            if (Hyprland.focusedMonitor && bar.screen && Hyprland.focusedMonitor.name === bar.screen.name) {
                bar.isKeyboardFocused = !bar.isKeyboardFocused;
                if (bar.isKeyboardFocused) {
                    barContentItem.forceActiveFocus();
                }
            }
        }
    }

    margins {
        top: 7
        left: 11
        right: 11
    }

    anchors {
        top: true
        left: true
        right: true
    }

    Item {
        id: barContentItem
        anchors.fill: parent
        anchors.margins: 3
        focus: bar.isKeyboardFocused

        Keys.onEscapePressed: {
            bar.isKeyboardFocused = false;
        }

        // LEFT MODULE: Workspaces, Taskbar, Submap, Window Title
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: 38
            width: leftRow.implicitWidth + 24
            color: Theme.glassBg
            radius: 19
            antialiasing: true
            Row {
                id: leftRow
                anchors.centerIn: parent
                spacing: 12

                Workspaces {}
                Taskbar {}
                SubmapIndicator {}
            }
        }

        // CENTER MODULE: Media, Idle Inhibitor, Clock
        Rectangle {
            anchors.centerIn: parent
            height: 38
            width: centerRow.implicitWidth + 32
            color: Theme.glassBg
            radius: 19
            antialiasing: true
            Row {
                id: centerRow
                anchors.centerIn: parent
                spacing: 16

                MediaWidget {}
                IdleInhibitorWidget {}
                Clock { parentWindow: bar }
            }
        }

        // RIGHT MODULE: SysMonitor, Keyboard, Audio, Mic, Network, Battery, Notification, Settings, Tray, Power
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 38
            width: rightRow.implicitWidth + 24
            color: Theme.glassBg
            radius: 19
            antialiasing: true
            Row {
                id: rightRow
                anchors.centerIn: parent
                spacing: 10

                SysMonitor {}
                KeyboardLayout {}
                AudioWidget {}
                MicWidget {}
                NetworkSpeedWidget {}
                NetworkWidget { parentWindow: bar }
                BluetoothWidget { parentWindow: bar }
                BatteryWidget {}
                ScreenshotButton { parentWindow: bar }
                SystemTray { parentWindow: bar }
                PowerButton { parentWindow: bar }
            }
        }
    }
}
