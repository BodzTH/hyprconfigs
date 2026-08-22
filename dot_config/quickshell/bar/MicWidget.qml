import QtQuick
import Quickshell
import Quickshell.Services.Pipewire as Pw
import Quickshell.Io
import ".."

Rectangle {
    id: micWidget

    readonly property var source: Pw.Pipewire.defaultAudioSource ? Pw.Pipewire.defaultAudioSource.audio : null
    readonly property bool isMuted: source ? source.muted : true
    readonly property int volumePct: source ? Math.round(source.volume * 100) : 0

    height: 28
    width: contentRow.implicitWidth + 16
    radius: 6
    antialiasing: true
    
    activeFocusOnTab: true
    HoverHandler { id: micHover }
    property bool isHoveredOrFocused: micHover.hovered || micWidget.activeFocus
    color: isHoveredOrFocused ? Theme.hoverBg : "transparent"
    

    function toggleMute() {
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]);
    }
    Keys.onReturnPressed: toggleMute()
    Keys.onSpacePressed: toggleMute()
    Keys.onUpPressed: Quickshell.execDetached(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SOURCE@", "0.02+"])
    Keys.onDownPressed: Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", "0.02-"])

    Behavior on color { ColorAnimation { duration: 150 } }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: isHoveredOrFocused ? 4 : 0

        Behavior on spacing { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        Text {
            id: micIcon
            anchors.verticalCenter: parent.verticalCenter
            verticalAlignment: Text.AlignVCenter
            color: isMuted ? Theme.error : Theme.accent
            font.family: Theme.fontMain
            font.pixelSize: 14
            renderType: Text.NativeRendering
            text: isMuted ? "󰍭" : "󰍬"
        }

        Text {
            id: micText
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
                if (!source) return "00%"
                if (isMuted) return "MUT"
                return volumePct.toString().padStart(2, '0') + "%"
            }
        }
    }

    Process {
        id: pavuProc
        command: ["pavucontrol", "-t", "4"]
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]);
            } else if (mouse.button === Qt.RightButton) {
                pavuProc.running = true;
            }
        }

        onWheel: (wheel) => {
            if (wheel.angleDelta.y > 0) {
                Quickshell.execDetached(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SOURCE@", "0.02+"]);
            } else {
                Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", "0.02-"]);
            }
        }
    }
}
