pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: self

    property bool isEnabled: false
    property bool isConnected: false
    property string connectedDevice: ""

    property Process btToggleProc: Process {
        command: ["sh", "-c", "if bluetoothctl show | grep -q \"Powered: yes\"; then bluetoothctl power off; else bluetoothctl power on; fi"]
    }

    property Process btCheckProc: Process {
        command: ["sh", "-c", "if bluetoothctl show | grep -q \"Powered: yes\"; then echo \"POWERED_YES\"; bluetoothctl devices Connected; else echo \"POWERED_NO\"; fi"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n");
                var powered = lines.length > 0 && lines[0].includes("POWERED_YES");
                self.isEnabled = powered;
                if (powered && lines.length > 1 && lines[1].trim().length > 0) {
                    self.isConnected = true;
                    var devLine = lines[1].trim();
                    var match = devLine.match(/^Device\s+[0-9A-Fa-f:]+\s+(.+)$/);
                    self.connectedDevice = match ? match[1] : devLine;
                } else {
                    self.isConnected = false;
                    self.connectedDevice = "";
                }
            }
        }
    }

    function toggle() {
        btToggleProc.running = true;
        isEnabled = !isEnabled; // Optimistic update
    }

    function updateStatus() {
        btCheckProc.running = true;
    }

    property Timer pollTimer: Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            self.updateStatus();
        }
    }
}
