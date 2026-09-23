pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Networking
import qs
import qs.services

// NetworkPanel — drop-down from the bar's network item.
//
// Rebuilt 2026-09-23; the old panel is in ~/.config/config_archive/quickshell/.
// Everything goes through services/NetworkService.qml — NetworkManager over
// D-Bus for live state, nmcli only for one-shot actions — and nothing here
// opens an outside tool (no nmtui, editor, applet or terminal).
//
// Sections: status header (online pill) · Ethernet · Wi-Fi (+ networks, join
// hidden) · VPN (+ WireGuard import). Accent marks what is on/connected and
// the focused row; everything else stays glass, like the launcher.
//
// Keyboard: Tab / ↑↓ move between rows, Enter / Space activate, Esc closes.
PanelWindow {
    id: panel
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-network"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Full screen so a click outside closes it
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: "transparent"

    // Screen x the drop-down centres under (the bar item's centre)
    property real anchorX: width - 200

    // Which rows are expanded
    property var expandedNetwork: null      // WifiNetwork showing its password field
    property string detailsFor: ""          // "ethernet" | "wifi" | ""
    property bool hiddenOpen: false
    property bool importOpen: false
    property bool dnsOpen: false
    // DNS-over-TLS choice for the next apply. Starts as whatever the
    // connection has; Hello defaults new picks to encrypted.
    property bool dnsUseDot: true

    // Per-network error text after a failed connect, keyed by name
    property var wifiErrors: ({})
    property string hiddenMessage: ""
    property bool hiddenBusy: false
    property string importMessage: ""
    property string vpnBusy: ""             // name of the VPN being switched

    readonly property color warning: "#dfaf87"   // same amber as nvim/yazi's palette

    function toggle(scr, x) {
        if (visible) { visible = false; return; }
        if (scr) screen = scr;
        if (x !== undefined) anchorX = x;
        expandedNetwork = null;
        detailsFor = "";
        hiddenOpen = false;
        importOpen = false;
        dnsOpen = false;
        hiddenMessage = "";
        importMessage = "";
        visible = true;
        NetworkService.refreshVpns();
        NetworkService.findWireguardFiles();
        NetworkService.refreshDns();
        firstFocus.forceActiveFocus();
    }

    // `qs ipc call network toggle` — opens on the focused screen under where
    // the bar item sits. No keybind by design (bar only); this is for testing
    // and scripts.
    IpcHandler {
        target: "network"
        function toggle(): void {
            // Screen width, not panel.width: the window isn't mapped yet, so
            // its own width is still 0 here.
            var scr = root.getFocusedScreen();
            root.toggleNetwork(scr, (scr ? scr.width : 1920) - 200);
        }
    }

    // Scan only while someone is looking at the list.
    onVisibleChanged: {
        if (NetworkService.wifiDevice) NetworkService.wifiDevice.scannerEnabled = visible;
    }

    function openDetails(which, ifname) {
        if (detailsFor === which) { detailsFor = ""; return; }
        detailsFor = which;
        NetworkService.fetchDetails(ifname);
    }

    function activateNetwork(net) {
        if (net.connected) {
            openDetails("wifi", NetworkService.wifiDevice.name);
        } else if (NetworkService.needsPassword(net)) {
            expandedNetwork = expandedNetwork === net ? null : net;
        } else {
            clearError(net);
            NetworkService.connectWifi(net);
        }
    }

    function clearError(net) {
        var e = Object.assign({}, wifiErrors);
        delete e[net.name];
        wifiErrors = e;
    }

    Connections {
        target: NetworkService
        function onWifiFailed(network, reason, wantsPassword) {
            var e = Object.assign({}, panel.wifiErrors);
            e[network.name] = wantsPassword ? "Wrong or missing password" : reason;
            panel.wifiErrors = e;
            // What nm-applet's password dialog used to do: ask again, inline.
            if (wantsPassword) panel.expandedNetwork = network;
        }
        function onHiddenResult(ok, message) {
            panel.hiddenBusy = false;
            panel.hiddenMessage = ok ? "" : message;
            if (ok) panel.hiddenOpen = false;
        }
        function onVpnResult(name, ok, message) { panel.vpnBusy = ""; }
        function onImportResult(ok, message) {
            panel.importMessage = ok ? "Imported" : message;
            if (ok) panel.importOpen = false;
        }
    }

    function signalGlyph(s) {
        return s > 0.75 ? "󰤨" : s > 0.5 ? "󰤥" : s > 0.25 ? "󰤢" : "󰤟";
    }

    function securityText(net) {
        var t = WifiSecurityType.toString(net.security);
        if (net.security === WifiSecurityType.Open) return "Open";
        if (net.security === WifiSecurityType.Sae) return "WPA3";
        if (net.security === WifiSecurityType.Wpa2Psk) return "WPA2";
        if (net.security === WifiSecurityType.WpaPsk) return "WPA";
        if (net.security === WifiSecurityType.Owe) return "Enhanced open";
        return t;
    }

    // ▓▒░ SMALL REUSABLE PIECES

    // On/off switch: accent when on, glass when off.
    component Toggle: Rectangle {
        id: toggle
        property bool checked: false
        property bool busy: false
        signal toggled()

        implicitWidth: 38
        implicitHeight: 22
        radius: height / 2
        antialiasing: true
        color: checked ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.85) : Qt.rgba(1, 1, 1, 0.08)
        border.color: checked ? Theme.accent : Theme.borderMuted
        border.width: 1
        opacity: busy ? 0.55 : 1
        Behavior on color { ColorAnimation { duration: 160 } }

        Rectangle {
            width: parent.height - 6
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: toggle.checked ? parent.width - width - 3 : 3
            color: toggle.checked ? Theme.base : Theme.subtext0
            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }

        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: if (!toggle.busy) toggle.toggled() }
    }

    // Small round icon button (details / disconnect / forget).
    component IconButton: Rectangle {
        id: iconBtn
        property string glyph: ""
        property string tip: ""
        property color tint: Theme.text
        signal clicked()

        implicitWidth: 26
        implicitHeight: 26
        radius: 13
        color: btnHover.hovered ? Theme.bgSelection : Qt.rgba(1, 1, 1, 0.05)
        border.color: Theme.glassBorder
        border.width: 1
        Behavior on color { ColorAnimation { duration: 100 } }

        Text {
            anchors.centerIn: parent
            text: iconBtn.glyph
            color: iconBtn.tint
            font.family: Theme.fontMain
            font.pixelSize: 13
        }
        HoverHandler { id: btnHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: iconBtn.clicked() }
    }

    // Glass text field used for passwords, SSIDs and paths.
    component Field: Rectangle {
        id: field
        property alias text: input.text
        property string placeholder: ""
        property bool secret: false
        property bool revealed: false
        property alias input: input
        signal accepted()

        implicitHeight: 34
        radius: 8
        color: Theme.glassBg
        border.color: input.activeFocus ? Theme.accent : Theme.borderMuted
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 120 } }

        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
            spacing: 6

            TextInput {
                id: input
                Layout.fillWidth: true
                color: Theme.text
                font.family: Theme.fontMain
                font.pixelSize: 12
                echoMode: field.secret && !field.revealed ? TextInput.Password : TextInput.Normal
                clip: true
                selectByMouse: true
                Keys.onReturnPressed: field.accepted()
                Keys.onEnterPressed: field.accepted()

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: field.placeholder
                    color: Theme.subtext0
                    font: input.font
                    visible: input.text.length === 0
                }
            }

            // Show / hide password
            Text {
                visible: field.secret
                text: field.revealed ? "󰈉" : "󰈈"
                color: Theme.subtext0
                font.family: Theme.fontMain
                font.pixelSize: 14
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: field.revealed = !field.revealed }
            }
        }
    }

    // Accent pill button (Connect / Join / Import).
    component PillButton: Rectangle {
        id: pill
        property string label: ""
        property bool enabled_: true
        signal clicked()

        implicitWidth: pillText.implicitWidth + 24
        implicitHeight: 34
        radius: 8
        opacity: enabled_ ? 1 : 0.45
        color: pillHover.hovered && enabled_ ? Qt.lighter(Theme.accent, 1.15) : Theme.accent
        Behavior on color { ColorAnimation { duration: 100 } }

        Text {
            id: pillText
            anchors.centerIn: parent
            text: pill.label
            color: Theme.base
            font.family: Theme.fontMain
            font.pixelSize: 12
            font.weight: Font.Bold
        }
        HoverHandler { id: pillHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: if (pill.enabled_) pill.clicked() }
    }

    // A clickable row: icon badge, title/subtitle, and a right-hand slot.
    // Focus (keyboard) and hover share the launcher's row look; `active`
    // tints the icon with the accent (connected / on).
    component Row_: Rectangle {
        id: row
        property string glyph: ""
        property string title: ""
        property string subtitle: ""
        property color subtitleColor: Theme.subtext0
        property bool active: false
        default property alias trailing: trailingSlot.data
        signal activated()

        Layout.fillWidth: true
        implicitHeight: 48
        radius: 10
        antialiasing: true
        activeFocusOnTab: true
        color: activeFocus ? Theme.bgSelection : rowHover.hovered ? Theme.hoverBg : "transparent"
        border.color: activeFocus ? Theme.glassBorder : "transparent"
        border.width: 1
        Behavior on color { ColorAnimation { duration: 80 } }

        readonly property bool hovered: rowHover.hovered

        Keys.onReturnPressed: activated()
        Keys.onSpacePressed: activated()

        // Accent stripe on the keyboard-focused row
        Rectangle {
            width: 3
            height: parent.height - 18
            radius: 1.5
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.accent
            visible: row.activeFocus
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 8
                color: row.active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                border.color: row.active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5) : Theme.glassBorder
                border.width: 1
                Behavior on color { ColorAnimation { duration: 160 } }

                Text {
                    anchors.centerIn: parent
                    text: row.glyph
                    color: row.active ? Theme.accent : Theme.subtext0
                    font.family: Theme.fontMain
                    font.pixelSize: 15
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: row.title
                    color: Theme.text
                    font.family: Theme.fontMain
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }
                Text {
                    text: row.subtitle
                    visible: text.length > 0
                    color: row.subtitleColor
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }
            }

            RowLayout {
                id: trailingSlot
                spacing: 6
            }
        }

        HoverHandler { id: rowHover }
        TapHandler {
            // A tap on a switch or button in the trailing slot belongs to that
            // control only. Both handlers used to fire: the Wi-Fi switch
            // flipped Wi-Fi off, then the row flipped it straight back on
            // (switching off updates instantly, so the second flip saw "off").
            // Switching on applies a moment later, so both flips said "on" —
            // which is why only turning Wi-Fi off seemed broken.
            onTapped: (eventPoint) => {
                var p = trailingSlot.mapFromItem(row, eventPoint.position.x, eventPoint.position.y);
                if (trailingSlot.visible && p.x >= 0 && p.y >= 0
                        && p.x <= trailingSlot.width && p.y <= trailingSlot.height)
                    return;
                row.forceActiveFocus();
                row.activated();
            }
        }
    }

    // IP details for the active connection on one interface.
    component DetailsBlock: ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 54
        Layout.rightMargin: 12
        Layout.bottomMargin: 6
        spacing: 3

        Repeater {
            model: {
                var d = NetworkService.details;
                if (NetworkService.detailsLoading || !d.ip) return [["", "Loading…"]];
                var rows = [["IP", d.ip.join(", ") || "—"], ["Gateway", d.gateway || "—"], ["DNS", d.dns.join(", ") || "—"]];
                if (d.ip6.length) rows.push(["IPv6", d.ip6.join(", ")]);
                return rows;
            }
            delegate: RowLayout {
                id: detailRow
                required property var modelData
                spacing: 10
                Text {
                    text: detailRow.modelData[0]
                    color: Theme.subtext0
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                    Layout.preferredWidth: 58
                }
                Text {
                    text: detailRow.modelData[1]
                    color: Theme.text
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    // Section label ("WI-FI NETWORKS", "VPN")
    component SectionLabel: Text {
        Layout.leftMargin: 12
        Layout.topMargin: 4
        color: Theme.subtext0
        font.family: Theme.fontMain
        font.pixelSize: 10
        font.weight: Font.Bold
        font.letterSpacing: 1
        renderType: Text.NativeRendering
    }

    component Divider: Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        implicitHeight: 1
        color: Theme.glassBorder
    }

    // ▓▒░ LAYOUT

    // Close on outside click
    MouseArea {
        anchors.fill: parent
        onClicked: panel.visible = false
    }

    Rectangle {
        id: card
        width: 380
        x: Math.max(12, Math.min(panel.width - width - 12, panel.anchorX - width / 2))
        y: 48
        height: Math.min(content.implicitHeight + 20, panel.height - 64)
        color: Theme.glassBg
        radius: 14
        antialiasing: true
        border.color: Theme.glassBorder
        border.width: 1
        clip: true

        // Drop-down animation
        opacity: panel.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        transform: Translate {
            y: panel.visible ? 0 : -10
            Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }

        // Swallow clicks so they don't close the panel
        MouseArea { anchors.fill: parent }

        Keys.onEscapePressed: panel.visible = false
        // ↑↓ walk the same focus chain as Tab
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                var next = panel.activeFocusItem ? panel.activeFocusItem.nextItemInFocusChain(event.key === Qt.Key_Down) : null;
                if (next) next.forceActiveFocus();
                event.accepted = true;
            }
        }

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 10
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                // Only when content really overflows: the card is sized to its
                // content, so "equal" is the normal case, not a scroll case.
                visible: flick.contentHeight > flick.height + 1
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    color: parent.pressed ? Qt.lighter(Theme.accent, 1.3) : Theme.accent
                }
                background: Item {}
            }

            ColumnLayout {
                id: content
                width: parent.width
                spacing: 4

                // ── Header: title + online pill ──
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 4
                    Layout.bottomMargin: 4

                    Text {
                        text: "Network"
                        color: Theme.text
                        font.family: Theme.fontMain
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        Layout.fillWidth: true
                        renderType: Text.NativeRendering
                    }

                    Rectangle {
                        id: onlinePill
                        readonly property int c: NetworkService.connectivity
                        readonly property color tone: c === NetworkConnectivity.Full ? Theme.accent
                            : c === NetworkConnectivity.None ? Theme.error
                            : c === NetworkConnectivity.Unknown ? Theme.subtext0 : panel.warning
                        readonly property bool isPortal: c === NetworkConnectivity.Portal

                        implicitHeight: 24
                        implicitWidth: pillRow.implicitWidth + 18
                        radius: 12
                        color: Qt.rgba(tone.r, tone.g, tone.b, 0.14)
                        border.color: Qt.rgba(tone.r, tone.g, tone.b, 0.5)
                        border.width: 1

                        Row {
                            id: pillRow
                            anchors.centerIn: parent
                            spacing: 6
                            Rectangle {
                                width: 7; height: 7; radius: 3.5
                                anchors.verticalCenter: parent.verticalCenter
                                color: onlinePill.tone
                            }
                            Text {
                                text: NetworkService.onlineText + (onlinePill.isPortal ? "  ·  Sign in" : "")
                                color: onlinePill.tone
                                font.family: Theme.fontMain
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                renderType: Text.NativeRendering
                            }
                        }

                        // A captive portal can only be handled in the browser.
                        HoverHandler { cursorShape: onlinePill.isPortal ? Qt.PointingHandCursor : Qt.ArrowCursor }
                        TapHandler {
                            enabled: onlinePill.isPortal
                            onTapped: {
                                NetworkService.openLoginPage();
                                panel.visible = false;
                            }
                        }
                    }
                }

                Text {
                    visible: !NetworkService.ready
                    Layout.leftMargin: 12
                    text: "Connecting to NetworkManager…"
                    color: Theme.subtext0
                    font.family: Theme.fontMain
                    font.pixelSize: 12
                }

                // ── Ethernet ──
                Row_ {
                    id: firstFocus
                    visible: NetworkService.ethernetAvailable
                    glyph: "󰈀"
                    title: "Ethernet"
                    active: NetworkService.ethernetConnected
                    subtitle: !NetworkService.cablePlugged ? "Cable unplugged"
                        : NetworkService.ethernetBusy ? "Working…"
                        : NetworkService.ethernetConnected ? "Connected · " + NetworkService.speedText(NetworkService.linkSpeed)
                        : "Off"
                    subtitleColor: NetworkService.ethernetConnected ? Theme.accent : Theme.subtext0
                    onActivated: {
                        if (NetworkService.ethernetConnected)
                            panel.openDetails("ethernet", NetworkService.wiredDevice.name);
                        else if (NetworkService.cablePlugged)
                            NetworkService.setEthernet(true);
                    }

                    IconButton {
                        visible: NetworkService.ethernetConnected
                        glyph: "󰋼"
                        tint: panel.detailsFor === "ethernet" ? Theme.accent : Theme.text
                        onClicked: panel.openDetails("ethernet", NetworkService.wiredDevice.name)
                    }
                    Toggle {
                        checked: NetworkService.ethernetConnected
                        busy: NetworkService.ethernetBusy || !NetworkService.cablePlugged
                        onToggled: NetworkService.setEthernet(!NetworkService.ethernetConnected)
                    }
                }
                DetailsBlock { visible: panel.detailsFor === "ethernet" && NetworkService.ethernetConnected }

                Divider { visible: NetworkService.ethernetAvailable && NetworkService.wifiAvailable }

                // ── Wi-Fi ──
                Row_ {
                    visible: NetworkService.wifiAvailable
                    glyph: NetworkService.wifiEnabled ? "󰤨" : "󰤮"
                    title: "Wi-Fi"
                    active: NetworkService.activeWifi !== null
                    subtitle: !NetworkService.wifiHardwareEnabled ? "Blocked by the hardware switch"
                        : !NetworkService.wifiEnabled ? "Off"
                        : NetworkService.activeWifi ? "Connected to " + NetworkService.activeWifi.name
                        : "Not connected"
                    subtitleColor: NetworkService.activeWifi ? Theme.accent : Theme.subtext0
                    onActivated: if (NetworkService.wifiHardwareEnabled) NetworkService.setWifiEnabled(!NetworkService.wifiEnabled)

                    Toggle {
                        checked: NetworkService.wifiEnabled
                        busy: !NetworkService.wifiHardwareEnabled
                        onToggled: NetworkService.setWifiEnabled(!NetworkService.wifiEnabled)
                    }
                }

                // Network list
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    visible: NetworkService.wifiAvailable && NetworkService.wifiEnabled

                    SectionLabel { text: "NETWORKS" }

                    Text {
                        visible: NetworkService.sortedWifi.length === 0
                        Layout.leftMargin: 12
                        Layout.bottomMargin: 4
                        text: "Scanning…"
                        color: Theme.subtext0
                        font.family: Theme.fontMain
                        font.pixelSize: 12
                    }

                    Repeater {
                        model: ScriptModel { values: NetworkService.sortedWifi }

                        delegate: ColumnLayout {
                            id: netItem
                            required property var modelData
                            readonly property var net: modelData
                            readonly property bool connecting: net.state === ConnectionState.Connecting
                            readonly property bool expanded: panel.expandedNetwork === net
                            readonly property string error: panel.wifiErrors[net.name] || ""
                            Layout.fillWidth: true
                            spacing: 2

                            Row_ {
                                id: netRow
                                glyph: panel.signalGlyph(netItem.net.signalStrength)
                                title: netItem.net.name
                                active: netItem.net.connected
                                subtitle: netItem.error ? netItem.error
                                    : netItem.connecting ? "Connecting…"
                                    : netItem.net.connected ? "Connected"
                                    : netItem.net.known ? "Saved · " + panel.securityText(netItem.net)
                                    : panel.securityText(netItem.net)
                                subtitleColor: netItem.error ? Theme.error
                                    : netItem.net.connected || netItem.connecting ? Theme.accent : Theme.subtext0
                                onActivated: panel.activateNetwork(netItem.net)

                                // Action buttons: on hover or keyboard focus
                                RowLayout {
                                    spacing: 4
                                    visible: netRow.hovered || netRow.activeFocus
                                    IconButton {
                                        visible: netItem.net.connected
                                        glyph: "󰋼"
                                        tint: panel.detailsFor === "wifi" ? Theme.accent : Theme.text
                                        onClicked: panel.openDetails("wifi", NetworkService.wifiDevice.name)
                                    }
                                    IconButton {
                                        visible: netItem.net.connected
                                        glyph: "󰖪"
                                        onClicked: NetworkService.disconnectWifi(netItem.net)
                                    }
                                    IconButton {
                                        visible: netItem.net.known
                                        glyph: "󰆴"
                                        tint: Theme.error
                                        onClicked: NetworkService.forgetWifi(netItem.net)
                                    }
                                }
                                Text {
                                    visible: NetworkService.isSecured(netItem.net) && !(netRow.hovered || netRow.activeFocus)
                                    text: "󰌾"
                                    color: Theme.subtext0
                                    font.family: Theme.fontMain
                                    font.pixelSize: 12
                                }
                            }

                            DetailsBlock { visible: netItem.net.connected && panel.detailsFor === "wifi" }

                            // Inline password (also reopened after a wrong password)
                            RowLayout {
                                visible: netItem.expanded
                                Layout.fillWidth: true
                                Layout.leftMargin: 54
                                Layout.rightMargin: 10
                                Layout.bottomMargin: 6
                                spacing: 8

                                Field {
                                    id: pwField
                                    Layout.fillWidth: true
                                    placeholder: "Password"
                                    secret: true
                                    onAccepted: connectBtn.clicked()
                                    onVisibleChanged: {
                                        if (visible) { text = ""; input.forceActiveFocus(); }
                                    }
                                }
                                PillButton {
                                    id: connectBtn
                                    label: "Connect"
                                    enabled_: pwField.text.length >= 8
                                    onClicked: {
                                        if (!enabled_) return;
                                        panel.clearError(netItem.net);
                                        NetworkService.connectWithPassword(netItem.net, pwField.text);
                                        pwField.text = "";
                                        panel.expandedNetwork = null;
                                    }
                                }
                            }
                        }
                    }

                    // Join a hidden network
                    Row_ {
                        glyph: "󰐕"
                        title: "Join other network…"
                        subtitle: panel.hiddenBusy ? "Connecting…" : panel.hiddenMessage
                        subtitleColor: panel.hiddenMessage ? Theme.error : Theme.accent
                        onActivated: {
                            panel.hiddenOpen = !panel.hiddenOpen;
                            if (panel.hiddenOpen) ssidField.input.forceActiveFocus();
                        }
                    }
                    ColumnLayout {
                        visible: panel.hiddenOpen
                        Layout.fillWidth: true
                        Layout.leftMargin: 54
                        Layout.rightMargin: 10
                        Layout.bottomMargin: 6
                        spacing: 6

                        Field { id: ssidField; Layout.fillWidth: true; placeholder: "Network name (SSID)"; onAccepted: hiddenPw.input.forceActiveFocus() }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Field { id: hiddenPw; Layout.fillWidth: true; placeholder: "Password (empty if open)"; secret: true; onAccepted: joinBtn.clicked() }
                            PillButton {
                                id: joinBtn
                                label: "Join"
                                enabled_: ssidField.text.length > 0 && !panel.hiddenBusy
                                          && (hiddenPw.text.length === 0 || hiddenPw.text.length >= 8)
                                onClicked: {
                                    if (!enabled_) return;
                                    panel.hiddenBusy = true;
                                    panel.hiddenMessage = "";
                                    NetworkService.joinHidden(ssidField.text, hiddenPw.text);
                                    hiddenPw.text = "";
                                }
                            }
                        }
                    }
                }

                Divider {}

                // ── DNS (the same as CachyOS Hello's DNS page) ──
                SectionLabel { text: "DNS" }

                Row_ {
                    glyph: "󰒍"
                    title: NetworkService.dns.preset === "" ? "Automatic (router)" : NetworkService.dns.preset
                    active: NetworkService.dns.preset !== ""
                    subtitle: NetworkService.dnsBusy ? "Applying…"
                        : !NetworkService.dns.conn ? "No active connection"
                        : (NetworkService.dns.preset === "" ? "From the router"
                           : NetworkService.dns.dot ? "Encrypted · DNS over TLS" : "Not encrypted")
                          + " · " + NetworkService.dns.conn
                    subtitleColor: NetworkService.dns.preset !== "" && NetworkService.dns.dot ? Theme.accent : Theme.subtext0
                    onActivated: {
                        panel.dnsOpen = !panel.dnsOpen;
                        if (panel.dnsOpen) panel.dnsUseDot = NetworkService.dns.preset === "" ? true : NetworkService.dns.dot;
                    }

                    Text {
                        text: panel.dnsOpen ? "󰅀" : "󰅂"
                        color: Theme.subtext0
                        font.family: Theme.fontMain
                        font.pixelSize: 14
                    }
                }

                ColumnLayout {
                    visible: panel.dnsOpen && NetworkService.dns.conn !== ""
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    Layout.rightMargin: 8
                    Layout.bottomMargin: 6
                    spacing: 2

                    // Encryption switch. Changing it re-applies the current
                    // provider right away, like picking it again in Hello.
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 4
                        spacing: 10
                        Text {
                            text: "Encrypted (DNS over TLS)"
                            color: Theme.text
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            Layout.fillWidth: true
                            renderType: Text.NativeRendering
                        }
                        Toggle {
                            checked: panel.dnsUseDot
                            busy: NetworkService.dnsBusy
                            onToggled: {
                                panel.dnsUseDot = !panel.dnsUseDot;
                                var cur = NetworkService.dnsPresets.find(p => p.name === NetworkService.dns.preset);
                                if (cur) NetworkService.setDns(cur, panel.dnsUseDot);
                            }
                        }
                    }

                    Repeater {
                        // "Automatic" first, then Hello's list in Hello's order
                        model: [{ name: "", label: "Automatic (router)" }].concat(
                                   NetworkService.dnsPresets.map(p => ({ name: p.name, label: p.name, dot: p.dot })))

                        delegate: Rectangle {
                            id: dnsItem
                            required property var modelData
                            readonly property bool current: NetworkService.dns.preset === modelData.name
                            Layout.fillWidth: true
                            implicitHeight: 30
                            radius: 8
                            activeFocusOnTab: true
                            color: current ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
                                 : dnsHover.hovered || activeFocus ? Theme.hoverBg : "transparent"
                            border.color: current ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.45) : "transparent"
                            border.width: 1

                            function pick() {
                                if (NetworkService.dnsBusy || current) return;
                                if (modelData.name === "") NetworkService.resetDns();
                                else NetworkService.setDns(NetworkService.dnsPresets.find(p => p.name === modelData.name),
                                                           panel.dnsUseDot);
                            }
                            Keys.onReturnPressed: pick()
                            Keys.onSpacePressed: pick()

                            RowLayout {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                spacing: 8
                                Text {
                                    text: dnsItem.modelData.label
                                    color: dnsItem.current ? Theme.accent : Theme.text
                                    font.family: Theme.fontMain
                                    font.pixelSize: 12
                                    font.weight: dnsItem.current ? Font.Bold : Font.Normal
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    renderType: Text.NativeRendering
                                }
                                // Hello offers these two as plain DNS only
                                Text {
                                    visible: dnsItem.modelData.name !== "" && !dnsItem.modelData.dot
                                    text: "no encryption"
                                    color: Theme.subtext0
                                    font.family: Theme.fontMain
                                    font.pixelSize: 10
                                }
                                Text {
                                    visible: dnsItem.current
                                    text: "󰄬"
                                    color: Theme.accent
                                    font.family: Theme.fontMain
                                    font.pixelSize: 13
                                }
                            }
                            HoverHandler { id: dnsHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: dnsItem.pick() }
                        }
                    }
                }

                Divider {}

                // ── VPN ──
                SectionLabel { text: "VPN" }

                Repeater {
                    model: NetworkService.vpns

                    delegate: Row_ {
                        id: vpnRow
                        required property var modelData
                        glyph: "󰦝"
                        title: modelData.name
                        active: modelData.active
                        subtitle: panel.vpnBusy === modelData.name ? "Working…"
                            : (modelData.type === "wireguard" ? "WireGuard" : "VPN") + (modelData.active ? " · Connected" : "")
                        subtitleColor: modelData.active ? Theme.accent : Theme.subtext0
                        onActivated: vpnToggle.toggled()

                        Toggle {
                            id: vpnToggle
                            checked: vpnRow.modelData.active
                            busy: panel.vpnBusy !== ""
                            onToggled: {
                                panel.vpnBusy = vpnRow.modelData.name;
                                NetworkService.setVpn(vpnRow.modelData, !vpnRow.modelData.active);
                            }
                        }
                    }
                }

                Row_ {
                    glyph: "󰁯"
                    title: "Import WireGuard…"
                    subtitle: panel.importMessage || (NetworkService.vpns.length === 0 ? "No VPNs yet" : "")
                    subtitleColor: panel.importMessage && panel.importMessage !== "Imported" ? Theme.error : Theme.subtext0
                    onActivated: {
                        panel.importOpen = !panel.importOpen;
                        if (panel.importOpen) NetworkService.findWireguardFiles();
                    }
                }
                ColumnLayout {
                    visible: panel.importOpen
                    Layout.fillWidth: true
                    Layout.leftMargin: 54
                    Layout.rightMargin: 10
                    Layout.bottomMargin: 6
                    spacing: 4

                    Text {
                        text: NetworkService.wireguardFiles.length ? "Found in ~/Downloads:" : "No WireGuard .conf files in ~/Downloads."
                        color: Theme.subtext0
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                    }
                    Repeater {
                        model: NetworkService.wireguardFiles
                        delegate: Rectangle {
                            id: fileRow
                            required property string modelData
                            Layout.fillWidth: true
                            implicitHeight: 30
                            radius: 8
                            activeFocusOnTab: true
                            color: fileHover.hovered || activeFocus ? Theme.hoverBg : Qt.rgba(1, 1, 1, 0.04)
                            Keys.onReturnPressed: NetworkService.importWireguard(modelData)
                            Text {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                verticalAlignment: Text.AlignVCenter
                                text: "󰈮  " + fileRow.modelData.replace(/^.*\//, "")
                                color: Theme.text
                                font.family: Theme.fontMain
                                font.pixelSize: 12
                                elide: Text.ElideMiddle
                            }
                            HoverHandler { id: fileHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: NetworkService.importWireguard(fileRow.modelData) }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        spacing: 8
                        Field { id: pathField; Layout.fillWidth: true; placeholder: "…or a path to a .conf file"; onAccepted: importBtn.clicked() }
                        PillButton {
                            id: importBtn
                            label: "Import"
                            enabled_: pathField.text.trim().length > 0
                            onClicked: {
                                if (!enabled_) return;
                                NetworkService.importWireguard(pathField.text.trim().replace(/^~/, Quickshell.env("HOME")));
                            }
                        }
                    }
                }
            }
        }
    }
}
