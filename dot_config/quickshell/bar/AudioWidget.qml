import QtQuick
import Quickshell
import Quickshell.Services.Pipewire as Pw
import Quickshell.Io
import ".."

Rectangle {
    id: audioWidget

    readonly property var sink: Pw.Pipewire.defaultAudioSink ? Pw.Pipewire.defaultAudioSink.audio : null
    readonly property bool isMuted: sink ? sink.muted : true
    readonly property int volumePct: sink ? Math.round(sink.volume * 100) : 0

    height: 28
    width: contentRow.implicitWidth + 16
    radius: 6
    antialiasing: true
    
    activeFocusOnTab: true
    HoverHandler { id: audioHover }
    property bool isHoveredOrFocused: audioHover.hovered || audioWidget.activeFocus
    color: isHoveredOrFocused ? Theme.hoverBg : "transparent"
    

    function toggleMute() {
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
    }
    Keys.onReturnPressed: toggleMute()
    Keys.onSpacePressed: toggleMute()
    Keys.onUpPressed: Quickshell.execDetached(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "0.02+"])
    Keys.onDownPressed: Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "0.02-"])

    Behavior on color { ColorAnimation { duration: 150 } }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: isHoveredOrFocused ? 4 : 0

        Behavior on spacing { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        Text {
            id: volumeIcon
            anchors.verticalCenter: parent.verticalCenter
            verticalAlignment: Text.AlignVCenter
            color: isMuted ? Theme.error : Theme.accent
            font.family: Theme.fontMain
            font.pixelSize: 14
            renderType: Text.NativeRendering
            text: {
                if (!sink) return "󰖁"
                if (isMuted) return "󰖁"
                return volumePct >= 50 ? "󰕾" : "󰖀"
            }
        }

        Text {
            id: volumeText
            anchors.verticalCenter: parent.verticalCenter
            verticalAlignment: Text.AlignVCenter
            color: isMuted ? Theme.error : Theme.text
            font.family: Theme.fontMain
            font.pixelSize: 10
            font.weight: Font.Bold
            renderType: Text.NativeRendering
            
            clip: true
            width: isHoveredOrFocused ? implicitWidth : 0
            opacity: isHoveredOrFocused ? 1.0 : 0.0

            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200 } }

            text: {
                if (!sink) return "00%"
                if (isMuted) return "MUT"
                return volumePct.toString().padStart(2, '0') + "%"
            }
        }
    }

    Process {
        id: pavuProc
        command: ["pavucontrol"]
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
            } else if (mouse.button === Qt.RightButton) {
                pavuProc.running = true;
            }
        }

        onWheel: (wheel) => {
            if (wheel.angleDelta.y > 0) {
                Quickshell.execDetached(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "0.02+"]);
            } else {
                Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "0.02-"]);
            }
        }
    }
}
