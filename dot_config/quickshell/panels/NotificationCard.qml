import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs

// One notification, drawn the same way in the popup stack (NotificationOSD)
// and in the history list (NotificationCenter), so a fix to one is a fix to both.
//
// `notification` is a live, tracked Notification object — shell.qml sets
// tracked = true on arrival. Untracked notifications are destroyed by
// quickshell as soon as onNotification returns, which is what used to make
// every dismiss() throw "is not a function".
Rectangle {
    id: card

    required property var notification
    // Arrival time, recorded by shell.qml (Notification carries no timestamp).
    property var receivedAt: null
    // Reference time for the "5m" age label; the history panel moves it on open.
    property date now: new Date()

    // Emitted when the user clicks the card body. The owner decides what that
    // means: the popup hides itself, the history entry closes the panel.
    signal activated()

    readonly property bool isCritical: notification && notification.urgency === NotificationUrgency.Critical
    // Array.from: `actions` is a QList sequence, not guaranteed a real JS array.
    readonly property var allActions: notification ? Array.from(notification.actions) : []
    readonly property var defaultAction: allActions.find(a => a.identifier === "default") || null
    readonly property var buttonActions: allActions.filter(a => a.identifier !== "default")
    readonly property bool hovered: cardHover.hovered

    implicitHeight: content.implicitHeight + 24
    color: Theme.glassBg
    border.color: isCritical ? Theme.error : (cardHover.hovered ? Theme.borderMuted : Theme.glassBorder)
    border.width: 1
    radius: 19
    antialiasing: true

    Behavior on border.color { ColorAnimation { duration: 120 } }

    // Matches `key` as a whole word inside `str` — unlike includes(), "sh"
    // can't match inside "finished" and "tor" can't match inside "editor".
    function hasWord(str, key) {
        return new RegExp("\\b" + key + "\\b").test(str);
    }

    function iconSource() {
        var n = card.notification;
        if (!n) return "";
        // An inline image (avatar, album art, screenshot) beats the app icon.
        if (n.image) return n.image;
        var iconStr = n.appIcon;
        if (iconStr) {
            if (iconStr.startsWith("/") || iconStr.startsWith("file://")) return iconStr;
            if (Quickshell.hasThemeIcon(iconStr)) return "image://icon/" + iconStr;
        }
        // Fall back to the sender's real desktop entry (recovers a correct
        // icon for e.g. notify-send, which reports no usable icon name).
        var entry = DesktopEntries.heuristicLookup(n.desktopEntry || n.appName || "");
        if (entry && entry.icon) {
            return entry.icon.startsWith("/") ? entry.icon : "image://icon/" + entry.icon;
        }
        return "";
    }

    function appDisplayName() {
        var name = card.notification ? card.notification.appName : "";
        if (!name) return "Notification";
        if (name.toLowerCase() === "notify-send") return "Terminal · notify-send";
        return name;
    }

    function categoryGlyph() {
        // Matched on the app name only — notification body text is arbitrary
        // and previously caused false matches (e.g. "Tutorial" ~ "tor").
        var str = (card.notification ? card.notification.appName || "" : "").toLowerCase();
        if (["notify-send", "ghostty", "kitty", "alacritty", "foot", "wezterm", "terminal",
             "konsole", "xterm", "bash", "zsh", "python", "node", "cargo", "pacman", "yay",
             "paru", "git", "make", "gcc"].some(k => hasWord(str, k))) return "󰆍";
        if (["firefox", "chrome", "chromium", "brave", "zen", "edge", "browser", "opera",
             "vivaldi", "safari", "tor"].some(k => hasWord(str, k))) return "󰖟";
        if (["discord", "vesktop", "webcord", "telegram", "signal", "slack", "element",
             "whatsapp", "matrix", "teams"].some(k => hasWord(str, k))) return "󰭹";
        if (["spotify", "music", "amberol", "mpv", "vlc", "rhythmbox", "cider"].some(k => hasWord(str, k))) return "󰝚";
        if (["volume", "pipewire", "mute"].some(k => str.includes(k))) return "󰕾";
        return "󰵅";
    }

    function timeText() {
        if (!card.receivedAt) return "";
        var mins = Math.floor((card.now.getTime() - card.receivedAt.getTime()) / 60000);
        if (mins < 1) return "now";
        if (mins < 60) return mins + "m";
        if (mins < 1440) return Math.floor(mins / 60) + "h";
        return Qt.formatDate(card.receivedAt, "d MMM");
    }

    HoverHandler { id: cardHover }

    // Card body click: run the app's default action (Firefox focuses the tab,
    // Discord opens the channel). Declared before the content so the close and
    // action buttons, which come later, sit on top and win their clicks.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (card.defaultAction) card.defaultAction.invoke();
            card.activated();
        }
    }

    ColumnLayout {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // ▓▒░ ICON BADGE — inline image, app icon, or a category glyph
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                Layout.alignment: Qt.AlignTop
                radius: 10
                antialiasing: true
                color: Qt.rgba(1, 1, 1, 0.08)
                border.color: Theme.glassBorder
                border.width: 1
                clip: true

                Image {
                    id: notifImg
                    anchors.centerIn: parent
                    // Inline images fill the badge; theme icons stay icon-sized.
                    readonly property bool isInlineImage: card.notification && !!card.notification.image
                    width: isInlineImage ? 36 : 22
                    height: width
                    sourceSize: Qt.size(width * 2, height * 2)
                    source: card.iconSource()
                    fillMode: isInlineImage ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                    visible: status === Image.Ready && source.toString() !== ""
                }

                Text {
                    anchors.centerIn: parent
                    text: card.categoryGlyph()
                    color: Theme.accent
                    font.family: Theme.fontMain
                    font.pixelSize: 16
                    visible: !notifImg.visible
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                readonly property string summary: card.notification ? card.notification.summary || "" : ""
                readonly property string body: card.notification ? card.notification.body || "" : ""
                readonly property bool isSummaryDuplicate: {
                    var s = summary.trim().toLowerCase();
                    var a = (card.notification ? card.notification.appName || "" : "").trim().toLowerCase();
                    return s.length > 0 && (s === a || s === card.appDisplayName().toLowerCase());
                }

                // Header: app name · age · close
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: card.appDisplayName()
                        color: Qt.rgba(1, 1, 1, 0.75)
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    Text {
                        text: card.timeText()
                        color: Theme.subtext0
                        font.family: Theme.fontMain
                        font.pixelSize: 10
                        visible: text.length > 0
                        renderType: Text.NativeRendering
                    }

                    // Close = dismiss for good (gone from history too).
                    Rectangle {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        radius: 9
                        color: closeHover.hovered ? Theme.hoverBg : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: closeHover.hovered ? Theme.text : Theme.subtext0
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                        }

                        HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: card.notification.dismiss() }
                    }
                }

                Text {
                    text: parent.summary
                    color: "#ffffff"
                    font.family: Theme.fontMain
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                    visible: text.length > 0 && (!parent.isSummaryDuplicate || parent.body.length === 0)
                }

                // Body markup (bold, italics, links) is advertised in shell.qml,
                // so apps send it — render it rather than showing raw tags.
                Text {
                    text: parent.body
                    textFormat: Text.StyledText
                    color: parent.isSummaryDuplicate ? "#ffffff" : Qt.rgba(1, 1, 1, 0.85)
                    linkColor: Theme.accent
                    font.family: Theme.fontMain
                    font.pixelSize: parent.isSummaryDuplicate ? 12 : 11
                    font.weight: parent.isSummaryDuplicate ? Font.DemiBold : Font.Normal
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    lineHeight: 1.25
                    renderType: Text.NativeRendering
                    visible: text.length > 0
                    onLinkActivated: (link) => Qt.openUrlExternally(link)
                }
            }
        }

        // ▓▒░ ACTION BUTTONS — "Reply", "Mark as read", "Open", ...
        Flow {
            Layout.fillWidth: true
            spacing: 6
            visible: card.buttonActions.length > 0

            Repeater {
                model: card.buttonActions

                Rectangle {
                    id: actionBtn
                    required property var modelData
                    width: actionText.implicitWidth + 20
                    height: 24
                    radius: 12
                    antialiasing: true
                    color: actionHover.hovered ? Theme.bgSelection : Theme.hoverBg
                    border.color: Theme.glassBorder
                    border.width: 1

                    Text {
                        id: actionText
                        anchors.centerIn: parent
                        text: actionBtn.modelData.text
                        color: Theme.text
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
                    }

                    HoverHandler { id: actionHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: actionBtn.modelData.invoke() }
                }
            }
        }
    }
}
