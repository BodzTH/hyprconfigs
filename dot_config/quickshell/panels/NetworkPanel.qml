import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "../services"

PanelWindow {
    id: networkPanel
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
        onClicked: networkPanel.visible = false
    }

    // ── Tab state ────────────────────────────────────────────────────────────
    property int currentTab: 0  // 0=Status, 1=WiFi, 2=Saved

    // ── WiFi scan state ──────────────────────────────────────────────────────
    property var networks: []
    property bool scanning: false
    property string connectingSsid: ""

    // ── Password / hidden network overlay ────────────────────────────────────
    property bool showPasswordPrompt: false
    property bool showHiddenPrompt: false
    property string pendingSsid: ""
    property string pendingPassword: ""
    property string hiddenSsid: ""
    property string hiddenPassword: ""
    property bool showPassword: false

    // ── Saved connections ────────────────────────────────────────────────────
    property var savedConnections: []
    property string confirmDeleteName: ""
    property string confirmDeleteUuid: ""

    // ── Overlay active? ──────────────────────────────────────────────────────
    readonly property bool overlayActive: showPasswordPrompt || showHiddenPrompt

    // ── Processes ────────────────────────────────────────────────────────────

    property Process scanProc: Process {
        running: false
        command: ["sh", "-c",
            "nmcli -t -f ssid,signal,security,active dev wifi list 2>/dev/null | sort -t: -k2 -rn"]
        stdout: StdioCollector {
            onStreamFinished: {
                var result = [];
                var lines = this.text.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i];
                    if (!line) continue;
                    // split on unescaped colons
                    var parts = line.split(/(?<!\\):/);
                    if (parts.length < 4) continue;
                    var ssid = parts[0].replace(/\\:/g, ":").trim();
                    if (!ssid || ssid === "--") continue;
                    var signal = parseInt(parts[1]) || 0;
                    var security = parts[2].trim();
                    var active = parts[3].trim() === "yes";
                    var found = false;
                    for (var j = 0; j < result.length; j++) {
                        if (result[j].ssid === ssid) {
                            if (signal > result[j].signal) result[j].signal = signal;
                            if (active) result[j].connected = true;
                            found = true; break;
                        }
                    }
                    if (!found)
                        result.push({ ssid: ssid, signal: signal, security: security, connected: active });
                }
                networkPanel.networks = result;
                networkPanel.scanning = false;
            }
        }
    }

    property Process connectProc: Process {
        running: false
        onRunningChanged: {
            if (!running) {
                networkPanel.connectingSsid = "";
                networkPanel.scan();
                NetworkService.ethernetProc.running = true;
            }
        }
    }

    property Process disconnectProc: Process {
        running: false
        command: ["sh", "-c",
            "nmcli dev disconnect $(nmcli -t -f device,state dev | grep ':connected' | grep -v loopback | head -1 | cut -d: -f1)"]
        onRunningChanged: {
            if (!running) {
                networkPanel.scan();
                NetworkService.ethernetProc.running = true;
            }
        }
    }

    property Process conUpProc: Process {
        running: false
        onRunningChanged: { if (!running) networkPanel.loadSaved() }
    }

    property Process conDownProc: Process {
        running: false
        onRunningChanged: { if (!running) networkPanel.loadSaved() }
    }

    property Process deleteProc: Process {
        running: false
        onRunningChanged: { if (!running) networkPanel.loadSaved() }
    }

    property Process forgetWifiProc: Process {
        running: false
        onRunningChanged: { if (!running) networkPanel.scan() }
    }

    Connections {
        target: NetworkService
        function onSavedConnectionsReady(raw) {
            var result = [];
            var lines = raw.split("\n");
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim();
                if (!line) continue;
                // format: name:type:active:uuid  (name may contain colons)
                // uuid is always last 36 chars with known format
                var uuidMatch = line.match(/:([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/);
                if (!uuidMatch) continue;
                var uuid = uuidMatch[1];
                var rest = line.slice(0, line.length - uuid.length - 1); // strip :uuid
                var lastColon = rest.lastIndexOf(":");
                var active = rest.slice(lastColon + 1) === "yes";
                rest = rest.slice(0, lastColon);
                var secondLastColon = rest.lastIndexOf(":");
                var type = rest.slice(secondLastColon + 1);
                var name = rest.slice(0, secondLastColon);
                if (type === "loopback") continue;
                var label = type;
                if (type === "802-3-ethernet") label = "ethernet";
                else if (type === "802-11-wireless") label = "wifi";
                result.push({ name: name, type: label, active: active, uuid: uuid });
            }
            networkPanel.savedConnections = result;
        }
    }

    // ── Actions ───────────────────────────────────────────────────────────────

    function scan() {
        scanning = true;
        scanProc.running = true;
    }

    function loadSaved() {
        confirmDeleteName = "";
        confirmDeleteUuid = "";
        NetworkService.fetchSavedConnections();
    }

    function connectToNetwork(ssid, password) {
        connectingSsid = ssid;
        if (password)
            connectProc.command = ["nmcli", "dev", "wifi", "connect", ssid, "password", password];
        else
            connectProc.command = ["nmcli", "dev", "wifi", "connect", ssid];
        connectProc.running = true;
    }

    function connectToHidden(ssid, password) {
        connectingSsid = ssid;
        if (password)
            connectProc.command = ["nmcli", "dev", "wifi", "connect", ssid, "password", password, "hidden", "yes"];
        else
            connectProc.command = ["nmcli", "dev", "wifi", "connect", ssid, "hidden", "yes"];
        connectProc.running = true;
    }

    function tryConnect(ssid, security, connected) {
        if (connected) { disconnectProc.running = true; return; }
        if (security && security !== "--") {
            pendingSsid = ssid;
            pendingPassword = "";
            showPassword = false;
            showPasswordPrompt = true;
        } else {
            connectToNetwork(ssid, "");
        }
    }

    function forgetWifi(ssid) {
        forgetWifiProc.command = ["sh", "-c", "nmcli connection delete \"" + ssid + "\" 2>/dev/null || true"];
        forgetWifiProc.running = true;
    }

    function activateConnection(name) {
        conUpProc.command = ["nmcli", "con", "up", name];
        conUpProc.running = true;
    }

    function deactivateConnection(name) {
        conDownProc.command = ["nmcli", "con", "down", name];
        conDownProc.running = true;
    }

    function deleteConnection(uuid) {
        deleteProc.command = ["nmcli", "con", "delete", uuid];
        deleteProc.running = true;
    }

    // Called from overlay buttons — defined at popup root level so all children can reach it
    function confirmConnect() {
        if (showHiddenPrompt) {
            showHiddenPrompt = false;
            connectToHidden(hiddenSsid, hiddenPassword);
        } else {
            showPasswordPrompt = false;
            connectToNetwork(pendingSsid, pendingPassword);
        }
    }

    function cancelOverlay() {
        showPasswordPrompt = false;
        showHiddenPrompt = false;
        pendingPassword = "";
        hiddenSsid = "";
        hiddenPassword = "";
    }

    function signalIcon(sig) {
        if (sig >= 75) return "󰤨";
        if (sig >= 50) return "󰤥";
        if (sig >= 25) return "󰤢";
        return "󰤟";
    }

    function typeIcon(type) {
        if (type === "ethernet") return "󰈀";
        if (type === "wifi") return "󰖩";
        if (type === "vpn" || type === "wireguard") return "󰌾";
        return "󰛳";
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    onVisibleChanged: {
        if (visible) {
            currentTab = 0;
            cancelOverlay();
            confirmDeleteName = "";
            confirmDeleteUuid = "";
            NetworkService.updateAll();
            scan();
            loadSaved();
        }
    }

    // Fetch connection details once activeConnectionName is known
    Connections {
        target: NetworkService
        function onActiveConnectionNameChanged() {
            if (networkPanel.visible && NetworkService.activeConnectionName)
                NetworkService.fetchConnectionDetails(NetworkService.activeConnectionName);
        }
    }

    // ── Root container ────────────────────────────────────────────────────────

    Rectangle {
        id: rootRect
        anchors { top: parent.top; right: parent.right }
        anchors.topMargin: 52
        anchors.rightMargin: 16
        width: 320
        height: Math.min(520, mainColumn.implicitHeight + 32)
        color: Theme.glassBg
        border.color: Theme.glassBorder
        border.width: 1
        radius: 19
        antialiasing: true
        clip: true

        // Block background click propagation
        MouseArea { anchors.fill: parent; onClicked: {} }

        // ── Main content (always present, behind overlay) ─────────────────────
        ColumnLayout {
            id: mainColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 12

            // ── Header ───────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: NetworkService.vpnActive ? "󰌾"
                        : NetworkService.type === "ethernet" ? "󰈀"
                        : NetworkService.wifiEnabled ? "󰖩" : "󰖪"
                    color: NetworkService.vpnActive ? Theme.success
                        : NetworkService.type !== "none" ? Theme.accent : Theme.subtext0
                    font.family: Theme.fontMain
                    font.pixelSize: 18
                    renderType: Text.NativeRendering
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Text {
                    text: NetworkService.vpnActive
                            ? "VPN · " + (NetworkService.type === "ethernet" ? "Ethernet"
                                : NetworkService.ssid || "WiFi")
                        : NetworkService.type === "ethernet" ? "Ethernet"
                        : NetworkService.type === "wifi" ? (NetworkService.ssid || "Connected")
                        : "Disconnected"
                    color: NetworkService.vpnActive ? Theme.success
                        : NetworkService.type !== "none" ? Theme.text : Theme.subtext0
                    font.family: Theme.fontMain
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    renderType: Text.NativeRendering
                }

                Item { Layout.fillWidth: true }

                // Wired quick toggle
                RowLayout {
                    spacing: 6
                    visible: NetworkService.ethernetAvailable

                    Text {
                        text: "Wired"
                        color: Theme.subtext0
                        font.family: Theme.fontMain
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        renderType: Text.NativeRendering
                    }

                    Rectangle {
                        width: 34; height: 18; radius: 9
                        color: NetworkService.ethernetConnected
                            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
                            : Theme.bgSelection
                        border.color: NetworkService.ethernetConnected
                            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5)
                            : Theme.borderBase
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 180 } }
                        Behavior on border.color { ColorAnimation { duration: 180 } }

                        Rectangle {
                            width: 12; height: 12; radius: 6
                            color: NetworkService.ethernetConnected ? Theme.accent : Theme.subtext0
                            anchors.verticalCenter: parent.verticalCenter
                            x: NetworkService.ethernetConnected ? parent.width - width - 3 : 3
                            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }

                        TapHandler { onTapped: NetworkService.toggleEthernet() }
                    }
                }

                // WiFi toggle
                RowLayout {
                    spacing: 6

                    Text {
                        text: "Wi-Fi"
                        color: Theme.subtext0
                        font.family: Theme.fontMain
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        renderType: Text.NativeRendering
                    }

                    Rectangle {
                        width: 34; height: 18; radius: 9
                        color: NetworkService.wifiEnabled
                            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
                            : Theme.bgSelection
                        border.color: NetworkService.wifiEnabled
                            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5)
                            : Theme.borderBase
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 180 } }
                        Behavior on border.color { ColorAnimation { duration: 180 } }

                        Rectangle {
                            width: 12; height: 12; radius: 6
                            color: NetworkService.wifiEnabled ? Theme.accent : Theme.subtext0
                            anchors.verticalCenter: parent.verticalCenter
                            x: NetworkService.wifiEnabled ? parent.width - width - 3 : 3
                            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }

                        TapHandler { onTapped: NetworkService.toggleWifi() }
                    }
                }
            }

            // ── Tab bar ───────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 28
                radius: 10
                color: Theme.bgSelection

                Row {
                    anchors.fill: parent
                    anchors.margins: 2
                    spacing: 2

                    Repeater {
                        model: ["Status", "Wi-Fi", "Saved"]
                        Rectangle {
                            width: (parent.width - 8) / 3
                            height: parent.height
                            radius: 8
                            color: networkPanel.currentTab === index
                                ? Qt.rgba(1, 1, 1, 0.12)
                                : (tabHover.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: networkPanel.currentTab === index ? Theme.text : Theme.subtext0
                                font.family: Theme.fontMain
                                font.pixelSize: 10
                                font.weight: networkPanel.currentTab === index ? Font.Bold : Font.Normal
                                renderType: Text.NativeRendering
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            HoverHandler { id: tabHover }
                            TapHandler {
                                onTapped: {
                                    networkPanel.currentTab = index;
                                    if (index === 1 && networkPanel.networks.length === 0)
                                        networkPanel.scan();
                                    if (index === 2)
                                        networkPanel.loadSaved();
                                }
                            }
                        }
                    }
                }
            }

            // ── Divider ───────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; height: 1
                color: Theme.borderBase; opacity: 0.4
            }

            // ══════════════════════════════════════════════════════════════════
            // TAB 0 — STATUS
            // ══════════════════════════════════════════════════════════════════
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: networkPanel.currentTab === 0

                // Disconnected
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: NetworkService.type === "none"

                    Rectangle {
                        Layout.fillWidth: true; height: 44; radius: 6
                        color: Theme.bgSelection
                        Text {
                            anchors.centerIn: parent
                            text: "No network connection"
                            color: Theme.subtext0; font.family: Theme.fontMain; font.pixelSize: 10
                            renderType: Text.NativeRendering
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true; spacing: 6

                        ActionButton {
                            Layout.fillWidth: true
                            label: "Connect Wired"
                            visible: NetworkService.ethernetAvailable
                            onActivated: NetworkService.connectEthernet()
                        }

                        ActionButton {
                            Layout.fillWidth: true
                            label: "Manage (nmtui)"
                            onActivated: NetworkService.openManager()
                        }
                    }
                }

                // Connected details
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: NetworkService.type !== "none"

                    // Connection name banner
                    Rectangle {
                        Layout.fillWidth: true; height: 36; radius: 6
                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
                        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12; anchors.rightMargin: 12

                            Text {
                                text: networkPanel.typeIcon(NetworkService.type)
                                color: Theme.accent
                                font.family: Theme.fontMain; font.pixelSize: 14
                                renderType: Text.NativeRendering
                            }
                            Text {
                                Layout.fillWidth: true
                                text: NetworkService.activeConnectionName
                                    || (NetworkService.type === "ethernet" ? "Wired Connection"
                                        : NetworkService.ssid || "WiFi")
                                color: Theme.text
                                font.family: Theme.fontMain; font.pixelSize: 10
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                            }
                            Rectangle {
                                visible: NetworkService.vpnActive
                                width: vpnLabel.implicitWidth + 8; height: 16; radius: 8
                                color: Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.2)
                                border.color: Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.4)
                                border.width: 1
                                Text {
                                    id: vpnLabel
                                    anchors.centerIn: parent
                                    text: "VPN"; color: Theme.success
                                    font.family: Theme.fontMain; font.pixelSize: 8; font.weight: Font.Bold
                                    renderType: Text.NativeRendering
                                }
                            }
                        }
                    }

                    // IP Address row — direct binding, no Repeater/model snapshot bug
                    DetailRow { label: "IP Address"; value: NetworkService.ipAddress; icon: "󰩠" }
                    DetailRow { label: "Gateway";    value: NetworkService.gateway;   icon: "󰛳" }
                    DetailRow { label: "DNS";        value: NetworkService.dnsServers; icon: "󰿔" }
                    DetailRow { label: "IPv6";       value: NetworkService.ipv6Address; icon: "󰩠" }

                    // WiFi signal bar
                    Rectangle {
                        Layout.fillWidth: true; height: 30; radius: 5
                        color: "transparent"
                        visible: NetworkService.type === "wifi"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10; anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                text: "󰤨"; color: Theme.subtext0
                                font.family: Theme.fontMain; font.pixelSize: 12
                                renderType: Text.NativeRendering
                            }
                            Text {
                                text: "Signal"; color: Theme.subtext0
                                font.family: Theme.fontMain; font.pixelSize: 9; font.weight: Font.Bold
                                renderType: Text.NativeRendering
                            }
                            Item { Layout.fillWidth: true }

                            Row {
                                spacing: 2
                                Repeater {
                                    model: 4
                                    Rectangle {
                                        width: 6; height: 6 + index * 3; radius: 1
                                        anchors.bottom: parent ? parent.bottom : undefined
                                        color: (NetworkService.signal >= (index + 1) * 25)
                                            ? Theme.accent : Theme.bgSelection
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                }
                            }
                            Text {
                                text: NetworkService.signal + "%"; color: Theme.text
                                font.family: Theme.fontMain; font.pixelSize: 9
                                renderType: Text.NativeRendering
                            }
                        }
                    }
                }

                // Action buttons
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    visible: NetworkService.type !== "none"

                    ActionButton {
                        Layout.fillWidth: true
                        label: "Disconnect"
                        isDangerous: true
                        onActivated: {
                            if (NetworkService.type === "ethernet") {
                                NetworkService.disconnectEthernet();
                            } else {
                                networkPanel.disconnectProc.running = true;
                            }
                        }
                    }
                    ActionButton {
                        Layout.fillWidth: true
                        label: "Manage…"
                        onActivated: NetworkService.openManager()
                    }
                }
            }

            // ══════════════════════════════════════════════════════════════════
            // TAB 1 — WI-FI
            // ══════════════════════════════════════════════════════════════════
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: networkPanel.currentTab === 1

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Available Networks"
                        color: Theme.subtext0; font.family: Theme.fontMain
                        font.pixelSize: 9; font.weight: Font.Bold
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 0.8
                        renderType: Text.NativeRendering
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: 22; height: 22; radius: 5
                        color: scanBtnHover.hovered ? Theme.hoverBg : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            anchors.centerIn: parent; text: "󰑐"
                            color: networkPanel.scanning ? Theme.accent : Theme.subtext0
                            font.family: Theme.fontMain; font.pixelSize: 13
                            renderType: Text.NativeRendering
                            RotationAnimator on rotation {
                                running: networkPanel.scanning
                                from: 0; to: 360; duration: 1000; loops: Animation.Infinite
                            }
                        }
                        HoverHandler { id: scanBtnHover }
                        TapHandler { onTapped: { if (!networkPanel.scanning) networkPanel.scan() } }
                    }
                }

                // WiFi disabled notice
                Rectangle {
                    Layout.fillWidth: true; height: 40; radius: 5; color: Theme.bgSelection
                    visible: !NetworkService.wifiEnabled
                    Text {
                        anchors.centerIn: parent; text: "Wi-Fi is disabled"
                        color: Theme.subtext0; font.family: Theme.fontMain; font.pixelSize: 10
                        renderType: Text.NativeRendering
                    }
                }

                // Network list
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 3
                    visible: NetworkService.wifiEnabled

                    Text {
                        Layout.fillWidth: true; text: "Scanning…"
                        color: Theme.subtext0; font.family: Theme.fontMain; font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        visible: networkPanel.scanning && networkPanel.networks.length === 0
                        renderType: Text.NativeRendering
                    }
                    Text {
                        Layout.fillWidth: true; text: "No networks found"
                        color: Theme.subtext0; font.family: Theme.fontMain; font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        visible: !networkPanel.scanning && networkPanel.networks.length === 0
                        renderType: Text.NativeRendering
                    }

                    Repeater {
                        model: networkPanel.networks

                        delegate: Rectangle {
                            id: wifiRow
                            Layout.fillWidth: true; height: 38; radius: 5

                            readonly property bool isConnected: modelData.connected
                            readonly property bool isConnecting: networkPanel.connectingSsid === modelData.ssid

                            color: isConnected
                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, wifiRowHover.hovered ? 0.18 : 0.10)
                                : (wifiRowHover.hovered ? Theme.hoverBg : "transparent")
                            border.color: isConnected
                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3) : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10; anchors.rightMargin: 6
                                spacing: 8

                                Text {
                                    text: networkPanel.signalIcon(modelData.signal)
                                    color: wifiRow.isConnected ? Theme.accent : Theme.subtext0
                                    font.family: Theme.fontMain; font.pixelSize: 13
                                    renderType: Text.NativeRendering
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 1
                                    Text {
                                        text: modelData.ssid; color: Theme.text
                                        font.family: Theme.fontMain; font.pixelSize: 10
                                        font.weight: wifiRow.isConnected ? Font.Bold : Font.Normal
                                        elide: Text.ElideRight; Layout.maximumWidth: 150
                                        renderType: Text.NativeRendering
                                    }
                                    Text {
                                        text: wifiRow.isConnected ? "Connected"
                                            : (modelData.security && modelData.security !== "--")
                                                ? "󰌾 " + modelData.security : "Open"
                                        color: wifiRow.isConnected ? Theme.accent : Theme.subtext0
                                        font.family: Theme.fontMain; font.pixelSize: 8
                                        renderType: Text.NativeRendering
                                    }
                                }

                                Text {
                                    text: modelData.signal + "%"; color: Theme.subtext0
                                    font.family: Theme.fontMain; font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                }

                                // Spinner while connecting
                                Text {
                                    visible: wifiRow.isConnecting; text: "󰑐"; color: Theme.accent
                                    font.family: Theme.fontMain; font.pixelSize: 13
                                    renderType: Text.NativeRendering
                                    RotationAnimator on rotation {
                                        running: wifiRow.isConnecting
                                        from: 0; to: 360; duration: 900; loops: Animation.Infinite
                                    }
                                }

                                // Forget (on non-connected rows, reveal on hover)
                                Rectangle {
                                    visible: !wifiRow.isConnecting && !wifiRow.isConnected
                                    width: 24; height: 24; radius: 4
                                    opacity: wifiRowHover.hovered ? 1.0 : 0.0
                                    color: forgetHover.hovered
                                        ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.2) : "transparent"
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Text {
                                        anchors.centerIn: parent; text: "󰆴"
                                        color: forgetHover.hovered ? Theme.error : Theme.subtext0
                                        font.family: Theme.fontMain; font.pixelSize: 11
                                        renderType: Text.NativeRendering
                                    }
                                    HoverHandler { id: forgetHover }
                                    TapHandler { onTapped: networkPanel.forgetWifi(modelData.ssid) }
                                }

                                // Disconnect (on connected row)
                                Rectangle {
                                    visible: !wifiRow.isConnecting && wifiRow.isConnected
                                    width: 24; height: 24; radius: 4
                                    color: discRowHover.hovered
                                        ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.2) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Text {
                                        anchors.centerIn: parent; text: "󰖪"
                                        color: discRowHover.hovered ? Theme.error : Theme.subtext0
                                        font.family: Theme.fontMain; font.pixelSize: 12
                                        renderType: Text.NativeRendering
                                    }
                                    HoverHandler { id: discRowHover }
                                    TapHandler { onTapped: networkPanel.disconnectProc.running = true }
                                }
                            }

                            HoverHandler { id: wifiRowHover }
                            TapHandler {
                                onTapped: {
                                    if (!wifiRow.isConnected && !wifiRow.isConnecting)
                                        networkPanel.tryConnect(modelData.ssid, modelData.security, modelData.connected)
                                }
                            }
                        }
                    }
                }

                // Hidden network
                Rectangle {
                    Layout.fillWidth: true; height: 28; radius: 5
                    color: hiddenBtnHover.hovered ? Theme.hoverBg : "transparent"
                    visible: NetworkService.wifiEnabled
                    Behavior on color { ColorAnimation { duration: 100 } }

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; spacing: 6
                        Text { text: "󰛴"; color: Theme.subtext0; font.family: Theme.fontMain; font.pixelSize: 12; renderType: Text.NativeRendering }
                        Text { text: "Connect to hidden network…"; color: Theme.subtext0; font.family: Theme.fontMain; font.pixelSize: 9; renderType: Text.NativeRendering }
                    }
                    HoverHandler { id: hiddenBtnHover }
                    TapHandler {
                        onTapped: {
                            networkPanel.hiddenSsid = "";
                            networkPanel.hiddenPassword = "";
                            networkPanel.showPassword = false;
                            networkPanel.showHiddenPrompt = true;
                        }
                    }
                }
            }

            // ══════════════════════════════════════════════════════════════════
            // TAB 2 — SAVED CONNECTIONS
            // ══════════════════════════════════════════════════════════════════
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                visible: networkPanel.currentTab === 2

                Text {
                    text: "Saved Connections"
                    color: Theme.subtext0; font.family: Theme.fontMain
                    font.pixelSize: 9; font.weight: Font.Bold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.8
                    renderType: Text.NativeRendering
                }

                Text {
                    text: "No saved connections"
                    color: Theme.subtext0; font.family: Theme.fontMain; font.pixelSize: 10
                    visible: networkPanel.savedConnections.length === 0
                    renderType: Text.NativeRendering
                }

                Repeater {
                    model: networkPanel.savedConnections

                    delegate: ColumnLayout {
                        Layout.fillWidth: true; spacing: 2

                        Rectangle {
                            id: savedRow
                            Layout.fillWidth: true; height: 38; radius: 5
                            readonly property bool isActive: modelData.active
                            color: isActive
                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, savedRowHover.hovered ? 0.18 : 0.10)
                                : (savedRowHover.hovered ? Theme.hoverBg : "transparent")
                            border.color: isActive
                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3) : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10; anchors.rightMargin: 6
                                spacing: 8

                                Text {
                                    text: networkPanel.typeIcon(modelData.type)
                                    color: savedRow.isActive ? Theme.accent : Theme.subtext0
                                    font.family: Theme.fontMain; font.pixelSize: 13
                                    renderType: Text.NativeRendering
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 1
                                    Text {
                                        text: modelData.name; color: Theme.text
                                        font.family: Theme.fontMain; font.pixelSize: 10
                                        font.weight: savedRow.isActive ? Font.Bold : Font.Normal
                                        elide: Text.ElideRight; Layout.maximumWidth: 150
                                        renderType: Text.NativeRendering
                                    }
                                    Text {
                                        text: savedRow.isActive ? "Connected" : modelData.type
                                        color: savedRow.isActive ? Theme.accent : Theme.subtext0
                                        font.family: Theme.fontMain; font.pixelSize: 8
                                        renderType: Text.NativeRendering
                                    }
                                }

                                // Connect / Disconnect button
                                Rectangle {
                                    visible: savedRowHover.hovered
                                    width: 24; height: 24; radius: 4
                                    color: conBtnHover.hovered
                                        ? (savedRow.isActive
                                            ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.2)
                                            : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2))
                                        : "transparent"
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: savedRow.isActive ? "󰖪" : "󰖩"
                                        color: savedRow.isActive ? Theme.error : Theme.accent
                                        font.family: Theme.fontMain; font.pixelSize: 12
                                        renderType: Text.NativeRendering
                                    }
                                    HoverHandler { id: conBtnHover }
                                    TapHandler {
                                        onTapped: savedRow.isActive
                                            ? networkPanel.deactivateConnection(modelData.name)
                                            : networkPanel.activateConnection(modelData.name)
                                    }
                                }

                                // Delete button
                                Rectangle {
                                    visible: savedRowHover.hovered && !savedRow.isActive
                                    width: 24; height: 24; radius: 4
                                    color: delBtnHover.hovered
                                        ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.2) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Text {
                                        anchors.centerIn: parent; text: "󰆴"
                                        color: delBtnHover.hovered ? Theme.error : Theme.subtext0
                                        font.family: Theme.fontMain; font.pixelSize: 12
                                        renderType: Text.NativeRendering
                                    }
                                    HoverHandler { id: delBtnHover }
                                    TapHandler {
                                        onTapped: {
                                            networkPanel.confirmDeleteName = modelData.name;
                                            networkPanel.confirmDeleteUuid = modelData.uuid;
                                        }
                                    }
                                }
                            }

                            HoverHandler { id: savedRowHover }
                        }

                        // Delete confirmation inline
                        Rectangle {
                            Layout.fillWidth: true; height: 34; radius: 5
                            visible: networkPanel.confirmDeleteName === modelData.name
                            color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.08)
                            border.color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.25)
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 6; spacing: 8
                                Text {
                                    Layout.fillWidth: true
                                    text: "Delete \"" + modelData.name + "\"?"
                                    color: Theme.error; font.family: Theme.fontMain; font.pixelSize: 9
                                    elide: Text.ElideRight; renderType: Text.NativeRendering
                                }
                                Rectangle {
                                    width: 50; height: 22; radius: 4
                                    color: cancelDelHover.hovered ? Theme.borderBase : Theme.bgSelection
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Text {
                                        anchors.centerIn: parent; text: "Cancel"
                                        color: Theme.subtext0; font.family: Theme.fontMain
                                        font.pixelSize: 8; font.weight: Font.Bold; renderType: Text.NativeRendering
                                    }
                                    HoverHandler { id: cancelDelHover }
                                    TapHandler {
                                        onTapped: {
                                            networkPanel.confirmDeleteName = "";
                                            networkPanel.confirmDeleteUuid = "";
                                        }
                                    }
                                }
                                Rectangle {
                                    width: 50; height: 22; radius: 4
                                    color: confirmDelHover.hovered
                                        ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.3)
                                        : Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.18)
                                    border.color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.4)
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Text {
                                        anchors.centerIn: parent; text: "Delete"
                                        color: Theme.error; font.family: Theme.fontMain
                                        font.pixelSize: 8; font.weight: Font.Bold; renderType: Text.NativeRendering
                                    }
                                    HoverHandler { id: confirmDelHover }
                                    TapHandler { onTapped: networkPanel.deleteConnection(modelData.uuid) }
                                }
                            }
                        }
                    }
                }

                // Edit all connections
                Rectangle {
                    Layout.fillWidth: true; height: 28; radius: 5
                    color: editAllHover.hovered ? Theme.hoverBg : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; spacing: 6
                        Text { text: "󰏫"; color: Theme.subtext0; font.family: Theme.fontMain; font.pixelSize: 12; renderType: Text.NativeRendering }
                        Text { text: "Edit connections (nmtui)…"; color: Theme.subtext0; font.family: Theme.fontMain; font.pixelSize: 9; renderType: Text.NativeRendering }
                    }
                    HoverHandler { id: editAllHover }
                    TapHandler { onTapped: NetworkService.openManager() }
                }
            }

            Item { height: 2 }
        }

        // ── Password / Hidden network overlay (on top, z:10) ──────────────────
        Rectangle {
            anchors.fill: parent
            radius: Theme.widgetRadius
            antialiasing: true
            color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.97)
            visible: networkPanel.overlayActive
            z: 10

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 40
                spacing: 14

                Text {
                    Layout.fillWidth: true
                    text: networkPanel.showHiddenPrompt ? "Connect to hidden network" : "Connect to"
                    color: Theme.subtext0; font.family: Theme.fontMain; font.pixelSize: 10
                    horizontalAlignment: Text.AlignHCenter; renderType: Text.NativeRendering
                }
                Text {
                    Layout.fillWidth: true
                    text: networkPanel.pendingSsid
                    color: Theme.text; font.family: Theme.fontMain
                    font.pixelSize: 13; font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                    visible: !networkPanel.showHiddenPrompt; renderType: Text.NativeRendering
                }

                // SSID field (hidden network only)
                Rectangle {
                    Layout.fillWidth: true; height: 32; radius: 5
                    color: Theme.bgSelection
                    border.color: hiddenSsidField.activeFocus ? Theme.accent : Theme.borderBase
                    border.width: 1
                    visible: networkPanel.showHiddenPrompt
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 6
                        Text { text: "󰖩"; color: Theme.subtext0; font.family: Theme.fontMain; font.pixelSize: 13 }
                        Item {
                            Layout.fillWidth: true; height: parent.height
                            TextInput {
                                id: hiddenSsidField
                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.text; font.family: Theme.fontMain; font.pixelSize: 11
                                selectionColor: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
                                text: networkPanel.hiddenSsid
                                onTextChanged: networkPanel.hiddenSsid = text
                                Component.onCompleted: if (networkPanel.showHiddenPrompt) forceActiveFocus()
                            }
                            Text {
                                anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                                text: "Network name (SSID)"; color: Theme.subtext0
                                font.family: Theme.fontMain; font.pixelSize: 11
                                visible: hiddenSsidField.text.length === 0; renderType: Text.NativeRendering
                            }
                        }
                    }
                }

                // Password field
                Rectangle {
                    Layout.fillWidth: true; height: 32; radius: 5
                    color: Theme.bgSelection
                    border.color: passwordField.activeFocus ? Theme.accent : Theme.borderBase
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 6
                        Text { text: "󰌾"; color: Theme.subtext0; font.family: Theme.fontMain; font.pixelSize: 13 }
                        Item {
                            Layout.fillWidth: true; height: parent.height
                            TextInput {
                                id: passwordField
                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: networkPanel.showPassword ? TextInput.Normal : TextInput.Password
                                color: Theme.text; font.family: Theme.fontMain; font.pixelSize: 11
                                selectionColor: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
                                text: networkPanel.showHiddenPrompt ? networkPanel.hiddenPassword : networkPanel.pendingPassword
                                onTextChanged: {
                                    if (networkPanel.showHiddenPrompt) networkPanel.hiddenPassword = text;
                                    else networkPanel.pendingPassword = text;
                                }
                                onAccepted: networkPanel.confirmConnect()
                                Component.onCompleted: if (!networkPanel.showHiddenPrompt) forceActiveFocus()
                            }
                            Text {
                                anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                                text: "Password"; color: Theme.subtext0
                                font.family: Theme.fontMain; font.pixelSize: 11
                                visible: passwordField.text.length === 0; renderType: Text.NativeRendering
                            }
                        }
                    }
                }

                // Show password
                Row {
                    spacing: 6; Layout.alignment: Qt.AlignLeft
                    CheckBox {
                        id: showPwCheck
                        checked: networkPanel.showPassword
                        onCheckedChanged: networkPanel.showPassword = checked
                        indicator: Rectangle {
                            implicitWidth: 14; implicitHeight: 14; radius: 3
                            color: showPwCheck.checked ? Theme.accent : Theme.bgSelection
                            border.color: Theme.borderBase; border.width: 1
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text { anchors.centerIn: parent; text: "✓"; color: Theme.base; font.pixelSize: 9; visible: showPwCheck.checked }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Show password"; color: Theme.subtext0
                        font.family: Theme.fontMain; font.pixelSize: 10; renderType: Text.NativeRendering
                    }
                }

                // Cancel / Connect buttons
                RowLayout {
                    Layout.fillWidth: true; spacing: 8

                    Rectangle {
                        Layout.fillWidth: true; height: 30; radius: 5
                        color: cancelPwHover.hovered ? Theme.borderBase : Theme.bgSelection
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            anchors.centerIn: parent; text: "Cancel"
                            color: Theme.subtext0; font.family: Theme.fontMain
                            font.pixelSize: 10; font.weight: Font.Bold; renderType: Text.NativeRendering
                        }
                        HoverHandler { id: cancelPwHover }
                        TapHandler { onTapped: networkPanel.cancelOverlay() }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 30; radius: 5
                        color: confirmPwHover.hovered
                            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28)
                            : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.45)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            anchors.centerIn: parent; text: "Connect"
                            color: Theme.text; font.family: Theme.fontMain
                            font.pixelSize: 10; font.weight: Font.Bold; renderType: Text.NativeRendering
                        }
                        HoverHandler { id: confirmPwHover }
                        TapHandler { onTapped: networkPanel.confirmConnect() }
                    }
                }
            }
        }
    }

    // ── Inline component: detail row ──────────────────────────────────────────
    component DetailRow: Rectangle {
        property string label: ""
        property string value: ""
        property string icon: ""

        Layout.fillWidth: true
        height: value ? 30 : 0
        visible: value !== ""
        radius: 5
        color: drHover.hovered ? Theme.hoverBg : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
            Text { text: icon; color: Theme.subtext0; font.family: Theme.fontMain; font.pixelSize: 12; renderType: Text.NativeRendering }
            Text { text: label; color: Theme.subtext0; font.family: Theme.fontMain; font.pixelSize: 9; font.weight: Font.Bold; renderType: Text.NativeRendering }
            Item { Layout.fillWidth: true }
            Text { text: value; color: Theme.text; font.family: Theme.fontMain; font.pixelSize: 9; elide: Text.ElideLeft; Layout.maximumWidth: 160; renderType: Text.NativeRendering }
        }
        HoverHandler { id: drHover }
    }

    // ── Inline component: action button ──────────────────────────────────────
    component ActionButton: Rectangle {
        property string label: ""
        property bool isDangerous: false
        signal activated()

        height: 28; radius: 5
        color: isDangerous
            ? (abHover.hovered
                ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.2)
                : Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.10))
            : (abHover.hovered ? Theme.borderBase : Theme.bgSelection)
        border.color: isDangerous ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.3) : "transparent"
        border.width: isDangerous ? 1 : 0
        Behavior on color { ColorAnimation { duration: 100 } }

        Text {
            anchors.centerIn: parent; text: label
            color: isDangerous ? Theme.error : Theme.subtext0
            font.family: Theme.fontMain; font.pixelSize: 9; font.weight: Font.Bold
            renderType: Text.NativeRendering
        }
        HoverHandler { id: abHover }
        TapHandler { onTapped: parent.activated() }
    }
}
