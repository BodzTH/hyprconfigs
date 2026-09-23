import QtQuick
import qs

// CheatsheetButton — bar button for the keybind cheatsheet (SUPER+H).
BarItem {
    id: cheatBtn

    width: 28
    HoverHandler { id: btnHover; cursorShape: Qt.PointingHandCursor }

    Keys.onReturnPressed: root.toggleCheatsheet()
    Keys.onSpacePressed: root.toggleCheatsheet()


    Text {
        anchors.centerIn: parent
        text: "󰌌"
        color: Theme.text
        font.family: Theme.fontMain
        font.pixelSize: 14
    }

    TapHandler { onTapped: root.toggleCheatsheet() }
}
