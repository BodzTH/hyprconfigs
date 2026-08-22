import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import ".."

Row {
    id: taskbar
    spacing: 6

    function getAppIconName(title, appId) {
        const t = title ? title.toLowerCase() : "";
        let id = appId ? appId.toLowerCase() : "";
        
        if (id.endsWith(".desktop")) {
            id = id.substring(0, id.length - 8);
        }
        
        if (id.includes("antigravity")) return "";
        
        const mappings = [
            { key: "ghostty", icon: "com.mitchellh.ghostty" },
            { key: "kitty", icon: "kitty" },
            { key: "foot", icon: "foot" },
            { key: "alacritty", icon: "alacritty" },
            { key: "wezterm", icon: "org.wezfurlong.wezterm" },
            { key: "yazi", icon: "yazi" },
            { key: "neovim", icon: "nvim" },
            { key: "nvim", icon: "nvim" },
            { key: "vim", icon: "vim" },
            { key: "nano", icon: "nano" },
            { key: "btop", icon: "btop" },
            { key: "htop", icon: "htop" },
            { key: "nmtui", icon: "preferences-system-network" },
            { key: "pavucontrol", icon: "multimedia-volume-control" },
            { key: "lazygit", icon: "git" },
            { key: "python", icon: "python" },
            { key: "obs", icon: "com.obsproject.Studio" },
            { key: "dolphin", icon: "system-file-manager" },
            { key: "thunar", icon: "system-file-manager" },
            { key: "nautilus", icon: "system-file-manager" },
            { key: "code", icon: "visual-studio-code" },
            { key: "discord", icon: "discord" },
            { key: "telegram", icon: "telegram" },
            { key: "steam", icon: "steam" },
            { key: "spotify", icon: "spotify" },
        ];

        for (let i = 0; i < mappings.length; i++) {
            if (t.includes(mappings[i].key) || id.includes(mappings[i].key)) {
                return mappings[i].icon;
            }
        }
        
        return id || "application-x-executable";
    }

    function getAppIcon(title, appId) {
        const id = appId ? appId.toLowerCase() : "";
        if (id.includes("antigravity")) {
            return "file:///home/bodz/Apps/Antigravity/Google-Antigravity-Icon-White.png";
        }
        
        const iconName = getAppIconName(title, appId);
        if (!iconName) return Quickshell.iconPath("application-x-executable");
        if (iconName.startsWith("/") || iconName.startsWith("file://")) {
            return iconName.startsWith("/") ? ("file://" + iconName) : iconName;
        }
        return Quickshell.iconPath(iconName, "application-x-executable");
    }

    Repeater {
        model: ToplevelManager.toplevels

        delegate: Rectangle {
            id: taskItem
            width: 28
            height: 28
            radius: 6
            antialiasing: true
            activeFocusOnTab: true
            color: modelData.active ? Theme.activeGlow : ((hoverHandler.hovered || taskItem.activeFocus) ? Theme.hoverBg : "transparent")
            

            Behavior on color { ColorAnimation { duration: 150 } }

            // Active window pill indicator
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 1
                anchors.horizontalCenter: parent.horizontalCenter
                height: 3
                width: modelData.active ? 12 : ((hoverHandler.hovered || taskItem.activeFocus) ? 6 : 0)
                radius: 1.5
                antialiasing: true
                color: modelData.active ? Theme.accent : Theme.subtext0
                opacity: modelData.active || hoverHandler.hovered || taskItem.activeFocus ? 1.0 : 0.0

                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            HoverHandler { id: hoverHandler }

            Keys.onReturnPressed: modelData.activate()
            Keys.onSpacePressed: modelData.activate()

            IconImage {
                anchors.centerIn: parent
                width: 22
                height: 22
                source: taskbar.getAppIcon(modelData.title, modelData.appId)

                // Fallback glyph when icon fails to load
                Text {
                    anchors.centerIn: parent
                    text: "󰣆"
                    color: Theme.subtext0
                    font.family: Theme.fontMain
                    font.pixelSize: 16
                    visible: parent.status === Image.Error || !parent.source
                }
            }
            
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton) {
                        modelData.activate();
                    } else if (mouse.button === Qt.MiddleButton) {
                        modelData.close();
                    }
                }
            }
        }
    }
}
