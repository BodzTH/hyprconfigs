pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

// Cheatsheet — SUPER+H or the bar's keyboard button.
//
// Every keybind worth knowing: Hyprland (live from `hyprctl binds -j`), keys
// inside quickshell's panels, Neovim and Yazi. Data comes from
// scripts/cheatsheet_data.py; see that file for where each source is read.
//
// Styled after AppLauncher: same glass card, search box, row metrics and open
// animation, plus a left rail of categories. The selected row carries the
// accent (stripe + tinted key chips); everything else stays glass.
//
// Enter on a Hyprland row closes the sheet and runs that bind through the
// registry in hypr/modules/keybindings.lua (`cheatsheet.run(mask, key)`).
// Rows that can't be run from here (Neovim, Yazi, panel keys, key series)
// copy their keys instead. Mouse: click selects, double-click activates —
// a single stray click must not run "Close window".
PanelWindow {
    id: sheet
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-shortcuts"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Full screen so clicking outside dismisses the panel
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: "transparent"

    property var categories: []
    property var rows: []
    property bool loaded: false
    property string selectedCat: "Apps"
    property int copiedIndex: -1

    readonly property string query: searchInput.text.toLowerCase().trim()

    // ▓▒░ FILTERING
    // Every query word must appear somewhere in the row (title, keys, group…).
    function matches(row, words) {
        var hay = (row.title + " " + row.subtitle + " " + row.group + " " + row.cat + " "
                   + row.keys.join(" ")).toLowerCase();
        return words.every(w => hay.indexOf(w) !== -1);
    }

    readonly property var hits: {
        if (!query) return [];
        var words = query.split(/\s+/);
        return rows.filter(r => matches(r, words));
    }

    // What the list shows, with section headers interleaved as their own
    // entries (a JS-array model has no roles for ListView.section to use).
    readonly property var displayRows: {
        var source = query ? hits : rows.filter(r => r.cat === selectedCat);
        var out = [];
        var lastHeader = null;
        source.forEach(r => {
            var header = query ? (r.cat + (r.group ? "  ·  " + r.group : "")) : r.group;
            if (header && header !== lastHeader) out.push({ isHeader: true, text: header });
            lastHeader = header;
            out.push(r);
        });
        return out;
    }

    function countFor(cat) {
        return (query ? hits : rows).filter(r => r.cat === cat).length;
    }

    function firstRowIndex() {
        for (var i = 0; i < displayRows.length; i++)
            if (!displayRows[i].isHeader) return i;
        return -1;
    }

    // Move the selection by `step` rows, skipping headers.
    function moveBy(step) {
        var n = displayRows.length;
        if (n === 0) return;
        var i = listView.currentIndex;
        var dir = step > 0 ? 1 : -1;
        var remaining = Math.abs(step);
        while (remaining > 0) {
            var j = i + dir;
            while (j >= 0 && j < n && displayRows[j].isHeader) j += dir;
            if (j < 0 || j >= n) break;
            i = j;
            remaining--;
        }
        listView.currentIndex = i;
    }

    function selectCategory(id) {
        selectedCat = id;
        searchInput.text = "";
        listView.currentIndex = firstRowIndex();
        listView.positionViewAtBeginning();
    }

    function cycleCategory(step) {
        var ids = categories.map(c => c.id);
        var i = ids.indexOf(selectedCat);
        selectCategory(ids[(i + step + ids.length) % ids.length]);
    }

    // ▓▒░ OPEN / CLOSE
    function toggle(scr) {
        if (visible) { visible = false; return; }
        if (scr) screen = scr;
        searchInput.text = "";
        listView.currentIndex = firstRowIndex();
        visible = true;
        // Hyprland binds are re-read on every open; nvim/yazi come from cache.
        fetch.running = true;
    }

    // ▓▒░ ACTIVATE — run the bind, or copy its keys
    function activate(row, index) {
        if (!row || row.isHeader) return;
        if (row.run) {
            visible = false;
            // Give focus back to the window underneath first, so "Close
            // window" closes that window and not nothing.
            runTimer.command = ["hyprctl", "eval",
                                "cheatsheet.run(" + row.run.mask + ", " + JSON.stringify(row.run.key) + ")"];
            runTimer.restart();
        } else {
            var text = row.copy || row.keys.join(" + ");
            // Own scope: wl-copy daemonizes to serve the selection, so a bare
            // execDetached would leave it in quickshell.service (see ClipboardPanel).
            Quickshell.execDetached([
                "systemd-run", "--user", "--scope", "--quiet", "--collect",
                "--slice=app.slice", "--description=cheatsheet copy",
                "wl-copy", "--", text]);
            copiedIndex = index;
            copiedTimer.restart();
        }
    }

    Timer {
        id: runTimer
        property var command: []
        interval: 150
        onTriggered: Quickshell.execDetached(command)
    }

    Timer {
        id: copiedTimer
        interval: 1200
        onTriggered: sheet.copiedIndex = -1
    }

    // ▓▒░ DATA
    Process {
        id: fetch
        command: ["python3", Quickshell.shellDir + "/scripts/cheatsheet_data.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    sheet.categories = data.categories;
                    sheet.rows = data.rows;
                    sheet.loaded = true;
                    if (listView.currentIndex < 0) listView.currentIndex = sheet.firstRowIndex();
                } catch (e) {
                    console.warn("Cheatsheet: bad data from cheatsheet_data.py:", e);
                }
            }
        }
    }

    // Warm the nvim/yazi caches at startup so the first open is instant.
    Component.onCompleted: fetch.running = true

    // Close on outside click
    MouseArea {
        anchors.fill: parent
        onClicked: sheet.visible = false
    }

    // ▓▒░ CENTERED PANEL CARD
    Rectangle {
        id: card
        width: 820
        height: Math.min(600, sheet.height * 0.74)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -40

        color: Theme.glassBg
        radius: 14
        antialiasing: true
        border.color: Theme.glassBorder
        border.width: 1

        // Slide-down open animation (same as the launcher)
        opacity: sheet.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        transform: Translate {
            y: sheet.visible ? 0 : -16
            Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }

        // Block background click propagation
        MouseArea { anchors.fill: parent; onClicked: searchInput.forceActiveFocus() }

        // ── Category rail ──
        Rectangle {
            id: rail
            anchors { top: parent.top; bottom: parent.bottom; left: parent.left; margins: 10 }
            width: 196
            radius: 10
            antialiasing: true
            color: Qt.rgba(0, 0, 0, 0.14)

            Column {
                anchors { fill: parent; margins: 6 }
                spacing: 2

                Text {
                    text: "Keybinds"
                    color: Theme.subtext0
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    leftPadding: 10
                    topPadding: 6
                    bottomPadding: 6
                    renderType: Text.NativeRendering
                }

                Repeater {
                    model: sheet.categories

                    delegate: Rectangle {
                        id: railItem
                        required property var modelData
                        readonly property bool isSelected: !sheet.query && sheet.selectedCat === modelData.id
                        readonly property int count: sheet.countFor(modelData.id)
                        readonly property bool dimmed: sheet.query.length > 0 && count === 0

                        width: parent.width
                        height: 36
                        radius: 8
                        antialiasing: true
                        opacity: dimmed ? 0.35 : 1
                        color: isSelected ? Theme.bgSelection : railHover.hovered ? Theme.hoverBg : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }
                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        // Accent stripe on the selected category
                        Rectangle {
                            width: 3
                            height: parent.height - 14
                            radius: 1.5
                            anchors.left: parent.left
                            anchors.leftMargin: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.accent
                            visible: railItem.isSelected
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
                            spacing: 10

                            Text {
                                text: railItem.modelData.icon
                                color: railItem.isSelected ? Theme.accent : Theme.text
                                font.family: Theme.fontMain
                                font.pixelSize: 15
                                Layout.preferredWidth: 18
                                horizontalAlignment: Text.AlignHCenter
                            }
                            Text {
                                text: railItem.modelData.id
                                color: Theme.text
                                font.family: Theme.fontMain
                                font.pixelSize: 13
                                font.weight: railItem.isSelected ? Font.Bold : Font.Medium
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                            }
                            Text {
                                text: railItem.count
                                color: sheet.query && railItem.count > 0 ? Theme.accent : Theme.subtext0
                                font.family: Theme.fontMain
                                font.pixelSize: 11
                                renderType: Text.NativeRendering
                            }
                        }

                        HoverHandler { id: railHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: sheet.selectCategory(railItem.modelData.id) }
                    }
                }
            }
        }

        // ── Right pane ──
        Item {
            anchors { top: parent.top; bottom: parent.bottom; left: rail.right; right: parent.right }

            // Search box (same as the launcher's)
            Rectangle {
                id: headerBox
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12; leftMargin: 10 }
                height: 46
                radius: 8
                antialiasing: true
                color: Theme.glassBg

                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    spacing: 10

                    Text {
                        text: "󰍉"
                        color: Theme.subtext0
                        font.family: Theme.fontMain
                        font.pixelSize: 15
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        color: Theme.text
                        font.family: Theme.fontMain
                        font.pixelSize: 14
                        focus: sheet.visible
                        selectByMouse: true

                        Text {
                            anchors.fill: parent
                            text: "Search every keybind..."
                            color: Theme.subtext0
                            font.family: Theme.fontMain
                            font.pixelSize: 14
                            visible: parent.text.length === 0
                            verticalAlignment: Text.AlignVCenter
                        }

                        onTextChanged: listView.currentIndex = sheet.firstRowIndex()

                        Keys.onPressed: (event) => {
                            switch (event.key) {
                            case Qt.Key_Down:     sheet.moveBy(1); break;
                            case Qt.Key_Up:       sheet.moveBy(-1); break;
                            case Qt.Key_PageDown: sheet.moveBy(8); break;
                            case Qt.Key_PageUp:   sheet.moveBy(-8); break;
                            case Qt.Key_Tab:      sheet.cycleCategory(1); break;
                            case Qt.Key_Backtab:  sheet.cycleCategory(-1); break;
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                sheet.activate(sheet.displayRows[listView.currentIndex], listView.currentIndex);
                                break;
                            case Qt.Key_Escape:
                                if (searchInput.text.length > 0) searchInput.text = "";
                                else sheet.visible = false;
                                break;
                            default:
                                return;
                            }
                            event.accepted = true;
                        }
                    }

                    Text {
                        text: sheet.hits.length + (sheet.hits.length === 1 ? " bind" : " binds")
                        color: Theme.subtext0
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                        visible: searchInput.text.length > 0
                    }
                }
            }

            // ── Bind list ──
            ListView {
                id: listView
                anchors {
                    top: headerBox.bottom
                    left: parent.left
                    right: parent.right
                    bottom: footer.top
                    margins: 10
                    topMargin: 6
                    leftMargin: 4
                }
                model: sheet.displayRows
                currentIndex: -1
                clip: true
                highlightMoveDuration: 80
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    visible: listView.contentHeight > listView.height
                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        antialiasing: true
                        // Wallpaper accent, like the launcher; brighter while dragged.
                        color: parent.pressed ? Qt.lighter(Theme.accent, 1.3) : Theme.accent
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    background: Item {}
                }

                delegate: Item {
                    id: entry
                    required property var modelData
                    required property int index
                    readonly property bool isHeader: modelData.isHeader === true
                    readonly property bool isSelected: !isHeader && listView.currentIndex === index

                    width: listView.width - 12
                    height: isHeader ? 30 : 48

                    // Section header
                    Text {
                        visible: entry.isHeader
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                        text: entry.isHeader ? entry.modelData.text.toUpperCase() : ""
                        color: Theme.subtext0
                        font.family: Theme.fontMain
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 1
                        renderType: Text.NativeRendering
                    }

                    // Bind row
                    Rectangle {
                        visible: !entry.isHeader
                        anchors.fill: parent
                        radius: 10
                        antialiasing: true
                        color: entry.isSelected ? Theme.bgSelection
                             : rowHover.hovered ? Theme.hoverBg : "transparent"
                        border.color: entry.isSelected ? Theme.glassBorder : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 80 } }

                        // Accent stripe on the selected row
                        Rectangle {
                            width: 3
                            height: parent.height - 18
                            radius: 1.5
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.accent
                            visible: entry.isSelected
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 16; rightMargin: 12 }
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: entry.isHeader ? "" : entry.modelData.title
                                    color: Theme.text
                                    font.family: Theme.fontMain
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    renderType: Text.NativeRendering
                                }
                                Text {
                                    text: entry.isHeader ? "" : entry.modelData.subtitle
                                    color: Theme.subtext0
                                    font.family: Theme.fontMain
                                    font.pixelSize: 11
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    visible: text.length > 0
                                    renderType: Text.NativeRendering
                                }
                            }

                            // What Enter will do — only on the selected row
                            Text {
                                visible: entry.isSelected
                                text: sheet.copiedIndex === entry.index ? "Copied"
                                    : (entry.modelData.run ? "⏎ run" : "⏎ copy")
                                color: sheet.copiedIndex === entry.index ? Theme.accent : Theme.subtext0
                                font.family: Theme.fontMain
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                renderType: Text.NativeRendering
                            }

                            // Key chips
                            Row {
                                spacing: 4
                                Repeater {
                                    model: entry.isHeader ? [] : entry.modelData.keys

                                    delegate: Rectangle {
                                        id: chip
                                        required property var modelData
                                        height: 24
                                        width: chipText.implicitWidth + 16
                                        radius: 6
                                        antialiasing: true
                                        color: entry.isSelected
                                            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                                            : Qt.rgba(1, 1, 1, 0.06)
                                        border.color: entry.isSelected ? Theme.accent : Theme.glassBorder
                                        border.width: 1
                                        Behavior on color { ColorAnimation { duration: 80 } }
                                        Behavior on border.color { ColorAnimation { duration: 80 } }

                                        Text {
                                            id: chipText
                                            anchors.centerIn: parent
                                            text: chip.modelData
                                            color: entry.isSelected ? Qt.lighter(Theme.accent, 1.35) : Theme.text
                                            font.family: Theme.fontMain
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            renderType: Text.NativeRendering
                                        }
                                    }
                                }
                            }
                        }

                        HoverHandler { id: rowHover }
                        TapHandler {
                            onTapped: {
                                listView.currentIndex = entry.index;
                                searchInput.forceActiveFocus();
                            }
                            onDoubleTapped: sheet.activate(entry.modelData, entry.index)
                        }
                    }
                }

                // Empty / loading states
                Text {
                    anchors.centerIn: parent
                    text: !sheet.loaded ? "Loading keybinds..."
                        : "No keybinds match \"" + searchInput.text + "\""
                    color: Theme.subtext0
                    font.family: Theme.fontMain
                    font.pixelSize: 13
                    visible: listView.count === 0
                }
            }

            // ── Footer hints ──
            Row {
                id: footer
                anchors { bottom: parent.bottom; left: parent.left; margins: 12; leftMargin: 14 }
                height: 22
                spacing: 16

                Repeater {
                    model: [["↑↓", "select"], ["Tab", "category"], ["⏎", "run / copy"], ["Esc", "close"]]

                    delegate: Row {
                        id: hint
                        required property var modelData
                        spacing: 6

                        Rectangle {
                            height: 18
                            width: hintKey.implicitWidth + 10
                            radius: 4
                            color: Qt.rgba(1, 1, 1, 0.06)
                            border.color: Theme.glassBorder
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                id: hintKey
                                anchors.centerIn: parent
                                text: hint.modelData[0]
                                color: Theme.text
                                font.family: Theme.fontMain
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: hint.modelData[1]
                            color: Theme.subtext0
                            font.family: Theme.fontMain
                            font.pixelSize: 10
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }
        }
    }
}
