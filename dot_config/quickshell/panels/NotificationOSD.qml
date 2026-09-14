import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications as Notifs
import ".."

// This component lives directly in ShellRoot (not inside Variants).
// It listens for the onNotification signal and manages a list of
// visible popup items rendered inside a single overlay PanelWindow.

Item {
    id: osdRoot

    required property var notificationServer

    // Internal list of currently-visible popup notifications
    property var popups: []
    property int nextNotifId: 0

    function getIconSource(iconStr, appName) {
        if (!iconStr) return "";
        if (iconStr.startsWith("/") || iconStr.startsWith("file://")) {
            return iconStr;
        }
        var lower = (iconStr + " " + (appName || "")).toLowerCase();
        // Skip CLI/generic names that don't have XDG icon assets and would produce checkerboards
        if (lower.includes("notify-send") || lower.includes("bash") || lower.includes("sh") ||
            lower.includes("zsh") || lower.includes("python") || lower.includes("curl") ||
            lower.includes("wget") || lower.includes("quickshell") || lower.includes("hyprland") ||
            lower.includes("unknown") || lower.includes("dialog-information")) {
            return "";
        }
        if (iconStr && iconStr.length > 0) {
            return "image://icon/" + iconStr;
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
        var str = ((name || "") + " " + (summary || "")).toLowerCase();
        
        // Terminals, CLI, Shell, notify-send
        if (str.includes("notify-send") || str.includes("ghostty") || str.includes("kitty") ||
            str.includes("alacritty") || str.includes("foot") || str.includes("wezterm") ||
            str.includes("terminal") || str.includes("konsole") || str.includes("xterm") ||
            str.includes("bash") || str.includes("zsh") || str.includes("sh") ||
            str.includes("python") || str.includes("node") || str.includes("cargo") ||
            str.includes("pacman") || str.includes("yay") || str.includes("paru") ||
            str.includes("git") || str.includes("make") || str.includes("gcc")) {
            return "󰆍"; // Terminal icon
        }

        // Web Browsers
        if (str.includes("firefox") || str.includes("chrome") || str.includes("chromium") ||
            str.includes("brave") || str.includes("zen") || str.includes("edge") ||
            str.includes("browser") || str.includes("opera") || str.includes("vivaldi") ||
            str.includes("safari") || str.includes("tor")) {
            return "󰖟"; // Browser globe
        }

        // Chat & Social
        if (str.includes("discord") || str.includes("vesktop") || str.includes("webcord") ||
            str.includes("telegram") || str.includes("signal") || str.includes("slack") ||
            str.includes("element") || str.includes("whatsapp") || str.includes("matrix") ||
            str.includes("teams") || str.includes("chat")) {
            return "󰭹"; // Message bubble
        }

        // Music & Media
        if (str.includes("spotify") || str.includes("music") || str.includes("amberol") ||
            str.includes("mpv") || str.includes("vlc") || str.includes("rhythmbox") ||
            str.includes("cider") || str.includes("audio") || str.includes("sound") ||
            str.includes("track") || str.includes("song")) {
            return "󰝚"; // Music note
        }

        // Code & Text Editors
        if (str.includes("code") || str.includes("vscodium") || str.includes("cursor") ||
            str.includes("neovim") || str.includes("nvim") || str.includes("emacs") ||
            str.includes("vim") || str.includes("zed") || str.includes("sublime") ||
            str.includes("ide") || str.includes("editor")) {
            return "󰅩"; // Code brackets
        }

        // Mail & Calendar
        if (str.includes("mail") || str.includes("thunderbird") || str.includes("evolution") ||
            str.includes("geary") || str.includes("calendar") || str.includes("korganizer") ||
            str.includes("email") || str.includes("inbox")) {
            return "󰇮"; // Mail / Inbox
        }

        // Screenshots & Graphics
        if (str.includes("screenshot") || str.includes("grim") || str.includes("slurp") ||
            str.includes("flameshot") || str.includes("gimp") || str.includes("inkscape") ||
            str.includes("krita") || str.includes("blender") || str.includes("image")) {
            return "󰹑"; // Screenshot / Image
        }

        // Files & Downloads
        if (str.includes("thunar") || str.includes("nautilus") || str.includes("dolphin") ||
            str.includes("pcmanfm") || str.includes("aria2") || str.includes("qbittorrent") ||
            str.includes("transmission") || str.includes("download") || str.includes("file")) {
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
            console.log("[OSD] Received notification: " + notification.summary);
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
                osdRoot.removePopup(targetNotif);
                destroy();
            }
        }
    }

    /**
     * Removes a notification popup entry from both the popupModel and local popups list.
     * @param {object} entry - The notification entry containing the target notifId to remove.
     */
    function removePopup(entry) {
        for (var i = 0; i < popupModel.count; i++) {
            if (popupModel.get(i).notifId === entry.notifId) {
                popupModel.remove(i);
                break;
            }
        }
        // Use functional filter array helper instead of manual array copying loop
        osdRoot.popups = osdRoot.popups.filter(p => p.notifId !== entry.notifId);
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
                        onClicked: popupModel.remove(index)
                    }
                }
            }
        }
    }
}
