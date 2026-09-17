import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications as Notifs
import ".."
import "../services"

// This component lives directly in ShellRoot (not inside Variants).
// It listens for the onNotification signal and manages a list of
// visible popup items rendered inside a single overlay PanelWindow.

Item {
    id: osdRoot

    required property var notificationServer

    // Internal list of currently-visible popup notifications
    property var popups: []
    property int nextNotifId: 0

    // Matches `key` as a whole word inside `str` — unlike includes(), "sh"
    // can't match inside "finished" and "tor" can't match inside "editor".
    function hasWord(str, key) {
        return new RegExp("\\b" + key + "\\b").test(str);
    }

    function getIconSource(iconStr, appName) {
        if (iconStr) {
            if (iconStr.startsWith("/") || iconStr.startsWith("file://")) {
                return iconStr;
            }
            if (Quickshell.hasThemeIcon(iconStr)) {
                return "image://icon/" + iconStr;
            }
        }
        // Fall back to the sender's real desktop entry (recovers a correct
        // icon for e.g. notify-send, which reports no usable icon name).
        var entry = DesktopEntries.heuristicLookup(appName || "");
        if (entry && entry.icon) {
            return entry.icon.startsWith("/") ? entry.icon : "image://icon/" + entry.icon;
        }
        return "";
    }

    function getAppDisplayName(name) {
        if (!name) return "Notification";
        var lower = name.toLowerCase();
        if (lower === "notify-send") return "Terminal · notify-send";
        return name;
    }

    function getAppCategoryGlyph(name, summary) {
        // Matched on the app name only — notification body text (summary) is
        // arbitrary and previously caused false matches (e.g. "Tutorial" ~ "tor").
        var str = (name || "").toLowerCase();

        // Terminals, CLI, Shell, notify-send
        if (["notify-send", "ghostty", "kitty", "alacritty", "foot", "wezterm", "terminal",
             "konsole", "xterm", "bash", "zsh", "python", "node", "cargo", "pacman", "yay",
             "paru", "git", "make", "gcc"].some(k => hasWord(str, k))) {
            return "󰆍"; // Terminal icon
        }

        // Web Browsers
        if (["firefox", "chrome", "chromium", "brave", "zen", "edge", "browser", "opera",
             "vivaldi", "safari", "tor"].some(k => hasWord(str, k))) {
            return "󰖟"; // Browser globe
        }

        // Chat & Social
        if (["discord", "vesktop", "webcord", "telegram", "signal", "slack", "element",
             "whatsapp", "matrix", "teams"].some(k => hasWord(str, k))) {
            return "󰭹"; // Message bubble
        }

        // Music & Media
        if (["spotify", "music", "amberol", "mpv", "vlc", "rhythmbox", "cider"].some(k => hasWord(str, k))) {
            return "󰝚"; // Music note
        }

        // Code & Text Editors
        if (["vscodium", "cursor", "neovim", "nvim", "emacs", "vim", "zed", "sublime",
             "editor"].some(k => hasWord(str, k))) {
            return "󰅩"; // Code brackets
        }

        // Mail & Calendar
        if (["mail", "thunderbird", "evolution", "geary", "calendar", "korganizer", "email",
             "inbox"].some(k => hasWord(str, k))) {
            return "󰇮"; // Mail / Inbox
        }

        // Screenshots & Graphics
        if (["screenshot", "grim", "slurp", "flameshot", "gimp", "inkscape", "krita",
             "blender"].some(k => hasWord(str, k))) {
            return "󰹑"; // Screenshot / Image
        }

        // Files & Downloads
        if (["thunar", "nautilus", "dolphin", "pcmanfm", "aria2", "qbittorrent",
             "transmission", "download"].some(k => hasWord(str, k))) {
            return "󰉋"; // Folder
        }

        // Hardware / System
        if (str.includes("battery") || str.includes("power") || str.includes("charging")) return "󰂄";
        if (str.includes("bluetooth")) return "󰂯";
        if (str.includes("wifi") || str.includes("network") || str.includes("ethernet")) return "󰖩";
        if (str.includes("volume") || str.includes("pipewire") || str.includes("mute")) return "󰕾";
        if (str.includes("settings") || str.includes("system") || str.includes("update") || str.includes("hyprland")) return "󰒓";

        // General clean notification bubble
        return "󰵅";
    }

    Connections {
        target: notificationServer
        function onNotification(notification) {
            // Do Not Disturb: keep the notification in history (handled by
            // notificationServer), just don't pop up an OSD card for it.
            if (DndService.isEnabled) return;

            // Add to our popup list
            var entry = {
                "notifId": osdRoot.nextNotifId++,
                "notif": notification,
                "summary": notification.summary || "",
                "body": notification.body || "",
                "appName": notification.appName || "Notification",
                "appIcon": notification.appIcon || ""
            };
            osdRoot.popups = osdRoot.popups.concat([entry]);
            popupModel.append(entry);

            // Auto-expire after 5 seconds
            expireTimer.createObject(osdRoot, {"targetNotif": entry});
        }
    }

    // Timer component for auto-expiring popups
    Component {
        id: expireTimer
        Timer {
            property var targetNotif
            interval: 5000
            running: true
            repeat: false
            onTriggered: {
                osdRoot.removePopup(targetNotif.notifId);
                destroy();
            }
        }
    }

    /**
     * Removes a notification popup by id from both the popupModel and local popups list,
     * and dismisses the underlying Notification so the server stops tracking it.
     * @param {int} notifId - The id of the popup entry to remove.
     */
    function removePopup(notifId) {
        var tracked = osdRoot.popups.find(p => p.notifId === notifId);
        for (var i = 0; i < popupModel.count; i++) {
            if (popupModel.get(i).notifId === notifId) {
                popupModel.remove(i);
                break;
            }
        }
        // Use functional filter array helper instead of manual array copying loop
        osdRoot.popups = osdRoot.popups.filter(p => p.notifId !== notifId);
        if (tracked && tracked.notif) tracked.notif.dismiss();
    }

    ListModel {
        id: popupModel
    }

    // The OSD overlay panel — only as tall as needed
    PanelWindow {
        id: osdPanel
        visible: popupModel.count > 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "notification-osd"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: true
            right: true
        }

        margins.top: 48
        margins.right: 16

        implicitWidth: 350
        // Height sized to content
        implicitHeight: Math.min(osdColumn.implicitHeight, 600)

        color: "transparent"
        // Don't grab focus — notifications should never steal input
        // The exclusive zone should be 0 so it doesn't push other windows
        exclusiveZone: 0

        Column {
            id: osdColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 10

            Repeater {
                model: popupModel

                Rectangle {
                    id: popupCard
                    width: osdColumn.width
                    implicitHeight: cardContent.implicitHeight + 24
                    color: Theme.glassBg
                    border.color: Theme.glassBorder
                    border.width: 1
                    radius: 19
                    antialiasing: true

                    // Slide-in animation
                    opacity: 1
                    x: 0
                    Component.onCompleted: {
                        slideIn.start();
                    }
                    NumberAnimation on x {
                        id: slideIn
                        from: 350
                        to: 0
                        duration: 250
                        easing.type: Easing.OutCubic
                        running: false
                    }

                    RowLayout {
                        id: cardContent
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 12
                        }
                        spacing: 12

                        // Left Icon Badge
                        Rectangle {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            radius: 10
                            antialiasing: true
                            color: Qt.rgba(1, 1, 1, 0.08)
                            border.color: Theme.glassBorder
                            border.width: 1
                            Layout.alignment: Qt.AlignTop
                            clip: true

                            Image {
                                id: notifImg
                                anchors.centerIn: parent
                                width: 22
                                height: 22
                                sourceSize: Qt.size(22, 22)
                                source: osdRoot.getIconSource(model.appIcon, model.appName)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                visible: status === Image.Ready && source != ""
                                onStatusChanged: {
                                    if (status === Image.Error) source = "";
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: osdRoot.getAppCategoryGlyph(model.appName, model.summary)
                                color: Theme.accent
                                font.family: Theme.fontMain
                                font.pixelSize: 16
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                visible: !notifImg.visible
                            }
                        }

                        // Notification Details Column
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            property bool isSummaryDuplicate: {
                                var s = (model.summary || "").trim().toLowerCase();
                                var a = (model.appName || "").trim().toLowerCase();
                                var d = osdRoot.getAppDisplayName(model.appName).toLowerCase();
                                return s.length > 0 && (s === a || s === d);
                            }

                            // Header Line: App Tag
                            Text {
                                text: osdRoot.getAppDisplayName(model.appName)
                                color: Qt.rgba(1, 1, 1, 0.75)
                                font.family: Theme.fontMain
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                            }

                            // Summary / Title
                            Text {
                                text: model.summary || ""
                                color: "#ffffff"
                                font.family: Theme.fontMain
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                                visible: text.length > 0 && (!parent.isSummaryDuplicate || (model.body || "").length === 0)
                            }

                            // Body
                            Text {
                                text: model.body || ""
                                color: parent.isSummaryDuplicate ? "#ffffff" : Qt.rgba(1, 1, 1, 0.85)
                                font.family: Theme.fontMain
                                font.pixelSize: parent.isSummaryDuplicate ? 12 : 11
                                font.weight: parent.isSummaryDuplicate ? Font.DemiBold : Font.Normal
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                lineHeight: 1.25
                                renderType: Text.NativeRendering
                                visible: text.length > 0
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: osdRoot.removePopup(model.notifId)
                    }
                }
            }
        }
    }
}
