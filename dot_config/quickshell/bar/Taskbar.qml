import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import ".."

Row {
    id: taskbar
    spacing: 6

    // App-identity overrides, keyed on the Wayland appId only — never on the
    // window title, which is page/document content an app doesn't control.
    // Everything else is resolved via the real desktop entry.
    //
    // Both entries below exist because hypr/modules/variables.lua launches these
    // with a custom --class, so their appId isn't "kitty" and has no matching
    // desktop entry for heuristicLookup to find:
    //   - modules/variables.lua: fileManager = "kitty --class=org.yazi.fm ..."
    //   - modules/variables.lua: updater = "kitty --class=cachy.update ..."
    //     (windowrules.lua also matches the older "cachy-update" and
    //     "org.cachyos.update" spellings — id.includes("cachy") covers all three)
    // Neither is a real installed package, so there's no desktop-entry icon
    // to look up regardless; these map straight to a real theme icon name.
    property var appIdOverrides: [
        { key: "org.yazi.fm", icon: "yazi" },
        { key: "cachy", icon: "system-software-update" },
    ]

    // Terminal emulators used on this system. Their toplevel appId never
    // reveals what's actually running inside, so for these — and only
    // these — we also consult the title to pick out a well-known TUI
    // program, matched on word boundaries so it can't fire on ordinary text.
    //
    // Caveat: this only works when the terminal's title is actually updated
    // to the running command. kitty does that itself for anything it launches
    // directly (e.g. the "kitty -e btop"/"kitty -e nmtui" spawned by this
    // config), but for a program typed at an interactive prompt it depends on
    // shell integration — bash and zsh's kitty integration set the title on
    // every command, fish's does not. Icon names below are verified against
    // the icon themes actually installed on this system (Adwaita, inheriting
    // AdwaitaLegacy and hicolor); several apps ship no dedicated icon at all,
    // so those fall back to a real generic icon rather than a name that
    // silently fails to resolve.
    property var terminalAppIds: ["kitty", "foot", "alacritty", "org.wezfurlong.wezterm", "com.mitchellh.ghostty"]
    property var terminalPrograms: [
        { key: "nvim", icon: "nvim" },                              // dedicated icon (hicolor)
        { key: "vim", icon: "gvim" },                               // vim.desktop's real Icon= key
        { key: "nano", icon: "accessories-text-editor" },           // no dedicated icon on this system
        { key: "btop", icon: "btop" },                              // dedicated icon (hicolor)
        { key: "htop", icon: "utilities-system-monitor" },          // no dedicated icon on this system
        { key: "yazi", icon: "yazi" },                              // dedicated icon (hicolor)
        { key: "lazygit", icon: "utilities-terminal" },             // no dedicated icon on this system
        { key: "nmtui", icon: "preferences-system-network" },       // AdwaitaLegacy
    ]

    function lookupTerminalProgram(title) {
        const t = title ? title.toLowerCase() : "";
        for (let i = 0; i < terminalPrograms.length; i++) {
            if (new RegExp("\\b" + terminalPrograms[i].key + "\\b").test(t)) {
                return terminalPrograms[i].icon;
            }
        }
        return "";
    }

    function getAppIconName(title, appId) {
        let id = appId ? appId.toLowerCase() : "";
        if (id.endsWith(".desktop")) {
            id = id.substring(0, id.length - 8);
        }
        if (!id) return "application-x-executable";

        if (id.includes("antigravity")) return "";

        for (let i = 0; i < appIdOverrides.length; i++) {
            if (id.includes(appIdOverrides[i].key)) return appIdOverrides[i].icon;
        }

        if (terminalAppIds.some(t => id.includes(t))) {
            const program = lookupTerminalProgram(title);
            if (program) return program;
        }

        const entry = DesktopEntries.heuristicLookup(id);
        if (entry && entry.icon) return entry.icon;

        if (Quickshell.hasThemeIcon(id)) return id;

        return "application-x-executable";
    }

    function getAppIcon(title, appId) {
        const id = appId ? appId.toLowerCase() : "";
        if (id.includes("antigravity")) {
            return "file://" + Quickshell.env("HOME") + "/Apps/Antigravity/Google-Antigravity-Icon-White.png";
        }

        const iconName = getAppIconName(title, appId);
        if (!iconName) return Quickshell.iconPath("application-x-executable");
        if (iconName.startsWith("/") || iconName.startsWith("file://")) {
            return iconName.startsWith("/") ? ("file://" + iconName) : iconName;
        }
        return Quickshell.iconPath(iconName);
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
                asynchronous: true
                // Only reads modelData.title (and so only re-resolves on title
                // change) for terminal windows, where it picks out the running
                // TUI program. Every other window's icon binds on appId alone,
                // so switching browser tabs etc. no longer reloads the icon.
                source: {
                    const id = (modelData.appId || "").toLowerCase();
                    const isTerminal = taskbar.terminalAppIds.some(t => id.includes(t));
                    return taskbar.getAppIcon(isTerminal ? modelData.title : "", modelData.appId);
                }

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
