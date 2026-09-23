pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// NetworkService — the one place quickshell talks to NetworkManager.
//
// Rebuilt 2026-09-23 (the old one is in ~/.config/config_archive/quickshell/).
// The rule that replaced the old design:
//
//   * Live state ONLY from NetworkManager over D-Bus (Quickshell.Networking):
//     ethernet link/speed/state, Wi-Fi radio, scan results, connect,
//     disconnect, forget, failure reasons, internet connectivity. It pushes
//     changes, so nothing here polls.
//   * `nmcli` ONLY for one-shot actions the D-Bus module doesn't cover —
//     connection details (IP/gateway/DNS), hidden networks, VPN up/down/import —
//     and only when the user asks. Never to track state.
//
// The old panel read state both ways at once, and the two disagreed.
// No outside tools (nmtui, nm-connection-editor, nm-applet): everything the
// panel offers is implemented here.
//
// The D-Bus state arrives asynchronously: devices are empty for the first
// second or so after quickshell starts (probed 2026-09-23). `ready` says when
// it is safe to believe "no devices".
Singleton {
    id: net

    // ▓▒░ DEVICES & STATE (D-Bus)
    readonly property bool ready: Networking.backend === NetworkBackendType.NetworkManager
                                  && Networking.devices.values.length > 0
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired) || null
    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) || null

    readonly property bool ethernetAvailable: wiredDevice !== null
    readonly property bool cablePlugged: wiredDevice ? wiredDevice.hasLink === true : false
    readonly property bool ethernetConnected: wiredDevice ? wiredDevice.connected : false
    readonly property bool ethernetBusy: wiredDevice ? (wiredDevice.state === ConnectionState.Connecting
                                                        || wiredDevice.state === ConnectionState.Disconnecting) : false
    readonly property int linkSpeed: wiredDevice && wiredDevice.linkSpeed ? wiredDevice.linkSpeed : 0

    readonly property bool wifiAvailable: wifiDevice !== null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
    readonly property var wifiNetworks: wifiDevice ? wifiDevice.networks.values : []
    readonly property var activeWifi: wifiNetworks.find(n => n.connected) || null

    // "ethernet" | "wifi" | "none" — what the bar icon shows
    readonly property string type: ethernetConnected ? "ethernet" : activeWifi ? "wifi" : "none"

    // Internet reachability as NetworkManager's own check reports it
    // (http://ping.archlinux.org/nm-check.txt — /usr/lib/NetworkManager/conf.d).
    readonly property int connectivity: Networking.connectivity
    readonly property string onlineText: {
        switch (connectivity) {
        case NetworkConnectivity.Full: return "Online";
        case NetworkConnectivity.Limited: return "Limited";
        case NetworkConnectivity.Portal: return "Login needed";
        case NetworkConnectivity.None: return "Offline";
        default: return "Checking…";
        }
    }

    // Wi-Fi list order: connected, then saved networks in range, then the
    // rest — each group strongest first. Nameless (hidden) APs are dropped.
    readonly property var sortedWifi: wifiNetworks
        .filter(n => n.name && n.name.length > 0)
        .slice()
        .sort((a, b) => (b.connected - a.connected) || (b.known - a.known)
                        || (b.signalStrength - a.signalStrength))

    // ▓▒░ ACTIONS (D-Bus)
    function setWifiEnabled(on) {
        hush();
        Networking.wifiEnabled = on;
    }

    // Off = NetworkManager's device disconnect, which also stops it from
    // auto-reconnecting until it is switched back on here. On = activate the
    // wired connection again.
    function setEthernet(on) {
        if (!wiredDevice) return;
        hush();
        if (on) {
            if (wiredDevice.network) wiredDevice.network.connect();
            else runOnce(["nmcli", "device", "connect", wiredDevice.name]);
        } else {
            wiredDevice.disconnect();
        }
    }

    function isSecured(network) {
        return network.security !== undefined
            && network.security !== WifiSecurityType.Open
            && network.security !== WifiSecurityType.Owe;
    }

    // Saved or open networks connect straight away; a new secured one needs
    // the password (the panel asks inline and calls connectWithPassword).
    function needsPassword(network) {
        return !network.known && isSecured(network);
    }

    function connectWifi(network) {
        hush();
        watchFailure(network);
        network.connect();
    }

    function connectWithPassword(network, password) {
        hush();
        watchFailure(network);
        network.connectWithPsk(password);
    }

    function disconnectWifi(network) { hush(); network.disconnect(); }
    function forgetWifi(network) { hush(); network.forget(); }

    // ▓▒░ FAILURES
    // NetworkManager reports why a connection failed. A wrong or missing
    // password ("NoSecrets", "WifiAuthTimeout", "WifiClientFailed") is what
    // nm-applet used to answer with a password dialog; here the panel reopens
    // the network's inline password field instead (see passwordRetry).
    signal wifiFailed(var network, string reason, bool wantsPassword)

    // Networks already carrying our failure handler. QML objects don't take
    // ad-hoc JS properties, so this can't be a flag on the network itself.
    property var watchedNetworks: []

    function watchFailure(network) {
        if (watchedNetworks.indexOf(network) !== -1) return;
        watchedNetworks = watchedNetworks.concat([network]);
        network.connectionFailed.connect(reason => {
            var wantsPassword = reason === ConnectionFailReason.NoSecrets
                             || reason === ConnectionFailReason.WifiAuthTimeout
                             || reason === ConnectionFailReason.WifiClientFailed;
            net.wifiFailed(network, ConnectionFailReason.toString(reason), wantsPassword);
            notify("network-wireless-disconnected", "Couldn't connect to " + network.name,
                   wantsPassword ? "Wrong or missing password." : ConnectionFailReason.toString(reason));
        });
    }

    // ▓▒░ ONE-SHOT nmcli ACTIONS
    // Run once, output discarded; used where D-Bus has no equivalent.
    function runOnce(command) {
        Quickshell.execDetached(command);
    }

    // Details of the active connection on one interface — fetched only when
    // the panel's details section is opened.
    property var details: ({})     // { ip, gateway, dns, ip6 }
    property bool detailsLoading: false

    function fetchDetails(ifname) {
        detailsLoading = true;
        detailsProc.command = ["nmcli", "-t", "-f", "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS", "device", "show", ifname];
        detailsProc.running = true;
    }

    Process {
        id: detailsProc
        stdout: StdioCollector {
            onStreamFinished: {
                var d = { ip: [], gateway: "", dns: [], ip6: [] };
                this.text.split("\n").forEach(line => {
                    var i = line.indexOf(":");
                    if (i < 0) return;
                    var key = line.slice(0, i), val = line.slice(i + 1);
                    if (!val) return;
                    if (key.startsWith("IP4.ADDRESS")) d.ip.push(val);
                    else if (key === "IP4.GATEWAY") d.gateway = val;
                    else if (key.startsWith("IP4.DNS")) d.dns.push(val);
                    else if (key.startsWith("IP6.ADDRESS")) d.ip6.push(val);
                });
                net.details = d;
                net.detailsLoading = false;
            }
        }
    }

    // Hidden network. The password never goes on a command line (anyone can
    // read argv from /proc): it is written to this process's stdin, and the
    // script moves it into a 0600 passwd-file in $XDG_RUNTIME_DIR that nmcli
    // reads and the script deletes. `nmcli --ask` is interactive-only, so
    // that is not an option here.
    signal hiddenResult(bool ok, string message)

    function joinHidden(ssid, password) {
        if (!wifiDevice || !ssid) return;
        hush();
        hiddenProc.password = password || "";
        hiddenProc.command = ["bash", "-c", `
            ssid="$1"; ifname="$2"; secured="$3"
            IFS= read -r pw
            nmcli connection delete id "$ssid" >/dev/null 2>&1
            if [ "$secured" = 1 ]; then
                nmcli connection add type wifi ifname "$ifname" con-name "$ssid" ssid "$ssid" \\
                    802-11-wireless.hidden yes wifi-sec.key-mgmt wpa-psk >/dev/null || exit 1
                umask 077
                f=$(mktemp -p "\${XDG_RUNTIME_DIR:-/tmp}" nm-hidden.XXXXXX) || exit 1
                printf '802-11-wireless-security.psk:%s\\n' "$pw" > "$f"
                nmcli --wait 30 connection up id "$ssid" passwd-file "$f" 2>&1; rc=$?
                rm -f "$f"
            else
                nmcli connection add type wifi ifname "$ifname" con-name "$ssid" ssid "$ssid" \\
                    802-11-wireless.hidden yes >/dev/null || exit 1
                nmcli --wait 30 connection up id "$ssid" 2>&1; rc=$?
            fi
            [ $rc -eq 0 ] || nmcli connection delete id "$ssid" >/dev/null 2>&1
            exit $rc`, "--", ssid, wifiDevice.name, password ? "1" : "0"];
        hiddenProc.running = true;
    }

    Process {
        id: hiddenProc
        property string password: ""
        stdinEnabled: true
        onStarted: {
            write(password + "\n");
            password = "";
        }
        stdout: StdioCollector { id: hiddenOut }
        onExited: (code) => {
            var ok = code === 0;
            net.hiddenResult(ok, ok ? "Connected" : (hiddenOut.text.trim().split("\n").pop() || "Couldn't connect"));
        }
    }

    // ▓▒░ VPN (nmcli — the D-Bus module has no VPN API)
    // [{ name, uuid, type, active }] for vpn and wireguard connections.
    property var vpns: []

    function refreshVpns() { vpnProc.running = true; }

    Process {
        id: vpnProc
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,ACTIVE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                net.vpns = this.text.split("\n").filter(l => l).map(l => {
                    var f = net.splitTerse(l);
                    return { name: f[0], uuid: f[1], type: f[2], active: f[3] === "yes" };
                }).filter(c => c.type === "vpn" || c.type === "wireguard");
            }
        }
    }

    // `nmcli -t` separates fields with ':' and escapes a literal ':' (or '\\')
    // inside a field with a backslash — a VPN named "work:eu" must survive.
    function splitTerse(line) {
        var fields = [""];
        for (var i = 0; i < line.length; i++) {
            var c = line[i];
            if (c === "\\" && i + 1 < line.length) { fields[fields.length - 1] += line[++i]; }
            else if (c === ":") { fields.push(""); }
            else { fields[fields.length - 1] += c; }
        }
        return fields;
    }

    signal vpnResult(string name, bool ok, string message)

    function setVpn(vpn, on) {
        hush();
        vpnActionProc.vpnName = vpn.name;
        vpnActionProc.turningOn = on;
        vpnActionProc.command = ["nmcli", "--wait", "30", "connection", on ? "up" : "down", "uuid", vpn.uuid];
        vpnActionProc.running = true;
    }

    Process {
        id: vpnActionProc
        property string vpnName: ""
        property bool turningOn: false
        stdout: StdioCollector { id: vpnActionOut }
        stderr: StdioCollector { id: vpnActionErr }
        onExited: (code) => {
            var ok = code === 0;
            net.vpnResult(vpnName, ok, ok ? "" : (vpnActionErr.text.trim() || vpnActionOut.text.trim()));
            // Success is visible on the switch; only a failure is worth a popup.
            if (!ok) net.notify("network-vpn-disconnected", "VPN " + vpnName + " failed",
                                vpnActionErr.text.trim().split("\n").pop() || "");
            net.refreshVpns();
        }
    }

    // WireGuard import: candidate .conf files are those under ~/Downloads that
    // actually contain a WireGuard [Interface] section.
    property var wireguardFiles: []

    function findWireguardFiles() { wgFindProc.running = true; }

    Process {
        id: wgFindProc
        command: ["bash", "-c",
            "find \"$HOME/Downloads\" -maxdepth 2 -type f -name '*.conf' -size -64k -print0 2>/dev/null"
            + " | xargs -0 -r grep -l -s '^\\[Interface\\]'"]
        stdout: StdioCollector {
            onStreamFinished: net.wireguardFiles = this.text.split("\n").filter(l => l)
        }
    }

    signal importResult(bool ok, string message)

    function importWireguard(path) {
        importProc.command = ["nmcli", "connection", "import", "type", "wireguard", "file", path];
        importProc.running = true;
    }

    Process {
        id: importProc
        stdout: StdioCollector { id: importOut }
        stderr: StdioCollector { id: importErr }
        onExited: (code) => {
            var ok = code === 0;
            net.importResult(ok, ok ? importOut.text.trim() : importErr.text.trim());
            net.notify(ok ? "network-vpn" : "dialog-error",
                       ok ? "WireGuard VPN imported" : "VPN import failed",
                       ok ? "" : importErr.text.trim().split("\n").pop());
            net.refreshVpns();
        }
    }

    // ▓▒░ NOTIFICATIONS
    // Two kinds:
    //   notify()      — always: failures, cable unplugged, captive portal,
    //                   imports. Things you need to hear about.
    //   notifyState() — routine state (connected / disconnected / on / off /
    //                   online). Silent for a while after you act from the
    //                   panel yourself: flipping the ethernet or Wi-Fi switch
    //                   used to set off a burst of "disconnected / connected /
    //                   Wi-Fi off / Online" for a change you had just made and
    //                   could see. Still shown when something changes on its
    //                   own (a network drops, the internet comes back).
    //
    // Both are held back for the first seconds after (re)start, while the
    // D-Bus state fills in, so a login or a quickshell reload doesn't announce
    // the connection that was already there.
    property bool armed: false
    Timer { interval: 6000; running: true; onTriggered: net.armed = true }

    property real quietUntil: 0
    function hush() { quietUntil = Date.now() + 10000; }

    function notify(icon, title, body) {
        if (!armed) return;
        Quickshell.execDetached(["notify-send", "-a", "Network", "-i", icon, title, body || ""]);
    }

    function notifyState(icon, title, body) {
        if (Date.now() < quietUntil) return;
        notify(icon, title, body);
    }

    onEthernetConnectedChanged: {
        if (ethernetConnected) {
            ethDropTimer.stop();
            notifyState("network-wired", "Ethernet connected", linkSpeed ? speedText(linkSpeed) : "");
        } else {
            // Wait a beat: a pulled cable drops the link and the connection
            // within moments of each other, in either order. One message.
            ethDropTimer.restart();
        }
    }

    Timer {
        id: ethDropTimer
        interval: 1500
        onTriggered: {
            if (net.ethernetConnected) return;
            if (!net.cablePlugged) net.notify("network-wired-disconnected", "Ethernet cable unplugged", "");
            else net.notifyState("network-wired-disconnected", "Ethernet disconnected", "");
        }
    }

    // Wi-Fi: announce by name, since the connected network is what changes.
    property string lastWifiName: ""
    onActiveWifiChanged: {
        var name = activeWifi ? activeWifi.name : "";
        if (name === lastWifiName) return;
        if (name) notifyState("network-wireless", "Connected to " + name, "Wi-Fi");
        else if (lastWifiName) notifyState("network-wireless-disconnected", "Disconnected from " + lastWifiName, "Wi-Fi");
        lastWifiName = name;
    }

    onWifiEnabledChanged: notifyState(wifiEnabled ? "network-wireless" : "network-wireless-offline",
                                      wifiEnabled ? "Wi-Fi turned on" : "Wi-Fi turned off", "")

    // "Online" is announced only as a recovery (after Limited / Portal /
    // Offline) — a normal connect already says "connected".
    property int lastConnectivity: NetworkConnectivity.Unknown
    onConnectivityChanged: {
        var was = lastConnectivity;
        lastConnectivity = connectivity;
        if (connectivity === NetworkConnectivity.Portal) {
            if (!armed) return;
            // The login page opens in the browser, the one place a captive
            // portal can be handled; the notification's button triggers it.
            Quickshell.execDetached(["bash", "-c",
                "a=$(notify-send -a Network -i network-wireless -A open='Open login page' "
                + "'Login needed' 'This network wants you to sign in before you can go online.'); "
                + "[ \"$a\" = open ] && xdg-open \"$1\"", "--", net.portalUrl]);
        } else if (connectivity === NetworkConnectivity.Limited) {
            notifyState("network-error", "Limited connectivity", "Connected, but the internet isn't reachable.");
        } else if (connectivity === NetworkConnectivity.Full
                   && (was === NetworkConnectivity.Limited || was === NetworkConnectivity.Portal
                       || was === NetworkConnectivity.None)) {
            notifyState("network-transmit-receive", "Back online", "");
        }
    }

    // ▓▒░ DNS — the same as CachyOS Hello's DNS page
    // Mirrors cachyos-welcome (src/dns.rs, src/actions.rs, fetched 2026-09-23):
    //   * presets: Hello's G_DNS_SERVERS table, same names/addresses/SNI —
    //             trimmed (2026-09-23, Bodz: "remove china dns and leave most
    //             reputable and trusted") to the large, audited providers:
    //             Quad9, Cloudflare ×3, Google, AdGuard ×2, Cisco OpenDNS.
    //             Dropped: AliDNS, DNSPod (China), Yandex ×3 (Russia), FFMUC,
    //             GCore, DNS.Watch. Restore rows from Hello's src/dns.rs;
    //   * apply:  on ONE connection (Hello preselects the active one) set
    //             ipv4/ipv6 DNS to the servers — each suffixed "#<DoT host>"
    //             when DNS-over-TLS is on — dns-priority -1 on both families,
    //             connection.dns-over-tls yes/no; ignore-auto-dns untouched;
    //             then reapply live (Hello: D-Bus Reapply; here `nmcli device
    //             reapply`, the same call);
    //   * reset:  DNS cleared, dns-priority 0, ignore-auto-dns no,
    //             dns-over-tls default.
    // Hello's DoH/DoQ modes (a local `blocky` proxy it installs) are not
    // mirrored — DoT is Hello's default for every preset that supports it.
    readonly property var dnsPresets: [
        { name: "AdGuard", v4: "94.140.14.14,94.140.15.15", v6: "2a10:50c0::ad1:ff,2a10:50c0::ad2:ff", dot: "dns.adguard-dns.com" },
        { name: "AdGuard Family Protection", v4: "94.140.14.15,94.140.15.16", v6: "2a10:50c0::bad1:ff,2a10:50c0::bad2:ff", dot: "family.adguard-dns.com" },
        { name: "Cisco Umbrella (OpenDNS)", v4: "208.67.222.222,208.67.220.220", v6: "2620:119:35::35,2620:119:53::53", dot: "dns.opendns.com" },
        { name: "Cloudflare", v4: "1.1.1.1,1.0.0.1", v6: "2606:4700:4700::1111,2606:4700:4700::1001", dot: "cloudflare-dns.com" },
        { name: "Cloudflare Malware and adult content blocking", v4: "1.1.1.3,1.0.0.3", v6: "2606:4700:4700::1113,2606:4700:4700::1003", dot: "family.cloudflare-dns.com" },
        { name: "Cloudflare Malware blocking", v4: "1.1.1.2,1.0.0.2", v6: "2606:4700:4700::1112,2606:4700:4700::1002", dot: "security.cloudflare-dns.com" },
        { name: "Google", v4: "8.8.8.8,8.8.4.4", v6: "2001:4860:4860::8888,2001:4860:4860::8844", dot: "dns.google" },
        { name: "Quad9", v4: "9.9.9.9,149.112.112.112", v6: "2620:fe::fe,2620:fe::9", dot: "dns.quad9.net" },
    ]

    // What the active connection uses now: { conn, uuid, device, preset
    // ("" = automatic, "Custom" = servers not in the table), dot, servers }.
    property var dns: ({ conn: "", uuid: "", device: "", preset: "", dot: false, servers: [] })
    property bool dnsBusy: false
    signal dnsResult(bool ok, string message)

    // Hello's rule for which connection: the first active one
    // (`nmcli -g NAME connection show --active`). Loopback is skipped — it is
    // listed as active too. Step 1 finds it, step 2 reads its DNS by UUID
    // (UUIDs never need escaping, names can contain anything).
    function refreshDns() { dnsActiveProc.running = true; }

    Process {
        id: dnsActiveProc
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,DEVICE", "connection", "show", "--active"]
        stdout: StdioCollector {
            onStreamFinished: {
                var rows = this.text.split("\n").filter(l => l).map(l => net.splitTerse(l));
                var active = rows.find(f => f[2] !== "loopback");
                if (!active) {
                    net.dns = { conn: "", uuid: "", device: "", preset: "", dot: false, servers: [] };
                    return;
                }
                dnsReadProc.conn = active[0];
                dnsReadProc.uuid = active[1];
                dnsReadProc.device = active[3];
                dnsReadProc.command = ["nmcli", "-t", "-f", "connection.dns-over-tls,ipv4.dns,ipv6.dns",
                                       "connection", "show", "uuid", active[1]];
                dnsReadProc.running = true;
            }
        }
    }

    Process {
        id: dnsReadProc
        property string conn: ""
        property string uuid: ""
        property string device: ""
        stdout: StdioCollector {
            onStreamFinished: {
                var dot = false, servers = [];
                // `connection show <conn>` prints "key:value" lines with the
                // value NOT escaped (unlike the tabular -t output), so split at
                // the first ':' only — IPv6 servers are full of colons.
                this.text.split("\n").filter(l => l).forEach(l => {
                    var i = l.indexOf(":");
                    var key = l.slice(0, i), val = l.slice(i + 1);
                    if (key === "connection.dns-over-tls") dot = /yes|^2/.test(val);
                    else if (key === "ipv4.dns" || key === "ipv6.dns")
                        servers = servers.concat(val.split(",").filter(x => x));
                });
                var ips = servers.map(x => x.split("#")[0]);
                var preset = "";
                if (ips.length) {
                    var match = net.dnsPresets.find(p => p.v4.split(",").every(ip => ips.indexOf(ip) !== -1));
                    preset = match ? match.name : "Custom";
                }
                net.dns = { conn: dnsReadProc.conn, uuid: dnsReadProc.uuid, device: dnsReadProc.device,
                            preset: preset, dot: dot, servers: ips };
            }
        }
    }

    // Apply a preset exactly as Hello does (see the block comment above).
    function setDns(preset, useDot) {
        if (!dns.uuid) return;
        var tag = (useDot && preset.dot) ? "#" + preset.dot : "";
        var v4 = preset.v4.split(",").map(a => a + tag).join(",");
        var v6 = preset.v6.split(",").map(a => a + tag).join(",");
        runDnsChange([
            "ipv4.dns", v4, "ipv6.dns", v6,
            "ipv4.dns-priority", "-1", "ipv6.dns-priority", "-1",
            "connection.dns-over-tls", (useDot && preset.dot) ? "yes" : "no"
        ]);
    }

    // Hello's reset: back to whatever the router hands out.
    function resetDns() {
        if (!dns.uuid) return;
        runDnsChange([
            "ipv4.dns", "", "ipv6.dns", "",
            "ipv4.dns-priority", "0", "ipv6.dns-priority", "0",
            "ipv4.ignore-auto-dns", "no", "ipv6.ignore-auto-dns", "no",
            "connection.dns-over-tls", "default"
        ]);
    }

    function runDnsChange(settings) {
        hush();
        dnsBusy = true;
        dnsWriteProc.command = ["bash", "-c",
            'uuid="$1"; dev="$2"; shift 2; nmcli connection modify uuid "$uuid" "$@" && { [ -z "$dev" ] || nmcli device reapply "$dev"; }',
            "--", dns.uuid, dns.device].concat(settings);
        dnsWriteProc.running = true;
    }

    Process {
        id: dnsWriteProc
        stderr: StdioCollector { id: dnsWriteErr }
        onExited: (code) => {
            net.dnsBusy = false;
            var ok = code === 0;
            net.dnsResult(ok, ok ? "" : dnsWriteErr.text.trim().split("\n").pop());
            if (!ok) net.notify("dialog-error", "Couldn't change DNS", dnsWriteErr.text.trim().split("\n").pop());
            net.refreshDns();
        }
    }

    // ▓▒░ CAPTIVE PORTAL LOGIN PAGE
    // Opening any plain-http URL makes a captive portal redirect to its login
    // page. We use NetworkManager's own connectivity-check URL — the one it
    // already fetches (from /usr/lib/NetworkManager/conf.d/20-connectivity.conf)
    // — so no third-party site is involved. Read once from NetworkManager;
    // the fallback is its value on this machine.
    property string portalUrl: "http://ping.archlinux.org/nm-check.txt"

    function openLoginPage() {
        Quickshell.execDetached(["xdg-open", portalUrl]);
    }

    Process {
        running: true
        command: ["busctl", "--system", "get-property", "org.freedesktop.NetworkManager",
                  "/org/freedesktop/NetworkManager", "org.freedesktop.NetworkManager", "ConnectivityCheckUri"]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = this.text.match(/^s "(http[^"]+)"/);
                if (m) net.portalUrl = m[1];
            }
        }
    }

    function speedText(mbps) {
        return mbps >= 1000 ? (mbps / 1000) + " Gb/s" : mbps + " Mb/s";
    }
}
