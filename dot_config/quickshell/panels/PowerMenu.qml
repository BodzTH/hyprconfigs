import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."

PanelWindow {
    id: powerMenuPopup
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
        onClicked: powerMenuPopup.visible = false
    }

    property int selectedIndex: 0

    onVisibleChanged: {
        if (visible) {
            selectedIndex = 0;
            powerMenuRect.forceActiveFocus();
        }
    }

    Rectangle {
        id: powerMenuRect
        anchors { top: parent.top; right: parent.right }
        anchors.topMargin: 52
        anchors.rightMargin: 16
        width: 290
        height: 54
        color: Theme.glassBg
        border.color: Theme.glassBorder
        border.width: 1
        radius: 19
        antialiasing: true
        focus: true

        // Block background click propagation
        MouseArea { anchors.fill: parent; onClicked: {} }

        Keys.onLeftPressed: selectedIndex = (selectedIndex - 1 + 5) % 5
        Keys.onUpPressed: selectedIndex = (selectedIndex - 1 + 5) % 5
        Keys.onRightPressed: selectedIndex = (selectedIndex + 1) % 5
        Keys.onDownPressed: selectedIndex = (selectedIndex + 1) % 5
        Keys.onTabPressed: selectedIndex = (selectedIndex + 1) % 5
        Keys.onBacktabPressed: selectedIndex = (selectedIndex - 1 + 5) % 5
        Keys.onEscapePressed: powerMenuPopup.visible = false
        Keys.onReturnPressed: {
            if (selectedIndex === 0) {
                powerMenuPopup.visible = false
                Quickshell.execDetached(["bash", "-c", "~/.config/scripts/keycheck.sh && faillock --reset && hyprlock"])
            } else if (selectedIndex === 1) {
                powerMenuPopup.visible = false
                Quickshell.execDetached(["bash", "-c", "~/.config/scripts/keycheck.sh && hyprlock & sleep 1.2 && systemctl suspend"])
            } else if (selectedIndex === 2) {
                Quickshell.execDetached(["bash", "-c", "hyprshutdown"])
            } else if (selectedIndex === 3) {
                Quickshell.execDetached(["bash", "-c", "hyprshutdown -t 'Rebooting...' --post-cmd 'systemctl reboot'"])
            } else if (selectedIndex === 4) {
                Quickshell.execDetached(["bash", "-c", "hyprshutdown -t 'Shutting down...' --post-cmd 'systemctl poweroff'"])
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 6

            // Lock Button
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                antialiasing: true
                color: (lockMouse.hovered || selectedIndex === 0) ? Theme.borderBase : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰌾"
                    color: Theme.text
                    font.family: Theme.fontMain
                    font.pixelSize: 16
                }

                HoverHandler {
                    id: lockMouse
                    onHoveredChanged: if (hovered) selectedIndex = 0
                }
                TapHandler {
                    onTapped: {
                        powerMenuPopup.visible = false
                        Quickshell.execDetached(["bash", "-c", "~/.config/scripts/keycheck.sh && faillock --reset && hyprlock"])
                    }
                }
            }

            // Suspend Button
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                antialiasing: true
                color: (suspendMouse.hovered || selectedIndex === 1) ? Theme.borderBase : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰤄"
                    color: Theme.text
                    font.family: Theme.fontMain
                    font.pixelSize: 16
                }

                HoverHandler {
                    id: suspendMouse
                    onHoveredChanged: if (hovered) selectedIndex = 1
                }
                TapHandler {
                    onTapped: {
                        powerMenuPopup.visible = false
                        Quickshell.execDetached(["bash", "-c", "~/.config/scripts/keycheck.sh && hyprlock & sleep 1.2 && systemctl suspend"])
                    }
                }
            }

            // Logout Button
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                antialiasing: true
                color: (exitMouse.hovered || selectedIndex === 2) ? Theme.borderBase : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰍃"
                    color: Theme.text
                    font.family: Theme.fontMain
                    font.pixelSize: 16
                }

                HoverHandler {
                    id: exitMouse
                    onHoveredChanged: if (hovered) selectedIndex = 2
                }
                TapHandler {
                    onTapped: {
                        Quickshell.execDetached(["bash", "-c", "hyprshutdown"])
                    }
                }
            }

            // Reboot Button
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                antialiasing: true
                color: (rebootMouse.hovered || selectedIndex === 3) ? Theme.borderBase : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰜉"
                    color: Theme.text
                    font.family: Theme.fontMain
                    font.pixelSize: 16
                }

                HoverHandler {
                    id: rebootMouse
                    onHoveredChanged: if (hovered) selectedIndex = 3
                }
                TapHandler {
                    onTapped: {
                        Quickshell.execDetached(["bash", "-c", "hyprshutdown -t 'Rebooting...' --post-cmd 'systemctl reboot'"])
                    }
                }
            }

            // Shutdown Button
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                antialiasing: true
                color: (poweroffMouse.hovered || selectedIndex === 4) ? Theme.borderBase : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰐥"
                    color: Theme.error
                    font.family: Theme.fontMain
                    font.pixelSize: 16
                }

                HoverHandler {
                    id: poweroffMouse
                    onHoveredChanged: if (hovered) selectedIndex = 4
                }
                TapHandler {
                    onTapped: {
                        Quickshell.execDetached(["bash", "-c", "hyprshutdown -t 'Shutting down...' --post-cmd 'systemctl poweroff'"])
                    }
                }
            }
        }
    }
}
