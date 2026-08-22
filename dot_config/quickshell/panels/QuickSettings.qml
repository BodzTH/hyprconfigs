import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire as Pw
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "../services"

PanelWindow {
    id: quickSettingsPopup
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-screenshot"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: -1

    // Background click-to-close
    MouseArea {
        anchors.fill: parent
        onClicked: quickSettingsPopup.visible = false
    }

    // Timer to update toggle states when showing popup
    onVisibleChanged: {
        if (visible) {
            NetworkService.updateWifiStatus();
            BluetoothService.updateStatus();
        }
    }

    Rectangle {
        anchors { top: parent.top; right: parent.right }
        anchors.topMargin: 52
        anchors.rightMargin: 16
        width: 280
        height: 180
        color: Theme.glassBg
        border.color: Theme.glassBorder
        border.width: 1
        radius: 19
        antialiasing: true

        // Block background click propagation
        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            // Grid of toggles
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                QuickToggle {
                    iconText: NetworkService.wifiEnabled ? "󰖩" : "󰖪"
                    subtitleText: NetworkService.wifiEnabled ? (NetworkService.ssid || "On") : "Off"
                    isEnabled: NetworkService.wifiEnabled
                    onToggled: NetworkService.toggleWifi()
                }

                QuickToggle {
                    iconText: "󰂯"
                    subtitleText: BluetoothService.isEnabled ? (BluetoothService.connectedDevice || "On") : "Off"
                    isEnabled: BluetoothService.isEnabled
                    onToggled: BluetoothService.toggle()
                }

                QuickToggle {
                    iconText: "󰂛"
                    subtitleText: DndService.isEnabled ? "On" : "Off"
                    isEnabled: DndService.isEnabled
                    onToggled: DndService.toggle()
                }
            }

            // Volume Slider
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Volume"
                        color: Theme.text
                        font.family: Theme.fontMain
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: {
                            if (!Pw.Pipewire.defaultAudioSink || !Pw.Pipewire.defaultAudioSink.audio) return "00%"
                            var audio = Pw.Pipewire.defaultAudioSink.audio
                            if (audio.muted) return "MUT"
                            return Math.round(audio.volume * 100) + "%"
                        }
                        color: Theme.subtext0
                        font.family: Theme.fontMain
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                }

                Slider {
                    Layout.fillWidth: true
                    from: 0
                    to: 100
                    value: {
                        if (!Pw.Pipewire.defaultAudioSink || !Pw.Pipewire.defaultAudioSink.audio) return 0
                        return Math.round(Pw.Pipewire.defaultAudioSink.audio.volume * 100)
                    }
                    onMoved: {
                        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (value / 100.0).toFixed(2)]);
                    }

                    // Theme matching style
                    background: Rectangle {
                        x: parent.leftPadding
                        y: parent.topPadding + parent.availableHeight / 2 - height / 2
                        implicitWidth: 200
                        implicitHeight: 4
                        width: parent.availableWidth
                        height: implicitHeight
                        radius: 2
                        antialiasing: true
                        color: Theme.bgSelection

                        Rectangle {
                            width: parent.parent.visualPosition * parent.width
                            height: parent.height
                            color: Theme.text
                            radius: 2
                            antialiasing: true
                        }
                    }

                    handle: Rectangle {
                        x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                        y: parent.topPadding + parent.availableHeight / 2 - height / 2
                        implicitWidth: 12
                        implicitHeight: 12
                        radius: 6
                        antialiasing: true
                        color: Theme.text
                        border.color: Theme.base
                        border.width: 1
                    }
                }
            }
        }
    }
}
