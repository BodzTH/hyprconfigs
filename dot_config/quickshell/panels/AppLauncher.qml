import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."

// AppLauncher — replaces rofi -show drun
// Triggered by: SUPER+A (global shortcut)
// Uses Quickshell's built-in DesktopEntries to read all .desktop files

PanelWindow {
    id: launcherWindow
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Full screen so clicking outside dismisses the panel
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: "transparent"

    // ▓▒░ GLOBAL SHORTCUT — SUPER+A
    GlobalShortcut {
        appid: "quickshell"
        name: "toggle-launcher"
        description: "Toggle application launcher"
        onPressed: {
            if (launcherWindow.visible) {
                launcherWindow.visible = false;
                return;
            }
            var scr = root.getFocusedScreen();
            if (scr) {
                launcherWindow.screen = scr;
            }
            searchInput.text = "";
            launcherWindow.visible = true;
        }
    }

    // ▓▒░ DETACHED LAUNCH LOGIC
    // Strips desktop entry field codes (like %U) and spawns process detached
    // so it doesn't get terminated if Quickshell reloads.
    function launchApp(app) {
        var cmdList = [];
        if (app.command) {
            cmdList = app.command.filter(function(arg) {
                return !arg.match(/^%[fFuUdDnNicu]$/);
            });
        }
        if (cmdList.length === 0) return;
        
        if (app.runInTerminal) {
            cmdList = ["ghostty", "-e"].concat(cmdList);
        }
        Quickshell.execDetached(cmdList);
        launcherWindow.visible = false;
    }

    // Close on outside click
    MouseArea {
        anchors.fill: parent
        onClicked: launcherWindow.visible = false
    }

    // ▓▒░ FILTERED APP LIST
    property var filteredApps: {
        var q = searchInput.text.toLowerCase().trim()
        var all = DesktopEntries.applications.values
        if (!q) return all
        return all.filter(function(app) {
            return app.name.toLowerCase().includes(q)
                || (app.genericName && app.genericName.toLowerCase().includes(q))
                || (app.comment && app.comment.toLowerCase().includes(q))
        })
    }

    // ▓▒░ CENTERED PANEL CARD
    Rectangle {
        id: launcherPanel
        width: 600
        height: Math.min(380, Math.max(160, headerBox.height + 20 + appList.contentHeight + 20))
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -60

        color: Theme.glassBg
        radius: 14
        antialiasing: true
        border.color: Theme.glassBorder
        border.width: 1

        // Slide-down open animation
        opacity: launcherWindow.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        transform: Translate {
            y: launcherWindow.visible ? 0 : -16
            Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }

        // Block background click propagation
        MouseArea { anchors.fill: parent; onClicked: searchInput.forceActiveFocus() }

        // ── Search Box ──
        Rectangle {
            id: headerBox
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
            height: 46
            radius: 8
            antialiasing: true
            color: Theme.glassBg
            border.width: 0

            RowLayout {
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                spacing: 10

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    color: Theme.text
                    font.family: Theme.fontMain
                    font.pixelSize: 14
                    focus: launcherWindow.visible

                    // Qt doesn't expose placeholder natively in TextInput,
                    // so we layer a Text behind it
                    Text {
                        anchors.fill: parent
                        text: "Search..."
                        color: Theme.subtext0
                        font.family: Theme.fontMain
                        font.pixelSize: 14
                        visible: parent.text.length === 0
                        verticalAlignment: Text.AlignVCenter
                    }

                    Keys.onEscapePressed: launcherWindow.visible = false
                    Keys.onDownPressed:   appList.incrementCurrentIndex()
                    Keys.onUpPressed:     appList.decrementCurrentIndex()
                    Keys.onReturnPressed: {
                        if (launcherWindow.filteredApps.length > 0) {
                            var entry = launcherWindow.filteredApps[appList.currentIndex]
                            if (entry) {
                                launcherWindow.launchApp(entry);
                            }
                        }
                    }
                }

                // Result count badge
                Text {
                    text: launcherWindow.filteredApps.length + " apps"
                    color: Theme.subtext0
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                    visible: searchInput.text.length > 0
                }
            }
        }

        // ── App List ──
        ListView {
            id: appList
            anchors {
                top: headerBox.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: 10
                topMargin: 6
            }

            model: launcherWindow.filteredApps
            currentIndex: 0
            clip: true
            highlightMoveDuration: 80

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                visible: appList.contentHeight > appList.height
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    antialiasing: true
                    color: Theme.text
                }
                background: Item {}
            }

            delegate: Rectangle {
                id: appRow
                width: appList.width - 12
                height: 50
                radius: 10
                antialiasing: true
                required property var modelData
                required property int index

                color: appList.currentIndex === index
                    ? Theme.bgSelection
                    : rowHover.hovered ? Theme.hoverBg : "transparent"
                border.color: appList.currentIndex === index ? Theme.glassBorder : "transparent"
                border.width: 1
                Behavior on color { ColorAnimation { duration: 80 } }
                Behavior on border.color { ColorAnimation { duration: 80 } }

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 12

                    // App icon — uses Qt's built-in XDG icon theme provider
                    Image {
                        width: 28; height: 28
                        source: appRow.modelData.icon
                            ? (appRow.modelData.icon.startsWith("/")
                               ? appRow.modelData.icon
                               : "image://icon/" + appRow.modelData.icon)
                            : ""
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        sourceSize: Qt.size(28, 28)

                        // Fallback glyph when icon fails to load
                        Text {
                            anchors.centerIn: parent
                            text: "󰣆"
                            color: Theme.subtext0
                            font.family: Theme.fontMain
                            font.pixelSize: 20
                            visible: parent.status !== Image.Ready
                        }
                    }

                    // Name + description
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: appRow.modelData.name
                            color: Theme.text
                            font.family: Theme.fontMain
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                        }

                        Text {
                            text: appRow.modelData.comment || appRow.modelData.genericName || ""
                            color: Theme.subtext0
                            font.family: Theme.fontMain
                            font.pixelSize: 11
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            visible: text.length > 0
                            renderType: Text.NativeRendering
                        }
                    }

                    // Terminal indicator
                    Text {
                        text: ""
                        color: Theme.subtext0
                        font.family: Theme.fontMain
                        font.pixelSize: 12
                        visible: appRow.modelData.runInTerminal
                    }
                }

                HoverHandler { id: rowHover }

                TapHandler {
                    onTapped: {
                        launcherWindow.launchApp(appRow.modelData);
                    }
                }
            }

            // Empty state
            Text {
                anchors.centerIn: parent
                text: "No apps found for \"" + searchInput.text + "\""
                color: Theme.subtext0
                font.family: Theme.fontMain
                font.pixelSize: 13
                visible: appList.count === 0
            }
        }
    }
}
