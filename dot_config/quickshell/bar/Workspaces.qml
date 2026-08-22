import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import ".."

Row {
    spacing: 6

    // Persistent Workspaces 1-5
    Repeater {
        model: 5

        delegate: Rectangle {
            id: wsRect
            
            property int wsId: index + 1
            property var wsObject: {
                for (var i = 0; i < Hyprland.workspaces.count; i++) {
                    var w = Hyprland.workspaces.get(i);
                    if (w && w.id === wsId) return w;
                }
                return null;
            }
            
            property bool isFocused: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsId
            property bool isOccupied: wsObject !== null

            width: isFocused ? 36 : 28
            height: 28
            radius: 6
            antialiasing: true
            
            activeFocusOnTab: true

            HoverHandler { id: wsHover }
            // Highlight when focused, hovered, or occupied
            color: {
                if (isFocused) return Theme.bgSelection;
                if (wsHover.hovered || wsRect.activeFocus) return Theme.hoverBg;
                if (isOccupied) return Theme.activeGlow;
                return "transparent";
            }
            border.color: isFocused ? Theme.glassBorder : ((isOccupied || wsRect.activeFocus) ? Theme.borderMuted : "transparent")
            border.width: 1
            

            Keys.onReturnPressed: {
                Hyprland.dispatch("hl.dsp.focus({ workspace = " + wsId + " })");
            }
            Keys.onSpacePressed: {
                Hyprland.dispatch("hl.dsp.focus({ workspace = " + wsId + " })");
            }

            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: wsId.toString()
                color: (isFocused || wsHover.hovered || isOccupied) ? Theme.text : Theme.subtext0
                
                font.family: Theme.fontMain
                font.pixelSize: 12
                font.weight: isFocused ? Font.ExtraBold : Font.Bold
                renderType: Text.NativeRendering
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Hyprland.dispatch("hl.dsp.focus({ workspace = " + wsId + " })");
                }
                onWheel: (wheel) => {
                    if (wheel.angleDelta.y > 0) {
                        Hyprland.dispatch('hl.dsp.exec_cmd("hyprctl dispatch workspace e-1")');
                    } else if (wheel.angleDelta.y < 0) {
                        Hyprland.dispatch('hl.dsp.exec_cmd("hyprctl dispatch workspace e+1")');
                    }
                }
            }
        }
    }
}
