pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import qs

Row {
    id: workspaces
    // No Row spacing: each slot carries its own 6px gap inside its animated
    // width, so a slot sliding in or out never makes the spacing jump.
    spacing: 0

    // Workspaces are matched by *name*, not id. On Hyprland 0.56.2 + quickshell
    // 0.3.1, workspaces that existed before quickshell (re)started are
    // registered with id -1 (probed 2026-09-23); the name is always right.
    // Hyprland.workspaces is an ObjectModel — it has `.values`, not
    // `.count`/`.get()`, which is why the old occupied-highlight never lit up.
    readonly property var occupied: {
        var names = {};
        Hyprland.toplevels.values.forEach(t => {
            if (t.workspace) names[t.workspace.name] = true;
        });
        return names;
    }
    readonly property string focusedName: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.name : ""

    // Persistent 1-5, plus 6-10 while occupied or focused — SUPER+1..0 binds
    // ten, and a workspace the bar can't show is one you can get lost on.
    function isShown(id) {
        return id <= 5 || occupied[String(id)] === true || focusedName === String(id);
    }

    // A fresh quickshell only learns about windows from open/close events, so
    // windows that already existed at (re)start never marked their workspace
    // occupied. Pull the current client list once up front.
    Component.onCompleted: Hyprland.refreshToplevels()

    function goTo(target) {
        Hyprland.dispatch("hl.dsp.focus({ workspace = " + target + " })");
    }

    // Ten fixed slots rather than a model that changes length: a changing JS
    // array model makes the Repeater rebuild every pill, so workspace 6+ used
    // to pop in at full size. Each slot now animates `reveal` 0 ↔ 1 and its
    // width, opacity and scale follow — the bar's left module widens with it.
    Repeater {
        model: 10

        delegate: Item {
            id: slot

            required property int index
            readonly property int wsId: index + 1
            readonly property int gap: index > 0 ? 6 : 0

            property real reveal: workspaces.isShown(wsId) ? 1 : 0
            Behavior on reveal { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

            width: (gap + wsRect.width) * reveal
            height: 28
            opacity: reveal
            visible: reveal > 0   // hidden slots also drop out of Tab focus
            clip: true

            Rectangle {
                id: wsRect

                readonly property int wsId: slot.wsId
                readonly property bool isFocused: workspaces.focusedName === String(wsId)
                readonly property bool isOccupied: workspaces.occupied[String(wsId)] === true

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: isFocused ? 36 : 28
                height: 28
                radius: 6
                antialiasing: true
                scale: 0.6 + 0.4 * slot.reveal

                activeFocusOnTab: true

                HoverHandler { id: wsHover }
                // Highlight when focused, hovered, or occupied
                color: {
                    if (isFocused) return Theme.bgSelection;
                    // Hover / keyboard focus: the bar's quiet glass lift (see BarItem)
                if (wsHover.hovered || wsRect.activeFocus) return Qt.rgba(1, 1, 1, 0.08);
                    if (isOccupied) return Theme.activeGlow;
                    return "transparent";
                }
                border.color: isFocused || wsRect.activeFocus ? Theme.accent
                        : wsHover.hovered ? Qt.rgba(1, 1, 1, 0.10)
                        : isOccupied ? Theme.borderMuted : "transparent"
                border.width: 1

                Keys.onReturnPressed: workspaces.goTo(wsId)
                Keys.onSpacePressed: workspaces.goTo(wsId)

                // Smooth, no overshoot — the old OutBack spring stretched the pill
            // past its size and snapped back, which read as bouncy.
            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: wsRect.wsId.toString()
                    color: (wsRect.isFocused || wsHover.hovered || wsRect.isOccupied) ? Theme.text : Theme.subtext0

                    font.family: Theme.fontMain
                    font.pixelSize: 12
                    font.weight: wsRect.isFocused ? Font.ExtraBold : Font.Bold
                    renderType: Text.NativeRendering
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: workspaces.goTo(wsRect.wsId)
                    // Same direction as SUPER+scroll in keybindings.lua. This used
                    // to exec `hyprctl dispatch workspace e-1` — hyprlang syntax,
                    // which the Lua config rejects ("')' expected near 'e'").
                    onWheel: (wheel) => {
                        if (wheel.angleDelta.y > 0) workspaces.goTo('"e-1"');
                        else if (wheel.angleDelta.y < 0) workspaces.goTo('"e+1"');
                    }
                }
            }
        }
    }
}
