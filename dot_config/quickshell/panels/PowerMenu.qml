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

    // ▓▒░ CGROUP-SAFE LAUNCH — do not go back to bare Quickshell.execDetached here
    //
    // execDetached detaches the *process* but not the *cgroup*: the child reparents
    // to init yet stays inside quickshell.service. That unit is KillMode=control-group
    // (the systemd default), so the instant quickshell's main PID exits, systemd
    // SIGTERMs everything left in the group.
    //
    // That is fatal for hyprshutdown specifically, because its sequence is:
    //   1. ask every app and layer client to exit  <- this kills quickshell
    //   2. WAIT for them to exit                   <- killed here, with quickshell
    //   3. dispatch hl.dsp.exit()                  <- never reached
    //   4. run --post-cmd                          <- never reached
    // It cannot survive the thing it is waiting for. Observed 2026-09-21: apps and
    // bar closed, Hyprland stayed up, machine never rebooted.
    //
    // systemd-run puts the command in its own transient scope under app.slice --
    // a sibling of quickshell.service, not a child -- so quickshell dying, crashing
    // or being restarted by Restart=on-failure no longer takes it down.
    function runDetached(description, command) {
        Quickshell.execDetached([
            "systemd-run", "--user", "--scope", "--quiet", "--collect",
            "--slice=app.slice", "--description=" + description,
            "bash", "-c", command
        ])
    }

    // ▓▒░ ACTIONS — one definition each, called from both the keyboard handler
    // and the TapHandler. They used to be duplicated per input path, which meant
    // a fix applied to one silently left the other broken.
    //
    // keycheck.sh forces every keyboard back to layout 0 (English) so the lock
    // password is typed in the expected layout -- kb_layout is "us,ara". It can
    // never fail, so it is chained with `;` not `&&`: the lock must still happen.

    // Lock and suspend both go through logind rather than naming hyprlock here.
    // ~/.config/hypr/hypridle.conf's general:lock_cmd is the single definition of
    // "lock this session" (it already does faillock --reset, a pidof guard and
    // --grace 1); calling hyprlock directly duplicated it and broke hypridle's
    // sleep-inhibit detection. Suspend needs no lock step at all -- hypridle's
    // before_sleep_cmd locks on PrepareForSleep and its inhibitor holds the
    // suspend until the session is genuinely locked, which is what the old
    // `hyprlock & sleep 1.2` was guessing at.
    function doLock()     { runDetached("lock session", "~/.config/scripts/keycheck.sh; loginctl lock-session") }
    function doSuspend()  { runDetached("suspend",      "~/.config/scripts/keycheck.sh; systemctl suspend") }

    // --no-fork: run in the foreground of the scope so systemd supervises
    // hyprshutdown itself rather than a daemonized grandchild.
    function doLogout()   { runDetached("hyprshutdown (logout)",   "hyprshutdown --no-fork") }
    function doReboot()   { runDetached("hyprshutdown (reboot)",   "hyprshutdown --no-fork -t 'Rebooting...' --post-cmd 'systemctl reboot'") }
    function doPoweroff() { runDetached("hyprshutdown (poweroff)", "hyprshutdown --no-fork -t 'Shutting down...' --post-cmd 'systemctl poweroff'") }

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
            powerMenuPopup.visible = false
            if (selectedIndex === 0)      powerMenuPopup.doLock()
            else if (selectedIndex === 1) powerMenuPopup.doSuspend()
            else if (selectedIndex === 2) powerMenuPopup.doLogout()
            else if (selectedIndex === 3) powerMenuPopup.doReboot()
            else if (selectedIndex === 4) powerMenuPopup.doPoweroff()
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
                        powerMenuPopup.doLock()
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
                        powerMenuPopup.doSuspend()
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
                        powerMenuPopup.visible = false
                        powerMenuPopup.doLogout()
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
                        powerMenuPopup.visible = false
                        powerMenuPopup.doReboot()
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
                        powerMenuPopup.visible = false
                        powerMenuPopup.doPoweroff()
                    }
                }
            }
        }
    }
}
