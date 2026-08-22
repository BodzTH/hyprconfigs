import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."

// ClipboardPanel — replaces wofi clipboard
// Triggered by: SUPER+V (global shortcut)
// Fetches history using cliphist list

PanelWindow {
    id: clipboardWindow
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-clipboard"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Full screen so clicking outside dismisses the panel
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: "transparent"

    // ▓▒░ GLOBAL SHORTCUT — SUPER+V
    GlobalShortcut {
        appid: "quickshell"
        name: "toggle-clipboard"
        description: "Toggle clipboard history"
        onPressed: {
            if (clipboardWindow.visible) {
                clipboardWindow.visible = false;
                return;
            }
            var scr = root.getFocusedScreen();
            if (scr) {
                clipboardWindow.screen = scr;
            }
            searchInput.text = "";
            clipboardModel = [];
            cliphistProc.running = true;
            clipboardWindow.visible = true;
        }
    }

    // List of clipboard items parsed from cliphist
    property var clipboardModel: []

    // ▓▒░ PROCESSES
    Process {
        id: cliphistProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var items = [];
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line) {
                        var tabIdx = line.indexOf("\t");
                        if (tabIdx !== -1) {
                            var id = line.substring(0, tabIdx);
                            var content = line.substring(tabIdx + 1);
                            items.push({ id: id, content: content, rawLine: lines[i] });
                        } else {
                            items.push({ id: "", content: line, rawLine: lines[i] });
                        }
                    }
                }
                clipboardWindow.clipboardModel = items;
            }
        }
    }

    Process {
        id: wipeProc
        command: ["cliphist", "wipe"]
        onRunningChanged: {
            if (!running) {
                clipboardModel = []
                clipboardWindow.visible = false
            }
        }
    }

    // Close on outside click
    MouseArea {
        anchors.fill: parent
        onClicked: clipboardWindow.visible = false
    }

    // ▓▒░ FILTERED LIST
    property var filteredItems: {
        var q = searchInput.text.toLowerCase().trim()
        if (!q) return clipboardModel
        return clipboardModel.filter(function(item) {
            return item.content.toLowerCase().includes(q)
        })
    }

    // ▓▒░ CENTERED PANEL CARD
    Rectangle {
        id: clipboardPanel
        width: 600
        height: Math.min(500, Math.max(160, headerBox.height + 20 + itemList.contentHeight + 20 + footerBox.height))
        anchors.centerIn: parent

        color: Theme.glassBg
        radius: 14
        antialiasing: true
        border.color: Theme.glassBorder
        border.width: 1

        // Slide-up open animation
        opacity: clipboardWindow.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        transform: Translate {
            y: clipboardWindow.visible ? 0 : 16
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
                    focus: clipboardWindow.visible

                    Text {
                        anchors.fill: parent
                        text: "Search..."
                        color: Theme.subtext0
                        font.family: Theme.fontMain
                        font.pixelSize: 14
                        visible: parent.text.length === 0
                        verticalAlignment: Text.AlignVCenter
                    }

                    Keys.onEscapePressed: clipboardWindow.visible = false
                    Keys.onDownPressed:   itemList.incrementCurrentIndex()
                    Keys.onUpPressed:     itemList.decrementCurrentIndex()
                    Keys.onReturnPressed: {
                        if (clipboardWindow.filteredItems.length > 0) {
                            var entry = clipboardWindow.filteredItems[itemList.currentIndex]
                            if (entry) {
                                Quickshell.execDetached(["bash", "-c", "printf \"%s\\n\" \"$1\" | cliphist decode | wl-copy", "--", entry.rawLine]);
                                clipboardWindow.visible = false
                            }
                        }
                    }
                }
            }
        }

        // ── Clipboard History List ──
        ListView {
            id: itemList
            anchors {
                top: headerBox.bottom
                left: parent.left
                right: parent.right
                bottom: footerBox.top
                margins: 10
                topMargin: 6
                bottomMargin: 6
            }

            model: clipboardWindow.filteredItems
            currentIndex: 0
            clip: true
            highlightMoveDuration: 80

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                visible: itemList.contentHeight > itemList.height
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    antialiasing: true
                    color: Theme.text
                }
                background: Item {}
            }

            delegate: Rectangle {
                id: itemRow
                width: itemList.width - 12
                height: 44
                radius: 10
                antialiasing: true
                required property var modelData
                required property int index

                color: itemList.currentIndex === index
                    ? Theme.bgSelection
                    : rowHover.hovered ? Theme.hoverBg : "transparent"
                border.color: itemList.currentIndex === index ? Theme.glassBorder : "transparent"
                border.width: 1
                Behavior on color { ColorAnimation { duration: 80 } }
                Behavior on border.color { ColorAnimation { duration: 80 } }

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 12

                    Text {
                        text: "󰅍"
                        color: Theme.subtext0
                        font.family: Theme.fontMain
                        font.pixelSize: 15
                    }

                    Text {
                        text: itemRow.modelData.content
                        color: Theme.text
                        font.family: Theme.fontMain
                        font.pixelSize: 13
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }

                HoverHandler { id: rowHover }

                TapHandler {
                    onTapped: {
                        Quickshell.execDetached(["bash", "-c", "printf \"%s\\n\" \"$1\" | cliphist decode | wl-copy", "--", itemRow.modelData.rawLine]);
                        clipboardWindow.visible = false
                    }
                }
            }

            // Empty state
            Text {
                anchors.centerIn: parent
                text: searchInput.text.length > 0 ? "No matches found" : "Clipboard history is empty"
                color: Theme.subtext0
                font.family: Theme.fontMain
                font.pixelSize: 13
                visible: itemList.count === 0
            }
        }

        // ── Footer / Actions ──
        Rectangle {
            id: footerBox
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 10 }
            height: 30
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                Text {
                    text: "Press Enter to copy, Esc to close"
                    color: Theme.subtext0
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                    Layout.fillWidth: true
                }

                // Clear history button
                Rectangle {
                    height: 28
                    width: clearText.implicitWidth + 24
                    radius: 6
                    antialiasing: true
                    color: wipeHover.hovered ? Theme.hoverBg : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        id: clearText
                        anchors.centerIn: parent
                        text: "Clear History"
                        color: wipeHover.hovered ? Theme.error : Theme.subtext0
                        font.family: Theme.fontMain
                        font.pixelSize: 12
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    HoverHandler { id: wipeHover }
                    TapHandler {
                        onTapped: {
                            wipeProc.running = true
                        }
                    }
                }
            }
        }
    }
}
