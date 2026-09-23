import QtQuick
import QtCore
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications as Notifs
import qs

// ScreenshotPanel — equivalent of the old rofi screenshot.sh
// Triggered by: Print key (global shortcut) or bar button
// Options: Copy to clipboard | Save to file | Save & Copy
//
// Old: dunstify for notifications → New: quickshell NotificationServer

Item {
    id: screenshotRoot

    // Pass the notification server in from shell.qml
    property var notificationServer

    property string screenshotDir: "~/Pictures/Screenshots"

    // ▓▒░ GLOBAL SHORTCUT — Print key triggers this panel
    // Hyprland bind: , Print, global, quickshell:toggle-screenshot
    GlobalShortcut {
        appid: "quickshell"
        name: "toggle-screenshot"
        description: "Toggle screenshot menu"
        onPressed: {
            if (screenshotOverlay.visible) {
                screenshotOverlay.visible = false;
                return;
            }
            var scr = root.getFocusedScreen();
            if (scr) {
                screenshotOverlay.screen = scr;
            }
            screenshotOverlay.visible = true;
        }
    }

    // ▓▒░ PROCESSES — launched after panel closes (avoids panel appearing in shot)
    Process {
        id: copyProc
        property string outFile: "/tmp/qs_screenshot.png"
        command: ["bash", "-c",
            'grim "' + outFile + '" && wl-copy -t image/png < "' + outFile + '"'
        ]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                screenshotRoot.sendNotif("Screenshot", "Copied to clipboard!")
            }
        }
    }

    Process {
        id: saveProc
        property string outFileName: ""
        command: ["bash", "-c", 'mkdir -p ~/Pictures/Screenshots && grim ~/Pictures/Screenshots/"' + outFileName + '"']
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                screenshotRoot.sendNotif("Screenshot", "Saved to ~/Pictures/Screenshots/" + outFileName)
            }
        }
    }

    Process {
        id: saveCopyProc
        property string outFileName: ""
        command: ["bash", "-c",
            'mkdir -p ~/Pictures/Screenshots && grim ~/Pictures/Screenshots/"' + outFileName + '" && wl-copy -t image/png < ~/Pictures/Screenshots/"' + outFileName + '"'
        ]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                screenshotRoot.sendNotif("Screenshot", "Saved & copied!")
            }
        }
    }

    // ▓▒░ DELAY TIMER — waits for the overlay to fully hide before grim runs
    // This prevents the screenshot widget from appearing in the captured image.
    Timer {
        id: shotDelay
        interval: 300   // ms — enough for the layer-shell surface to disappear
        repeat: false
        property int pendingAction: -1   // 0=copy, 1=save, 2=saveCopy
        property string pendingName: ""
        onTriggered: {
            if (pendingAction === 0) {
                copyProc.running = true
            } else if (pendingAction === 1) {
                saveProc.outFileName = pendingName
                saveProc.running = true
            } else if (pendingAction === 2) {
                saveCopyProc.outFileName = pendingName
                saveCopyProc.running = true
            }
        }
    }

    function scheduleShot(action, fname) {
        shotDelay.stop()
        shotDelay.pendingAction = action
        shotDelay.pendingName   = fname
        shotDelay.start()
    }

    function sendNotif(summary, body) {
        if (notificationServer) {
            notificationServer.createNotification({
                appName: "Screenshot",
                summary: summary,
                body: body
            })
        }
    }

    function timestamp() {
        return Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss")
    }

    // ▓▒░ OVERLAY PANEL — slides in from top-right like the old rofi screenshot
    PanelWindow {
        id: screenshotOverlay
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
            onClicked: screenshotOverlay.visible = false
        }

        property int selectedIndex: 0

        onVisibleChanged: {
            if (visible) {
                selectedIndex = 0;
                contentContainer.forceActiveFocus();
            }
        }

        Rectangle {
            id: contentContainer
            anchors { top: parent.top; right: parent.right }
            anchors.topMargin: 52
            anchors.rightMargin: 16
            width: 220
            height: contentCol.implicitHeight + 20

            color: Theme.glassBg
            border.color: Theme.glassBorder
            border.width: 1
            radius: 19
            antialiasing: true
            
            // Block background click propagation
            MouseArea { anchors.fill: parent; onClicked: {} }
            
            focus: true
            Keys.onEscapePressed: screenshotOverlay.visible = false
            Keys.onDownPressed: screenshotOverlay.selectedIndex = (screenshotOverlay.selectedIndex + 1) % 3
            Keys.onUpPressed: screenshotOverlay.selectedIndex = (screenshotOverlay.selectedIndex - 1 + 3) % 3
            Keys.onRightPressed: screenshotOverlay.selectedIndex = (screenshotOverlay.selectedIndex + 1) % 3
            Keys.onLeftPressed: screenshotOverlay.selectedIndex = (screenshotOverlay.selectedIndex - 1 + 3) % 3
            Keys.onTabPressed: screenshotOverlay.selectedIndex = (screenshotOverlay.selectedIndex + 1) % 3
            Keys.onBacktabPressed: screenshotOverlay.selectedIndex = (screenshotOverlay.selectedIndex - 1 + 3) % 3
            Keys.onReturnPressed: {
                if (screenshotOverlay.selectedIndex === 0) {
                    screenshotOverlay.visible = false
                    screenshotRoot.scheduleShot(0, "")
                } else if (screenshotOverlay.selectedIndex === 1) {
                    var fname = "screenshot_" + screenshotRoot.timestamp() + ".png"
                    screenshotOverlay.visible = false
                    screenshotRoot.scheduleShot(1, fname)
                } else if (screenshotOverlay.selectedIndex === 2) {
                    var fname = "screenshot_" + screenshotRoot.timestamp() + ".png"
                    screenshotOverlay.visible = false
                    screenshotRoot.scheduleShot(2, fname)
                }
            }

            // Slide-in animation
            opacity: screenshotOverlay.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Column {
                id: contentCol
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 10 }
                spacing: 4

                // ── Copy to Clipboard ──
                MenuListItem {
                    iconText: "󰆏"
                    labelText: "Copy"
                    isSelected: screenshotOverlay.selectedIndex === 0
                    itemIndex: 0
                    parentMenu: screenshotOverlay
                    onTapped: {
                        screenshotOverlay.visible = false
                        screenshotRoot.scheduleShot(0, "")
                    }
                }

                // ── Save to File ──
                MenuListItem {
                    iconText: "󰆓"
                    labelText: "Save"
                    isSelected: screenshotOverlay.selectedIndex === 1
                    itemIndex: 1
                    parentMenu: screenshotOverlay
                    onTapped: {
                        var fname = "screenshot_" + screenshotRoot.timestamp() + ".png"
                        screenshotOverlay.visible = false
                        screenshotRoot.scheduleShot(1, fname)
                    }
                }

                // ── Save & Copy ──
                MenuListItem {
                    iconText: "󰒅"
                    labelText: "Save & Copy"
                    isSelected: screenshotOverlay.selectedIndex === 2
                    itemIndex: 2
                    parentMenu: screenshotOverlay
                    onTapped: {
                        var fname = "screenshot_" + screenshotRoot.timestamp() + ".png"
                        screenshotOverlay.visible = false
                        screenshotRoot.scheduleShot(2, fname)
                    }
                }

                Item { height: 6 }  // bottom padding
            }
        }
    }
}
