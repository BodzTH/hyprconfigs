import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import ".."

Rectangle {
    id: layoutWidget

    height: 28
    width: layoutText.implicitWidth + 20
    radius: 6
    antialiasing: true
    
    activeFocusOnTab: true
    HoverHandler { id: layoutHover }
    property bool isHoveredOrFocused: layoutHover.hovered || layoutWidget.activeFocus
    color: isHoveredOrFocused ? Theme.hoverBg : "transparent"
    

    Keys.onReturnPressed: switchLayoutProc.running = true
    Keys.onSpacePressed: switchLayoutProc.running = true

    Behavior on color { ColorAnimation { duration: 150 } }

    property string currentLayout: "EN"

    Text {
        id: layoutText
        anchors.centerIn: parent
        text: layoutWidget.currentLayout
        color: Theme.subtext0
        
        font.family: Theme.fontMain
        font.pixelSize: 11
        font.weight: Font.Bold
        renderType: Text.NativeRendering
    }

    /**
     * Transforms a long keyboard layout name into a short 2-letter uppercase representation.
     * @param {string} name - The full layout name (e.g. "English (US)")
     * @returns {string} The short layout abbreviation (e.g. "EN")
     */
    function transformLayout(name) {
        name = name.trim();
        const mappings = [
            { key: "English", val: "EN" },
            { key: "Arabic", val: "AR" },
            { key: "Russian", val: "RU" },
            { key: "Hebrew", val: "HE" },
            { key: "German", val: "DE" },
            { key: "French", val: "FR" },
            { key: "Spanish", val: "ES" },
            { key: "Portuguese", val: "PT" },
            { key: "Turkish", val: "TR" },
            { key: "Chinese", val: "ZH" },
            { key: "Japanese", val: "JA" },
            { key: "Korean", val: "KO" }
        ];
        
        for (let i = 0; i < mappings.length; i++) {
            if (name.includes(mappings[i].key)) return mappings[i].val;
        }
        
        return name.substring(0, 2).toUpperCase();
    }

    // Process to get initial layout
    Process {
        id: getLayoutProc
        command: ["sh", "-c", "hyprctl devices -j | grep 'active_keymap' | head -n1 | cut -d'\"' -f4"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                layoutWidget.currentLayout = layoutWidget.transformLayout(this.text.trim());
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                var parts = event.data.split(",");
                if (parts.length > 1) {
                    layoutWidget.currentLayout = layoutWidget.transformLayout(parts[parts.length - 1]);
                }
            }
        }
    }

    Process {
        id: switchLayoutProc
        command: ["sh", "-c", "hyprctl switchxkblayout \"$(~/.config/scripts/mainkey.sh)\" next"]
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            switchLayoutProc.running = true;
        }
    }
}
