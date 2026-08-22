pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: self

    property int cpuUsage: 0
    property int memUsage: 0
    property string memUsed: "0.0G"
    property string memTotal: "0.0G"

    // Network speed in KB/s
    property real downloadSpeed: 0
    property real uploadSpeed: 0
    property var _prevRx: ({})
    property var _prevTx: ({})
    property real _lastNetTime: 0

    property Process monitorProc: Process {
        command: ["sh", "-c", "cpu=$(top -bn1 | grep 'Cpu(s)' | awk '{print 100 - $8}'); mem=$(free -m | awk '/Mem:/ {printf \"%.1f %.1f %d\", $3/1024, $2/1024, ($3/$2)*100}'); echo \"$cpu $mem\""]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var output = this.text.trim();
                var parts = output.split(/\s+/);
                if (parts.length >= 4) {
                    self.cpuUsage = Math.round(parseFloat(parts[0])) || 0;
                    self.memUsed = parts[1] + "G";
                    self.memTotal = parts[2] + "G";
                    self.memUsage = parseInt(parts[3]) || 0;
                } else if (parts.length >= 2) {
                    self.cpuUsage = Math.round(parseFloat(parts[0])) || 0;
                    self.memUsage = Math.round(parseFloat(parts[1])) || 0;
                }
            }
        }
    }

    property Timer pollTimer: Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            self.monitorProc.running = true;
        }
    }

    property Process netProc: Process {
        command: ["cat", "/proc/net/dev"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var now = Date.now();
                var lines = this.text.trim().split("\n");
                var newRx = {}, newTx = {};
                // Accumulate current byte counts per interface (skip header rows and loopback)
                for (var i = 2; i < lines.length; i++) {
                    var parts = lines[i].trim().split(/\s+/);
                    var iface = parts[0].replace(":", "");
                    if (iface === "lo") continue;
                    newRx[iface] = parseInt(parts[1]) || 0;
                    newTx[iface] = parseInt(parts[9]) || 0;
                }
                // Sum current and previous totals
                var totalRx = 0, totalTx = 0;
                var prevRx  = 0, prevTx  = 0;
                for (var k in newRx) {
                    totalRx += newRx[k];
                    prevRx  += self._prevRx[k] || 0;
                }
                for (var k2 in newTx) {
                    totalTx += newTx[k2];
                    prevTx  += self._prevTx[k2] || 0;
                }
                var dt = (now - self._lastNetTime) / 1000.0;
                if (self._lastNetTime > 0 && dt > 0) {
                    self.downloadSpeed = Math.max(0, (totalRx - prevRx) / dt / 1024);
                    self.uploadSpeed   = Math.max(0, (totalTx - prevTx) / dt / 1024);
                }
                self._prevRx = newRx;
                self._prevTx = newTx;
                self._lastNetTime = now;
            }
        }
    }

    property Timer netPollTimer: Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            self.netProc.running = true;
        }
    }
}
