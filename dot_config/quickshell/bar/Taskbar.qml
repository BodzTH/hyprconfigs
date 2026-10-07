import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services

Row {
    id: taskbar
    spacing: 6

    // Icons come from services/AppIconService.qml, shared with the overview:
    // appId → desktop entry, except terminals, whose icon follows the program
    // running in them (Claude Code, nvim, btop, ...).

    Repeater {
        model: ToplevelManager.toplevels

        // BarItem: the bar's shared hover / focus / press look (accent tint).
        delegate: BarItem {
            id: taskItem
            width: 28
            // Toplevel's property is `activated`. The old code read `active`,
            // which doesn't exist, so the active-window glow and accent
            // underline never showed.
            selected: modelData.activated

            // Terminals only: the Hyprland side of this window, for its PID,
            // and the part of its title that changes when a program starts or
            // exits — the cue to ask what the terminal is running now.
            readonly property bool isTerminal: AppIconService.isTerminal(modelData.appId)
            readonly property var hyprWindow: isTerminal
                ? (Hyprland.toplevels.values.find(t => t.wayland === modelData) || null) : null
            readonly property int pid: hyprWindow && hyprWindow.lastIpcObject
                ? (hyprWindow.lastIpcObject.pid || 0) : 0
            readonly property string titleKey: isTerminal ? AppIconService.titleKey(modelData.title) : ""
            // Browsers: the active tab's title, for page icons (claude.ai).
            readonly property bool isBrowser: AppIconService.isBrowser(modelData.appId)
            onPidChanged: AppIconService.watch(pid)
            onTitleKeyChanged: AppIconService.watch(pid)
            // lastIpcObject (and so the PID) is only filled by a client-list
            // refresh, which a newly opened window hasn't had yet.
            Component.onCompleted: if (isTerminal && pid <= 0) Hyprland.refreshToplevels()

            // Active window pill indicator
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 1
                anchors.horizontalCenter: parent.horizontalCenter
                height: 3
                width: modelData.activated ? 12 : ((hoverHandler.hovered || taskItem.activeFocus) ? 6 : 0)
                radius: 1.5
                antialiasing: true
                color: modelData.activated ? Theme.accent : Theme.subtext0
                opacity: modelData.activated || hoverHandler.hovered || taskItem.activeFocus ? 1.0 : 0.0

                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            HoverHandler { id: hoverHandler }

            Keys.onReturnPressed: modelData.activate()
            Keys.onSpacePressed: modelData.activate()

            IconImage {
                anchors.centerIn: parent
                width: 22
                height: 22
                asynchronous: true
                // Only terminals and browsers read the title (and terminals the
                // PID); every other window's icon binds on appId alone. A
                // browser's source re-evaluates on each tab switch but only
                // changes, and reloads, entering or leaving a claude.ai tab.
                source: AppIconService.iconSource(modelData.appId,
                    taskItem.isBrowser ? modelData.title : taskItem.titleKey, taskItem.pid)

                // Fallback glyph when icon fails to load
                Text {
                    anchors.centerIn: parent
                    text: "󰣆"
                    color: Theme.subtext0
                    font.family: Theme.fontMain
                    font.pixelSize: 16
                    visible: parent.status === Image.Error || !parent.source
                }
            }
            
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton) {
                        modelData.activate();
                    } else if (mouse.button === Qt.MiddleButton) {
                        modelData.close();
                    }
                }
            }
        }
    }
}
