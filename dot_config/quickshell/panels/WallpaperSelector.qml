import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."

PanelWindow {
    id: wallpaperWindow
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-wallpaper-selector"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: "transparent"
    
    Component.onCompleted: findProc.running = true

    property var wallpapers: []
    property var filteredWallpapers: {
        var q = searchInput.text.toLowerCase().trim()
        if (!q) return wallpapers
        return wallpapers.filter(function(item) {
            return item.name.toLowerCase().includes(q)
        })
    }

    Process {
        id: findProc
        command: ["bash", "-c", "find ~/Pictures/Wallpapers -maxdepth 1 -type f -iregex '.*\\.\\(jpg\\|jpeg\\|png\\|webp\\|gif\\)$'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var items = [];
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line) {
                        var name = line.substring(line.lastIndexOf("/") + 1);
                        items.push({ path: line, name: name });
                    }
                }
                items.sort(function(a,b) { return a.name.localeCompare(b.name); });
                wallpaperWindow.wallpapers = items;
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: wallpaperWindow.visible = false
    }

    Rectangle {
        id: panelCard
        width: 840
        height: Math.min(600, Math.max(160, 12 + headerBox.height + 12 + gridList.contentHeight + 12))
        anchors.centerIn: parent

        color: Theme.glassBg
        radius: 14
        antialiasing: true
        border.color: Theme.glassBorder
        border.width: 1

        opacity: wallpaperWindow.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        transform: Translate {
            y: wallpaperWindow.visible ? 0 : 16
            Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }

        MouseArea { 
            anchors.fill: parent
            onClicked: searchInput.forceActiveFocus() 
        } // Block background click and keep focus

        Rectangle {
            id: headerBox
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
            height: 46
            radius: 8
            color: Theme.glassBg
            border.width: 0

            RowLayout {
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                spacing: 10

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    color: Theme.text
                    font.family: Theme.fontMain
                    font.pixelSize: 14
                    focus: wallpaperWindow.visible

                    Text {
                        anchors.fill: parent
                        text: "Search wallpapers..."
                        color: Theme.subtext0
                        font.family: Theme.fontMain
                        font.pixelSize: 14
                        visible: parent.text.length === 0
                        verticalAlignment: Text.AlignVCenter
                    }

                    Keys.onEscapePressed: wallpaperWindow.visible = false
                    Keys.onDownPressed:   gridList.moveCurrentIndexDown()
                    Keys.onUpPressed:     gridList.moveCurrentIndexUp()
                    Keys.onRightPressed:  gridList.moveCurrentIndexRight()
                    Keys.onLeftPressed:   gridList.moveCurrentIndexLeft()
                    Keys.onReturnPressed: {
                        if (wallpaperWindow.filteredWallpapers.length > 0) {
                            var entry = wallpaperWindow.filteredWallpapers[gridList.currentIndex]
                            if (entry) {
                                Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/awww_transition.sh \"$1\"", "--", entry.path])
                                wallpaperWindow.visible = false
                            }
                        }
                    }
                }
            }
        }

        GridView {
            id: gridList
            anchors {
                top: headerBox.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: 12
                topMargin: 12
            }
            
            cellWidth: Math.floor((width - 8) / 4)
            cellHeight: Math.floor((cellWidth / 16) * 9) + 40
            
            model: wallpaperWindow.filteredWallpapers
            currentIndex: 0
            clip: true
            
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                visible: gridList.contentHeight > gridList.height
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    color: Theme.text
                }
            }

            delegate: Item {
                width: gridList.cellWidth
                height: gridList.cellHeight
                
                required property var modelData
                required property int index

                Rectangle {
                    anchors { fill: parent; margins: 6 }
                    radius: 10
                    color: gridList.currentIndex === index ? Theme.bgSelection : (itemHover.hovered ? Theme.hoverBg : "transparent")
                    border.color: gridList.currentIndex === index ? Theme.glassBorder : "transparent"
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.margins: 6
                            radius: 6
                            color: "transparent"
                            clip: true
                            
                            Image {
                                anchors.fill: parent
                                source: "file://" + modelData.path
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                            }
                        }
                        
                        Text {
                            text: modelData.name
                            color: Theme.text
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            Layout.fillWidth: true
                            Layout.margins: 6
                            Layout.topMargin: 0
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    HoverHandler { id: itemHover }
                    TapHandler {
                        onTapped: {
                            gridList.currentIndex = index
                            Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/awww_transition.sh \"$1\"", "--", modelData.path])
                            wallpaperWindow.visible = false
                        }
                    }
                }
            }
            
            Text {
                anchors.centerIn: parent
                text: searchInput.text.length > 0 ? "No wallpapers match your search" : "No wallpapers found"
                color: Theme.subtext0
                font.family: Theme.fontMain
                font.pixelSize: 13
                visible: gridList.count === 0
            }
        }
        

    }

    function toggle(scr) {
        if (wallpaperWindow.visible) {
            wallpaperWindow.visible = false;
            return;
        }
        if (scr) {
            wallpaperWindow.screen = scr;
        }
        searchInput.text = "";
        wallpaperWindow.visible = true;
    }
}
