import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."

PanelWindow {
    id: notificationPopup
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-screenshot"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: -1

    // Background click-to-close
    MouseArea {
        anchors.fill: parent
        onClicked: notificationPopup.visible = false
    }

    // Reference to the global notification server passed from root
    required property var notificationServer

    readonly property int notifCount: (notificationServer && notificationServer.trackedNotifications) ? notificationServer.trackedNotifications.count : 0
    readonly property bool hasNotifications: notifCount > 0

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

    Rectangle {
        anchors { top: parent.top; right: parent.right }
        anchors.topMargin: 52
        anchors.rightMargin: 16
        width: 320
        height: 400
        color: Theme.glassBg
        border.color: Theme.glassBorder
        border.width: 1
        radius: 19
        antialiasing: true

        // Block background click propagation
        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Header (only shown when notifications exist)
            RowLayout {
                Layout.fillWidth: true
                visible: notificationPopup.hasNotifications

                RowLayout {
                    spacing: 6
                    Text {
                        text: "󰇮"
                        color: Theme.accent
                        font.family: Theme.fontMain
                        font.pixelSize: 13
                        verticalAlignment: Text.AlignVCenter
                    }
                    Text {
                        text: notificationPopup.notifCount.toString()
                        color: Theme.text
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        verticalAlignment: Text.AlignVCenter
                        renderType: Text.NativeRendering
                    }
                }

                Item { Layout.fillWidth: true }

                // Clear All Button
                Rectangle {
                    width: 68
                    height: 22
                    radius: 11
                    antialiasing: true
                    color: clearMouse.hovered ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                    border.color: Theme.glassBorder
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: "󰎟"
                            color: Theme.subtext0
                            font.family: Theme.fontMain
                            font.pixelSize: 10
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            text: "Clear"
                            color: Theme.subtext0
                            font.family: Theme.fontMain
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            verticalAlignment: Text.AlignVCenter
                            renderType: Text.NativeRendering
                        }
                    }

                    HoverHandler { id: clearMouse }
                    TapHandler {
                        onTapped: {
                            var server = notificationPopup.notificationServer;
                            if (!server || !server.trackedNotifications) return;
                            var count = server.trackedNotifications.count;
                            for (var i = count - 1; i >= 0; i--) {
                                var notif = server.trackedNotifications.get(i);
                                if (notif) notif.dismiss();
                            }
                        }
                    }
                }
            }

            // List of Notifications / Empty State
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Empty State
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: !notificationPopup.hasNotifications

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰇮"
                        color: Theme.subtext0
                        font.family: Theme.fontMain
                        font.pixelSize: 26
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No notifications"
                        color: Theme.subtext0
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        renderType: Text.NativeRendering
                    }
                }

                ListView {
                    id: listView
                    anchors.fill: parent
                    model: notificationPopup.notificationServer ? notificationPopup.notificationServer.trackedNotifications : null
                    spacing: 8
                    clip: true
                    visible: notificationPopup.hasNotifications

                    delegate: Rectangle {
                        width: listView.width
                        implicitHeight: notifContent.implicitHeight + 20
                        color: Theme.bgSelection
                        radius: 12
                        antialiasing: true
                        border.color: Theme.glassBorder
                        border.width: 1

                        required property var modelData

                        RowLayout {
                            id: notifContent
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 10
                            }
                            spacing: 10

                            // App Icon Badge
                            Rectangle {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                Layout.alignment: Qt.AlignTop
                                radius: 8
                                antialiasing: true
                                color: Qt.rgba(1, 1, 1, 0.08)
                                border.color: Theme.glassBorder
                                border.width: 1
                                clip: true

                                Image {
                                    id: panelNotifImg
                                    anchors.centerIn: parent
                                    width: 22
                                    height: 22
                                    source: notificationPopup.getIconSource(modelData.appIcon, modelData.appName)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    visible: status === Image.Ready && source != ""
                                    onStatusChanged: {
                                        if (status === Image.Error) source = "";
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: notificationPopup.getAppCategoryGlyph(modelData.appName, modelData.summary)
                                    color: Theme.accent
                                    font.family: Theme.fontMain
                                    font.pixelSize: 15
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    visible: !panelNotifImg.visible
                                }
                            }

                            // Notification Info
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                property bool isSummaryDuplicate: {
                                    var s = (modelData.summary || "").trim().toLowerCase();
                                    var a = (modelData.appName || "").trim().toLowerCase();
                                    var d = notificationPopup.getAppDisplayName(modelData.appName).toLowerCase();
                                    return s.length > 0 && (s === a || s === d);
                                }

                                Text {
                                    text: notificationPopup.getAppDisplayName(modelData.appName)
                                    color: Qt.rgba(1, 1, 1, 0.75)
                                    font.family: Theme.fontMain
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: modelData.summary || ""
                                    color: "#ffffff"
                                    font.family: Theme.fontMain
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    renderType: Text.NativeRendering
                                    visible: text.length > 0 && (!parent.isSummaryDuplicate || (modelData.body || "").length === 0)
                                }

                                Text {
                                    text: modelData.body || ""
                                    color: parent.isSummaryDuplicate ? "#ffffff" : Qt.rgba(1, 1, 1, 0.85)
                                    font.family: Theme.fontMain
                                    font.pixelSize: parent.isSummaryDuplicate ? 12 : 11
                                    font.weight: parent.isSummaryDuplicate ? Font.DemiBold : Font.Normal
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    lineHeight: 1.2
                                    renderType: Text.NativeRendering
                                    visible: text.length > 0
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modelData.dismiss()
                        }
                    }
                }
            }
        }
    }
}
