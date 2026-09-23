pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs

// Window overview — SUPER+grave. Every workspace as a scaled tile with live
// thumbnails of its windows. Click a window to focus it, click empty tile
// space to switch workspace. Keys: arrows/Tab move, Enter focuses, 1-0 jump
// to a workspace, Esc closes.
//
// Geometry comes from `hyprctl -j`, read fresh on every open, not from
// Quickshell.Hyprland's models: on Hyprland 0.56.2 + quickshell 0.3.1 those
// report workspace id -1 and an empty monitor list after a (re)start, until
// events trickle in (probed 2026-09-23). The Hyprland module is still used for
// the one thing it gets right: mapping an address to a Wayland toplevel handle
// for ScreencopyView.
PanelWindow {
    id: overview
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-overview"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: -1

    property var clients: []
    property var monitors: []
    property int activeWs: 1
    property int selected: -1

    // Always 1-5 (matching the bar), plus any higher workspace with windows.
    readonly property var workspaceIds: {
        var ids = [1, 2, 3, 4, 5];
        clients.forEach(c => {
            var id = c.workspace.id;
            if (id > 0 && ids.indexOf(id) === -1) ids.push(id);
        });
        if (activeWs > 0 && ids.indexOf(activeWs) === -1) ids.push(activeWs);
        return ids.sort((a, b) => a - b);
    }

    // Keyboard order: workspace, then top-to-bottom, left-to-right.
    readonly property var orderedWindows: clients
        .filter(c => c.workspace.id > 0)
        .slice()
        .sort((a, b) => a.workspace.id - b.workspace.id || a.at[1] - b.at[1] || a.at[0] - b.at[0])

    function toggle(scr) {
        if (visible) { visible = false; return; }
        if (scr) screen = scr;
        fetch.running = true;   // shows the panel once the data is in
    }

    function windowsOn(wsId) {
        return clients.filter(c => c.workspace.id === wsId);
    }

    function monitorFor(id) {
        return monitors.find(m => m.id === id) || monitors[0] || null;
    }

    function focusWindow(c) {
        visible = false;
        Hyprland.dispatch('hl.dsp.focus({ window = "address:' + c.address + '" })');
    }

    function focusWorkspace(id) {
        visible = false;
        Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })");
    }

    function toplevelFor(c) {
        var addr = c.address.replace(/^0x/, "");
        return Hyprland.toplevels.values.find(t => t.address === addr) || null;
    }

    function iconFor(c) {
        var entry = DesktopEntries.heuristicLookup(c.class || "");
        if (entry && entry.icon) return entry.icon.startsWith("/") ? entry.icon : "image://icon/" + entry.icon;
        return Quickshell.hasThemeIcon(c.class) ? "image://icon/" + c.class : "";
    }

    Process {
        id: fetch
        command: ["sh", "-c", "hyprctl -j monitors; printf '\\n\\036\\n'; hyprctl -j clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.split("\x1e");
                try {
                    overview.monitors = JSON.parse(parts[0]);
                    overview.clients = JSON.parse(parts[1])
                        .filter(c => c.mapped && !c.hidden && c.workspace && c.workspace.id > 0);
                } catch (e) {
                    console.warn("Overview: could not parse hyprctl output:", e);
                    return;
                }
                var focusedMon = overview.monitors.find(m => m.focused) || overview.monitors[0];
                overview.activeWs = focusedMon ? focusedMon.activeWorkspace.id : 1;
                // Start on the focused window, so Enter alone is a no-op.
                var active = overview.orderedWindows.findIndex(c => c.focusHistoryID === 0);
                overview.selected = active >= 0 ? active : (overview.orderedWindows.length ? 0 : -1);
                overview.visible = true;
            }
        }
    }

    // Dim the desktop; click anywhere outside a tile to close.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)
        MouseArea { anchors.fill: parent; onClicked: overview.visible = false }
    }

    // Loader: thumbnails only exist (and only capture) while the overview is up.
    Loader {
        anchors.fill: parent
        active: overview.visible
        focus: true

        sourceComponent: Item {
            id: stage
            focus: true

            readonly property int count: overview.workspaceIds.length
            // Two rows beat one long strip: 5 workspaces as 3+2 gives tiles
            // ~1.7x wider than 5 across, big enough to read the thumbnails.
            readonly property int cols: count <= 4 ? count : Math.min(5, Math.ceil(count / 2))
            readonly property int rows: Math.ceil(count / cols)
            readonly property real gap: 24
            readonly property real labelH: 22
            readonly property real aspect: overview.height / overview.width
            readonly property real tileW: Math.min(
                (overview.width * 0.92 - (cols - 1) * gap) / cols,
                (overview.height * 0.80 - (rows - 1) * gap - rows * labelH) / rows / aspect)
            readonly property real tileH: tileW * aspect

            Keys.onPressed: (event) => {
                var n = overview.orderedWindows.length;
                if (event.key === Qt.Key_Escape) {
                    overview.visible = false;
                } else if (n > 0 && (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Tab)) {
                    overview.selected = (overview.selected + 1) % n;
                } else if (n > 0 && (event.key === Qt.Key_Left || event.key === Qt.Key_Up || event.key === Qt.Key_Backtab)) {
                    overview.selected = (overview.selected - 1 + n) % n;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (overview.selected >= 0) overview.focusWindow(overview.orderedWindows[overview.selected]);
                } else if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                    overview.focusWorkspace(event.key === Qt.Key_0 ? 10 : event.key - Qt.Key_0);
                } else {
                    return;
                }
                event.accepted = true;
            }

            Grid {
                anchors.centerIn: parent
                columns: stage.cols
                spacing: stage.gap

                Repeater {
                    model: overview.workspaceIds

                    Column {
                        id: wsColumn
                        required property int modelData
                        readonly property int wsId: modelData
                        readonly property var wsWindows: overview.windowsOn(wsId)
                        spacing: 6

                        Text {
                            height: stage.labelH - 6
                            text: wsColumn.wsId + (wsColumn.wsWindows.length ? "  ·  " + wsColumn.wsWindows.length : "")
                            color: wsColumn.wsId === overview.activeWs ? Theme.accent : Theme.text
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            renderType: Text.NativeRendering
                        }

                        Rectangle {
                            id: tile
                            width: stage.tileW
                            height: stage.tileH
                            radius: 14
                            antialiasing: true
                            clip: true
                            color: tileHover.hovered ? Qt.rgba(1, 1, 1, 0.10) : Theme.glassBg
                            border.color: wsColumn.wsId === overview.activeWs ? Theme.accent : Theme.glassBorder
                            border.width: wsColumn.wsId === overview.activeWs ? 2 : 1

                            HoverHandler { id: tileHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: overview.focusWorkspace(wsColumn.wsId)
                            }

                            Repeater {
                                model: wsColumn.wsWindows

                                Rectangle {
                                    id: win
                                    required property var modelData
                                    readonly property var mon: overview.monitorFor(modelData.monitor)
                                    readonly property real monW: mon ? mon.width / mon.scale : overview.width
                                    readonly property real monH: mon ? mon.height / mon.scale : overview.height
                                    readonly property real sx: tile.width / monW
                                    readonly property real sy: tile.height / monH
                                    readonly property bool isSelected: overview.orderedWindows[overview.selected] === modelData
                                    readonly property var toplevel: overview.toplevelFor(modelData)

                                    x: (modelData.at[0] - (mon ? mon.x : 0)) * sx
                                    y: (modelData.at[1] - (mon ? mon.y : 0)) * sy
                                    width: Math.max(24, modelData.size[0] * sx)
                                    height: Math.max(24, modelData.size[1] * sy)
                                    z: modelData.floating ? 2 : 1
                                    radius: 8
                                    antialiasing: true
                                    clip: true
                                    color: Theme.bgContainer
                                    border.color: isSelected || winHover.hovered ? Theme.accent : Theme.borderMuted
                                    border.width: isSelected ? 2 : 1

                                    ScreencopyView {
                                        id: thumb
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        captureSource: win.toplevel ? win.toplevel.wayland : null
                                        live: true
                                    }

                                    // Fallback until (or if never) a frame arrives
                                    Image {
                                        anchors.centerIn: parent
                                        width: Math.min(40, parent.width * 0.5)
                                        height: width
                                        sourceSize: Qt.size(64, 64)
                                        source: overview.iconFor(win.modelData)
                                        visible: !thumb.hasContent && source.toString() !== ""
                                    }

                                    // Title strip on hover / selection
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: 20
                                        color: Qt.rgba(0, 0, 0, 0.6)
                                        visible: win.isSelected || winHover.hovered

                                        Text {
                                            anchors.fill: parent
                                            anchors.leftMargin: 6
                                            anchors.rightMargin: 6
                                            verticalAlignment: Text.AlignVCenter
                                            text: win.modelData.title || win.modelData.class
                                            color: Theme.text
                                            elide: Text.ElideRight
                                            font.family: Theme.fontMain
                                            font.pixelSize: 10
                                            renderType: Text.NativeRendering
                                        }
                                    }

                                    HoverHandler { id: winHover }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: overview.focusWindow(win.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
