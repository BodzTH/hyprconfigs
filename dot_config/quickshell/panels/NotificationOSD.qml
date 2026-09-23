pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.services

// Popup stack, top-right. Lives directly in ShellRoot (not inside Variants).
//
// A popup is only a *view* of a notification: when it times out the card goes
// away but the notification stays tracked, so it is still in the history
// (NotificationCenter). Only the card's close button, an action, or the app
// itself closes the notification for good.
Item {
    id: osdRoot

    required property var notificationServer
    // Arrival times keyed by notification id, owned by shell.qml.
    required property var receivedTimes

    // Notification objects currently shown as popups, newest last.
    property var popups: []

    // Apps that already play their own sound — a second one from us would
    // double up. Matched against appName, case-insensitively.
    readonly property var selfSoundingApps: ["discord", "vesktop", "webcord", "telegramdesktop", "spotify"]

    function removePopup(notification) {
        popups = popups.filter(p => p !== notification);
    }

    function playSound(notification) {
        var hints = notification.hints || {};
        if (hints["suppress-sound"]) return;
        var app = (notification.appName || "").toLowerCase();
        if (selfSoundingApps.some(a => app.includes(a))) return;

        // canberra resolves XDG sound-theme names, so an app's own sound-name
        // hint works as well as a file path.
        var args = ["canberra-gtk-play", "--description=notification"];
        if (hints["sound-file"]) {
            args.push("-f", String(hints["sound-file"]).replace(/^file:\/\//, ""));
        } else {
            var critical = notification.urgency === NotificationUrgency.Critical;
            args.push("-i", hints["sound-name"] || (critical ? "bell" : "message-new-instant"));
        }
        Quickshell.execDetached(args);
    }

    Connections {
        target: osdRoot.notificationServer
        function onNotification(notification) {
            // shell.qml has already set tracked = true, so the object outlives
            // this handler. Drop the popup the moment the notification closes,
            // whoever closed it (us, the app, or the history panel).
            notification.closed.connect(() => osdRoot.removePopup(notification));

            // Do Not Disturb: the notification is kept in history, silently.
            // Critical ones (low battery, failed backups) still get through.
            var critical = notification.urgency === NotificationUrgency.Critical;
            if (DndService.isEnabled && !critical) return;

            osdRoot.playSound(notification);
            osdRoot.popups = osdRoot.popups.concat([notification]);
        }
    }

    // The overlay panel — only as tall as needed
    PanelWindow {
        id: osdPanel
        visible: osdRoot.popups.length > 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "notification-osd"
        // Notifications never steal keyboard input
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: true
            right: true
        }

        margins.top: 48
        margins.right: 16

        implicitWidth: 360
        implicitHeight: Math.min(osdColumn.implicitHeight, 600)

        color: "transparent"
        exclusiveZone: 0

        Column {
            id: osdColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 10

            Repeater {
                // ScriptModel diffs by object identity, so adding a popup does
                // not rebuild (and re-animate) the ones already on screen.
                model: ScriptModel { values: osdRoot.popups }

                NotificationCard {
                    id: popupCard
                    required property var modelData
                    notification: modelData
                    receivedAt: osdRoot.receivedTimes[modelData.id] || null
                    width: osdColumn.width

                    // Clicking a popup acknowledges it; it stays in history.
                    onActivated: osdRoot.removePopup(modelData)

                    // ▓▒░ EXPIRY — the app's own timeout if it gave one,
                    // otherwise 5s. Critical notifications stay until handled.
                    // Hovering pauses the countdown so a popup never vanishes
                    // while it is being read. expireTimeout is milliseconds
                    // (`notify-send -t 1500` reads back 1500), -1/0 = default.
                    Timer {
                        interval: popupCard.modelData.expireTimeout > 0 ? popupCard.modelData.expireTimeout : 5000
                        running: !popupCard.isCritical && !popupCard.hovered
                        onTriggered: {
                            // Transient notifications ask not to be kept at all.
                            if (popupCard.modelData.transient) popupCard.modelData.expire();
                            else osdRoot.removePopup(popupCard.modelData);
                        }
                    }

                    // Slide in from the right
                    NumberAnimation on x {
                        from: 360
                        to: 0
                        duration: 250
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
