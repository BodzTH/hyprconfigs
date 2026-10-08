pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs
import qs.services

// Window overview — SUPER+grave. Every workspace as a scaled tile (backed by
// the current wallpaper) with live thumbnails of its windows. Click a window
// to focus it, click empty tile space to switch workspace, drag a window onto
// another tile to move it there, middle-click a window to close it. Keys:
// arrows/Tab select, Enter focuses, 1-0 jump to a workspace, Shift+1-0 move
// the selected window there, Esc closes. Moving and closing keep the overview
// open and re-read the layout, so several windows can be sorted in one go.
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
    property var wallpapers: ({})   // monitor name -> image path, from `awww query`
    property bool opening: false    // the running fetch should show the panel
    property string pendingSelect: ""  // address to select after the next fetch
    property var closing: []        // windows being closed: their thumbnails don't capture
    property var closeQueue: []     // ...of which these still wait for the close request

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
        opening = true;
        fetch.running = true;   // shows the panel once the data is in
    }

    readonly property string wallpaper: {
        var focusedMon = monitors.find(m => m.focused) || monitors[0];
        return (focusedMon && wallpapers[focusedMon.name]) || Object.values(wallpapers)[0] || "";
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

    // Run a dispatcher, then re-read the layout once Hyprland has applied it.
    function act(lua, settle) {
        action.command = ["hyprctl", "dispatch", lua];
        refetch.interval = settle;
        action.running = true;
    }

    function moveWindow(c, wsId) {
        if (!c || wsId < 1 || c.workspace.id === wsId) return;
        pendingSelect = c.address;   // keep the moved window selected
        act('hl.dsp.window.move({ window = "address:' + c.address + '", workspace = ' + wsId + ', follow = false })', 60);
    }

    // Graceful close: an app may still ask about unsaved work, and unmaps a
    // moment later, hence the longer settle.
    //
    // The thumbnail stops capturing first, and stays off until the window is
    // gone. A window that closes while its live capture has a frame in
    // flight can make Hyprland drop quickshell with "invalid object" — the
    // whole shell, bar included, goes down (1-3 in 5 middle-click closes in a
    // nested test, 2026-10-09; 0.56.2 + quickshell 0.3.2). With the capture
    // released 150ms before the close there is no frame left to race (0 in
    // 15). Closes queue up, so quick middle-clicks on several windows all land.
    function closeWindow(c) {
        if (!c || closing.indexOf(c.address) >= 0) return;
        closing = closing.concat([c.address]);
        closeQueue = closeQueue.concat([c.address]);
        closeAfterRelease.restart();
    }

    Timer {
        id: closeAfterRelease
        interval: 150
        onTriggered: {
            overview.closeQueue.forEach(a => Hyprland.dispatch('hl.dsp.window.close({ window = "address:' + a + '" })'));
            overview.closeQueue = [];
            refetch.interval = 350;
            refetch.restart();
        }
    }

    function toplevelFor(c) {
        var addr = c.address.replace(/^0x/, "");
        return Hyprland.toplevels.values.find(t => t.address === addr) || null;
    }

    // Same icons as the taskbar (services/AppIconService.qml): a terminal
    // shows the program running in it.
    function iconFor(c) {
        const cls = c.class || "";
        // A browser's favicon is looked up by its whole tab title, as the
        // taskbar does; titleKey would strip a leading "(1) " counter.
        const title = AppIconService.isBrowser(cls) ? c.title : AppIconService.titleKey(c.title);
        return AppIconService.iconSource(cls, title, c.pid || 0);
    }

    Process {
        id: fetch
        command: ["sh", "-c", "hyprctl -j monitors; printf '\\n\\036\\n'; hyprctl -j clients; printf '\\n\\036\\n'; awww query 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.split("\x1e");
                try {
                    overview.monitors = JSON.parse(parts[0]);
                    overview.clients = JSON.parse(parts[1])
                        .filter(c => c.mapped && !c.hidden && c.workspace && c.workspace.id > 0);
                    overview.clients.forEach(c => {
                        if (AppIconService.isTerminal(c.class)) AppIconService.watch(c.pid);
                    });
                } catch (e) {
                    console.warn("Overview: could not parse hyprctl output:", e);
                    overview.opening = false;
                    return;
                }
                // ": DP-3: 1920x1080, scale: 1, currently displaying: image: /path"
                var walls = {};
                (parts[2] || "").split("\n").forEach(line => {
                    var m = line.match(/([^\s:]+): \d+x\d+.*currently displaying: image: (.+)$/);
                    if (m) walls[m[1]] = m[2];
                });
                overview.wallpapers = walls;

                var focusedMon = overview.monitors.find(m => m.focused) || overview.monitors[0];
                overview.activeWs = focusedMon ? focusedMon.activeWorkspace.id : 1;
                var wins = overview.orderedWindows;
                var keep = overview.pendingSelect
                    ? wins.findIndex(c => c.address === overview.pendingSelect) : -1;
                overview.pendingSelect = "";
                // Forget windows that are gone. One still here is slow to
                // close or asking about unsaved work: look again shortly. A
                // fresh open starts over, so a window whose close was refused
                // (kitty's "running program" prompt) gets its live view back.
                if (overview.opening) overview.closing = overview.closeQueue.slice();
                overview.closing = overview.closing.filter(a =>
                    overview.closeQueue.indexOf(a) >= 0 || overview.clients.some(c => c.address === a));
                if (overview.closing.length > overview.closeQueue.length) {
                    refetch.interval = 500;
                    refetch.restart();
                }
                if (keep >= 0) {
                    overview.selected = keep;
                } else if (overview.opening || overview.selected >= wins.length) {
                    // Start on the focused window, so Enter alone is a no-op.
                    var active = wins.findIndex(c => c.focusHistoryID === 0);
                    overview.selected = active >= 0 ? active : (wins.length ? 0 : -1);
                }
                if (overview.opening) {
                    overview.opening = false;
                    overview.visible = true;
                }
            }
        }
    }

    Process {
        id: action
        onExited: refetch.restart()
    }

    Timer {
        id: refetch
        onTriggered: if (overview.visible) fetch.running = true
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

            // While a window is dragged: the client, the tile under the cursor,
            // and where in the (scaled) ghost the cursor holds it.
            property var dragClient: null
            property var dragToplevel: null
            property int dropWs: -1
            property point grab

            function beginDrag(win, at) {
                var scale = Math.min(1, stage.tileW * 0.45 / win.width);
                ghost.width = win.width * scale;
                ghost.height = win.height * scale;
                grab = Qt.point(at.x * scale, at.y * scale);
                moveGhost(win.mapToItem(stage, at.x, at.y));
                dragToplevel = win.toplevel;
                dragClient = win.modelData;   // activates the ghost's Drag
                // By address: delegate modelData is a copy, so === can miss.
                var addr = win.modelData.address;
                overview.selected = overview.orderedWindows.findIndex(c => c.address === addr);
            }

            function moveGhost(p) {
                ghost.x = p.x - grab.x;
                ghost.y = p.y - grab.y;
            }

            function endDrag() {
                var c = dragClient, ws = dropWs;
                dragClient = null;
                dragToplevel = null;
                dropWs = -1;
                overview.moveWindow(c, ws);
            }

            // The digit row by key position (xkb keycodes 10-19 = 1..0), so
            // Shift+2 still reads as 2 although it arrives as '@'.
            function digitOf(event) {
                var sc = event.nativeScanCode;
                if (sc >= 10 && sc <= 19) return sc - 9;
                if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9)
                    return event.key === Qt.Key_0 ? 10 : event.key - Qt.Key_0;
                return 0;
            }

            Keys.onPressed: (event) => {
                var n = overview.orderedWindows.length;
                var digit = digitOf(event);
                if (event.key === Qt.Key_Escape) {
                    overview.visible = false;
                } else if (n > 0 && (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Tab)) {
                    overview.selected = (overview.selected + 1) % n;
                } else if (n > 0 && (event.key === Qt.Key_Left || event.key === Qt.Key_Up || event.key === Qt.Key_Backtab)) {
                    overview.selected = (overview.selected - 1 + n) % n;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (overview.selected >= 0) overview.focusWindow(overview.orderedWindows[overview.selected]);
                } else if (digit && (event.modifiers & Qt.ShiftModifier)) {
                    if (overview.selected >= 0) overview.moveWindow(overview.orderedWindows[overview.selected], digit);
                } else if (digit) {
                    overview.focusWorkspace(digit);
                } else {
                    return;
                }
                event.accepted = true;
            }

            Column {
                anchors.centerIn: parent
                spacing: 18

                Grid {
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

                            Item {
                                id: tile
                                width: stage.tileW
                                height: stage.tileH
                                // Hover is an accent frame, not a lighter fill (hyprlock
                                // power-button style) — the same frame the active tile has.
                                // During a drag only the drop target is framed.
                                readonly property bool isDropTarget: stage.dragClient !== null && stage.dropWs === wsColumn.wsId
                                readonly property bool lit: stage.dragClient !== null
                                    ? isDropTarget
                                    : wsColumn.wsId === overview.activeWs || tileHover.hovered

                                // The desktop itself: the wallpaper, dimmed so the
                                // thumbnails and frames stay readable. A static image,
                                // so the rounded clip costs one render, not one a frame.
                                ClippingRectangle {
                                    anchors.fill: parent
                                    radius: 14
                                    color: Theme.glassBg

                                    Image {
                                        anchors.fill: parent
                                        source: overview.wallpaper
                                            ? "file://" + overview.wallpaper.split("/").map(encodeURIComponent).join("/")
                                            : ""
                                        fillMode: Image.PreserveAspectCrop
                                        // tileW is NaN for a frame while the panel maps (0 width)
                                        sourceSize: stage.tileW > 0 ? Qt.size(Math.ceil(stage.tileW), Math.ceil(stage.tileH)) : Qt.size(0, 0)
                                        asynchronous: true
                                        smooth: true
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        color: Qt.rgba(0, 0, 0, tile.isDropTarget ? 0.15 : 0.35)
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }
                                }

                                HoverHandler { id: tileHover }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: overview.focusWorkspace(wsColumn.wsId)
                                }

                                DropArea {
                                    anchors.fill: parent
                                    onEntered: stage.dropWs = wsColumn.wsId
                                    onExited: if (stage.dropWs === wsColumn.wsId) stage.dropWs = -1
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
                                        readonly property bool isDragged: stage.dragClient !== null && stage.dragClient.address === modelData.address
                                        readonly property var toplevel: overview.toplevelFor(modelData)

                                        x: (modelData.at[0] - (mon ? mon.x : 0)) * sx
                                        y: (modelData.at[1] - (mon ? mon.y : 0)) * sy
                                        width: Math.max(24, modelData.size[0] * sx)
                                        height: Math.max(24, modelData.size[1] * sy)
                                        z: modelData.floating ? 2 : 1
                                        radius: 8
                                        antialiasing: true
                                        clip: true
                                        // The original stays as a faint placeholder while its ghost travels.
                                        opacity: isDragged ? 0.3 : 1
                                        color: Theme.bgContainer
                                        border.color: isSelected || winHover.hovered ? Theme.accent : Theme.borderMuted
                                        border.width: isSelected ? 2 : 1

                                        ScreencopyView {
                                            id: thumb
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            captureSource: win.toplevel && overview.closing.indexOf(win.modelData.address) < 0
                                                ? win.toplevel.wayland : null
                                            live: true
                                        }

                                        // Fallback until (or if never) a frame arrives
                                        Image {
                                            anchors.centerIn: parent
                                            width: Math.min(40, parent.width * 0.5) * (AppIconService.isFavicon(source) ? AppIconService.faviconScale : 1)
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
                                            visible: (win.isSelected || winHover.hovered) && !win.isDragged

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
                                        // Click focuses, middle-click closes; past a few
                                        // pixels of travel a left press becomes a drag.
                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                            preventStealing: true
                                            cursorShape: win.isDragged ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                            property point pressAt
                                            property bool dragged: false

                                            onPressed: (m) => {
                                                pressAt = Qt.point(m.x, m.y);
                                                dragged = false;
                                            }
                                            onPositionChanged: (m) => {
                                                if (!(pressedButtons & Qt.LeftButton)) return;
                                                if (!dragged && Math.hypot(m.x - pressAt.x, m.y - pressAt.y) > 8) {
                                                    dragged = true;
                                                    stage.beginDrag(win, pressAt);
                                                }
                                                if (dragged) stage.moveGhost(mapToItem(stage, m.x, m.y));
                                            }
                                            onReleased: if (dragged) stage.endDrag()
                                            onClicked: (m) => {
                                                if (dragged) return;
                                                if (m.button === Qt.MiddleButton) overview.closeWindow(win.modelData);
                                                else overview.focusWindow(win.modelData);
                                            }
                                        }
                                    }
                                }

                                // Frame on top of the wallpaper and the thumbnails.
                                Rectangle {
                                    anchors.fill: parent
                                    z: 10
                                    radius: 14
                                    antialiasing: true
                                    color: "transparent"
                                    border.color: tile.lit ? Theme.accent : Theme.glassBorder
                                    border.width: tile.lit ? 2 : 1
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "click focus  ·  drag to a workspace to move  ·  shift+1–0 move selected  ·  middle-click close  ·  esc"
                    color: Theme.subtext0
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }
            }

            // The window being dragged, following the cursor. Its Drag drives
            // the tiles' DropAreas; the hot spot is where the cursor holds it.
            Rectangle {
                id: ghost
                z: 100
                visible: stage.dragClient !== null
                radius: 8
                antialiasing: true
                clip: true
                opacity: 0.9
                color: Theme.bgContainer
                border.color: Theme.accent
                border.width: 2

                Drag.active: stage.dragClient !== null
                Drag.hotSpot.x: stage.grab.x
                Drag.hotSpot.y: stage.grab.y

                ScreencopyView {
                    id: ghostThumb
                    anchors.fill: parent
                    anchors.margins: 2
                    captureSource: stage.dragToplevel ? stage.dragToplevel.wayland : null
                    live: true
                }
                Image {
                    anchors.centerIn: parent
                    width: Math.min(40, parent.width * 0.5)
                    height: width
                    sourceSize: Qt.size(64, 64)
                    source: stage.dragClient ? overview.iconFor(stage.dragClient) : ""
                    visible: !ghostThumb.hasContent && source.toString() !== ""
                }
            }
        }
    }
}
