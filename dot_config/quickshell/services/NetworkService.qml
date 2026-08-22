pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: self

    property string type: "none" // "wifi", "ethernet", "none"
    property string ssid: ""
    property int signal: 0
    property string device: ""
    property bool wifiEnabled: true

    // Ethernet specific state
    property bool ethernetAvailable: false
    property bool ethernetConnected: false
    property string ethernetDevice: ""
    property string ethernetConnectionName: ""

    // Active connection details
    property string activeConnectionName: ""
    property bool vpnActive: false

    // Connection details (populated on demand)
    property string ipAddress: ""
    property string gateway: ""
    property string dnsServers: ""
    property string ipv6Address: ""

    property Process wifiToggleProc: Process {
        command: ["sh", "-c", "if [ \"$(nmcli radio wifi)\" = \"enabled\" ]; then nmcli radio wifi off; else nmcli radio wifi on; fi"]
    }

    property Process wifiCheckProc: Process {
        command: ["nmcli", "radio", "wifi"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                self.wifiEnabled = (this.text.trim() === "enabled");
            }
        }
    }

    function toggleWifi() {
        wifiToggleProc.running = true;
        wifiEnabled = !wifiEnabled; // Optimistic update
    }

    function updateWifiStatus() {
        wifiCheckProc.running = true;
    }

    // Ethernet control
    property Process ethernetControlProc: Process {
        running: false
        onRunningChanged: {
            if (!running) {
                self.updateAll();
            }
        }
    }

    function toggleEthernet() {
        if (self.ethernetConnected) {
            disconnectEthernet();
        } else {
            connectEthernet();
        }
    }

    function connectEthernet() {
        var dev = self.ethernetDevice || "eno1";
        var conn = self.ethernetConnectionName || "Wired connection 1";
        ethernetControlProc.command = ["sh", "-c", "nmcli con up \"" + conn + "\" 2>/dev/null || nmcli dev connect " + dev];
        ethernetControlProc.running = true;
    }

    function disconnectEthernet() {
        var dev = self.ethernetDevice || "eno1";
        ethernetControlProc.command = ["nmcli", "dev", "disconnect", dev];
        ethernetControlProc.running = true;
    }

    function openManager() {
        Quickshell.execDetached(["ghostty", "-e", "nmtui"]);
    }

    // Fetch detailed info for the active connection
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

    // Fetch all saved connections
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

    // Process to query active connections
    property Process wifiProc: Process {
        command: ["sh", "-c", "nmcli -t -f active,ssid,signal dev wifi | grep '^yes' || true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n");
                if (lines.length > 0 && lines[0].startsWith("yes:")) {
                    var line = lines[0];
                    var firstColon = line.indexOf(":");
                    var lastColon = line.lastIndexOf(":");
                    if (firstColon !== -1 && lastColon !== -1 && firstColon !== lastColon) {
                        self.type = "wifi";
                        self.ssid = line.substring(firstColon + 1, lastColon).replace(/\\:/g, ":");
                        self.signal = parseInt(line.substring(lastColon + 1)) || 0;
                        self.activeConnectionName = self.ssid;
                        self.fetchConnectionDetails(self.ssid);
                        return;
                    }
                }
                if (!self.ethernetConnected) {
                    self.type = "none";
                    self.ssid = "Disconnected";
                    self.signal = 0;
                    self.activeConnectionName = "";
                    self.ipAddress = "";
                    self.gateway = "";
                    self.dnsServers = "";
                    self.ipv6Address = "";
                }
            }
        }
    }

    property Process ethernetProc: Process {
        command: ["sh", "-c", "nmcli -t -f device,type,state,connection dev | grep ':ethernet:' || true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n");
                self.ethernetAvailable = false;
                self.ethernetConnected = false;
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (!line) continue;
                    var parts = line.split(":");
                    if (parts.length >= 3) {
                        self.ethernetAvailable = true;
                        self.ethernetDevice = parts[0];
                        if (parts[2] === "connected") {
                            self.ethernetConnected = true;
                            self.type = "ethernet";
                            self.device = parts[0];
                            self.ssid = "Ethernet";
                            self.signal = 100;
                            var conn = parts.slice(3).join(":").trim();
                            if (conn) {
                                self.activeConnectionName = conn;
                                self.ethernetConnectionName = conn;
                                self.fetchConnectionDetails(conn);
                            }
                            return;
                        } else {
                            if (parts.length >= 4 && parts.slice(3).join(":").trim()) {
                                self.ethernetConnectionName = parts.slice(3).join(":").trim();
                            }
                        }
                    }
                }
                // If ethernet is not connected, check wifi
                self.wifiProc.running = true;
            }
        }
    }

    // Poll for VPN status
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
        self.ethernetProc.running = true;
        self.updateWifiStatus();
        self.vpnProc.running = true;
    }

    property Timer pollTimer: Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            self.updateAll();
        }
    }
}
