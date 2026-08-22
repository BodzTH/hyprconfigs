import QtQuick
import Quickshell.Services.Mpris
import ".."

Rectangle {
    id: mediaWidget

    height: 28
    width: visible ? Math.min(300, contentRow.implicitWidth + 20) : 0
    radius: 6
    antialiasing: true
    
    activeFocusOnTab: true
    HoverHandler { id: mediaHover }
    color: mediaHover.hovered || mediaWidget.activeFocus ? Theme.hoverBg : "transparent"
    

    function toggleMedia() {
        if (!activePlayer || !activePlayer.canTogglePlaying) return;
        activePlayer.togglePlaying();
    }

    Keys.onReturnPressed: toggleMedia()
    Keys.onSpacePressed: toggleMedia()

    Behavior on color { ColorAnimation { duration: 150 } }

    property MprisPlayer activePlayer: Mpris.players.count > 0 ? Mpris.players.get(0) : null
    readonly property bool isPlaying: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing
    readonly property bool hasMedia: activePlayer && activePlayer.trackTitle !== ""

    function getTrackText() {
        if (!activePlayer) return "";
        if (!activePlayer.trackArtist) return activePlayer.trackTitle;
        return activePlayer.trackTitle + " - " + activePlayer.trackArtist;
    }

    // Only show if there's a player with an active track
    visible: hasMedia

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6
        width: Math.min(mediaWidget.width - 20, implicitWidth)
        clip: true

        Text {
            text: isPlaying ? "󰐊" : "󰏤"
            color: Theme.text
            font.family: Theme.fontMain
            font.pixelSize: 14
            renderType: Text.NativeRendering
        }

        Text {
            id: mediaText
            text: mediaWidget.getTrackText()
            color: Theme.subtext0
            font.family: Theme.fontMain
            font.pixelSize: 11
            font.weight: Font.Bold
            elide: Text.ElideRight
            width: mediaWidget.visible ? Math.min(250, implicitWidth) : 0
            renderType: Text.NativeRendering
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mediaWidget.toggleMedia()
        onWheel: (wheel) => {
            if (!activePlayer) return;
            if (wheel.angleDelta.y > 0) {
                if (activePlayer.canGoNext) activePlayer.next();
            } else {
                if (activePlayer.canGoPrevious) activePlayer.previous();
            }
        }
    }
}
