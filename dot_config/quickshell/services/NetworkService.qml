pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

QtObject {
    id: self

    // ── Live state — bound straight to the native NetworkManager module.
    // No polling: these update the instant D-Bus reports a change.

    // Exposed publicly — NetworkPanel binds its WiFi list directly to
    // wifiDevice.networks and toggles wifiDevice.scannerEnabled.
    readonly property var wiredDevice: {
        var d = Networking.devices;
        return d ? d.values.find(dev => dev.type === DeviceType.Wired) || null : null;
    }
    readonly property var wifiDevice: {
        var d = Networking.devices;
        return d ? d.values.find(dev => dev.type === DeviceType.Wifi) || null : null;
    }
    // The WifiNetwork currently connected, if any — also used by NetworkPanel
    // to drive the Status tab's disconnect action.
    readonly property var activeWifiNetwork: {
        return self.wifiDevice ? (self.wifiDevice.networks.values.find(n => n.connected) || null) : null;
    }

    readonly property bool ethernetAvailable: !!wiredDevice
    readonly property bool ethernetConnected: wiredDevice ? wiredDevice.connected : false

    readonly property bool wifiEnabled: Networking.wifiEnabled

    readonly property string type: ethernetConnected ? "ethernet" : (activeWifiNetwork ? "wifi" : "none")
    readonly property string ssid: activeWifiNetwork ? activeWifiNetwork.name : ""
    readonly property int signal: activeWifiNetwork ? Math.round(activeWifiNetwork.signalStrength) : 0

    readonly property string activeConnectionName: {
        if (ethernetConnected && wiredDevice.network) return wiredDevice.network.name;
        if (activeWifiNetwork) return activeWifiNetwork.name;
        return "";
    }

    // VPN has no native equivalent — the only state left worth polling.
    property bool vpnActive: false

    // Connection details (populated on demand; native only exposes a single
    // address, not gateway/DNS/IPv6, so these stay nmcli-sourced).
    property string ipAddress: ""
    property string gateway: ""
    property string dnsServers: ""
    property string ipv6Address: ""

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function toggleEthernet() {
        if (self.ethernetConnected) {
            disconnectEthernet();
        } else {
            connectEthernet();
        }
    }

    function connectEthernet() {
        if (self.wiredDevice && self.wiredDevice.network) {
            self.wiredDevice.network.connect();
        }
    }

    function disconnectEthernet() {
        if (self.wiredDevice) {
            self.wiredDevice.disconnect();
        }
    }

    function openManager() {
        Quickshell.execDetached(["kitty", "-e", "nmtui"]);
    }

    // Fetch detailed info (IP/gateway/DNS/IPv6) for the active connection
    property Process detailsProc: Process {
        id: detailsProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n");
                self.ipAddress = "";
                self.gateway = "";
                self.dnsServers = "";
                self.ipv6Address = "";
                var dnsArr = [];
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line.startsWith("IP4.ADDRESS")) {
                        var val = line.split(":").slice(1).join(":").trim();
                        if (!self.ipAddress) self.ipAddress = val;
                    } else if (line.startsWith("IP4.GATEWAY")) {
                        var gw = line.split(":").slice(1).join(":").trim();
                        if (gw && gw !== "--") self.gateway = gw;
                    } else if (line.startsWith("IP4.DNS")) {
                        var dns = line.split(":").slice(1).join(":").trim();
                        dns = dns.split("#")[0].trim();
                        if (dns && dns !== "--" && dnsArr.indexOf(dns) === -1) dnsArr.push(dns);
                    } else if (line.startsWith("IP6.ADDRESS")) {
                        if (!self.ipv6Address) {
                            var v6 = line.split(":").slice(1).join(":").trim();
                            if (v6 && !v6.startsWith("fe80") && v6 !== "--") self.ipv6Address = v6;
                        }
                    }
                }
                self.dnsServers = dnsArr.slice(0, 3).join(", ");
            }
        }
    }

    function fetchConnectionDetails(connName) {
        if (!connName) return;
        detailsProc.command = ["nmcli", "con", "show", connName];
        detailsProc.running = true;
    }

    // Fetch all saved connections (Saved tab) — nmcli only; native exposes
    // no per-connection UUID/list-of-profiles API.
    property Process savedConnsProc: Process {
        id: savedConnsProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                self.savedConnectionsReady(this.text.trim());
            }
        }
    }

    signal savedConnectionsReady(string raw)

    function fetchSavedConnections() {
        savedConnsProc.command = ["nmcli", "-t", "-f", "name,type,active,uuid", "con", "show"];
        savedConnsProc.running = true;
    }

    // Poll for VPN status — nothing native reports this, so it's the one
    // thing still on a timer, and a slow one since VPN state rarely changes.
    property Process vpnProc: Process {
        command: ["sh", "-c", "nmcli -t -f name,type,active con show | grep ':vpn:yes\\|:wireguard:yes' || true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                self.vpnActive = this.text.trim().length > 0;
            }
        }
    }

    function updateAll() {
        self.vpnProc.running = true;
    }

    property Timer vpnPollTimer: Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: self.vpnProc.running = true
    }
}
