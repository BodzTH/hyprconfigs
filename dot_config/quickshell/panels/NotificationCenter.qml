pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// Notification history + Do Not Disturb — SUPER+comma, the bar bell, or a
// right-click on the clock. Lists every notification the server is still
// tracking (see NotificationOSD.qml: popups time out, history does not).
PanelWindow {
    id: centerPopup
    visible: false

    required property var notificationServer
    required property var receivedTimes

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: -1

    // Newest first
    readonly property var entries: notificationServer.trackedNotifications.values.slice().reverse()

    // Reference time for the "5m" ages, moved on every open.
    property date openedAt: new Date()
    onVisibleChanged: if (visible) openedAt = new Date()

    function clearAll() {
        // Copy first: each dismiss() removes an entry from the live list.
        notificationServer.trackedNotifications.values.slice().forEach(n => n.dismiss());
    }

    // Background click-to-close
    MouseArea {
        anchors.fill: parent
        onClicked: centerPopup.visible = false
    }

    Rectangle {
        id: card
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 48
        anchors.rightMargin: 16
        width: 380
        height: Math.min(header.implicitHeight + (centerPopup.entries.length > 0 ? listView.contentHeight + 10 : 90) + 24, parent.height * 0.8)
        color: Theme.glassBg
        border.color: Theme.glassBorder
        border.width: 1
        radius: 19
        antialiasing: true

        focus: true
        Keys.onEscapePressed: centerPopup.visible = false

        // Swallow clicks so they don't reach the close-on-background area
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // ▓▒░ HEADER — title, DND switch, clear all
            RowLayout {
                id: header
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Notifications"
                    color: Theme.text
                    font.family: Theme.fontMain
                    font.pixelSize: Theme.fontSize + 2
                    font.weight: Font.Bold
                    Layout.fillWidth: true
                    renderType: Text.NativeRendering
                }

                // Do Not Disturb switch
                Rectangle {
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: dndRow.implicitWidth + 16
                    radius: 12
                    antialiasing: true
                    color: DndService.isEnabled ? Theme.accent : (dndHover.hovered ? Theme.hoverBg : "transparent")
                    border.color: Theme.borderMuted
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        id: dndRow
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            text: DndService.isEnabled ? "󰂛" : "󰂚"
                            color: DndService.isEnabled ? Theme.base : Theme.text
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                        }
                        Text {
                            text: "Do not disturb"
                            color: DndService.isEnabled ? Theme.base : Theme.text
                            font.family: Theme.fontMain
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            renderType: Text.NativeRendering
                        }
                    }

                    HoverHandler { id: dndHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: DndService.toggle() }
                }

                // Clear all
                Rectangle {
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: 24
                    radius: 12
                    color: clearHover.hovered ? Theme.hoverBg : "transparent"
                    visible: centerPopup.entries.length > 0

                    Text {
                        anchors.centerIn: parent
                        text: "󰎟"
                        color: Theme.text
                        font.family: Theme.fontMain
                        font.pixelSize: 14
                    }

                    HoverHandler { id: clearHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: centerPopup.clearAll() }
                }
            }

            // ▓▒░ HISTORY
            ListView {
                id: listView
                visible: centerPopup.entries.length > 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel { values: centerPopup.entries }

                delegate: NotificationCard {
                    required property var modelData
                    notification: modelData
                    receivedAt: centerPopup.receivedTimes[modelData.id] || null
                    now: centerPopup.openedAt
                    width: listView.width
                    // Following a notification's default action goes to the
                    // app — get out of the way.
                    onActivated: if (defaultAction) centerPopup.visible = false
                }
            }

            // Empty state
            Column {
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.bottomMargin: 12
                spacing: 6
                visible: centerPopup.entries.length === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: DndService.isEnabled ? "󰂛" : "󰂜"
                    color: Theme.subtext0
                    font.family: Theme.fontMain
                    font.pixelSize: 28
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No notifications"
                    color: Theme.subtext0
                    font.family: Theme.fontMain
                    font.pixelSize: Theme.fontSize
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}
