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

    property real _prevCpuIdle: -1
    property real _prevCpuTotal: -1

    property Process monitorProc: Process {
        command: ["cat", "/proc/stat", "/proc/meminfo"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i];
                    if (line.indexOf("cpu ") === 0) {
                        // "cpu  user nice system idle iowait irq softirq steal ..."
                        var f = line.trim().split(/\s+/).slice(1).map(Number);
                        var idle = (f[3] || 0) + (f[4] || 0);
                        var total = f.reduce(function(a, b) { return a + b; }, 0);
                        if (self._prevCpuTotal >= 0) {
                            var idleDelta = idle - self._prevCpuIdle;
                            var totalDelta = total - self._prevCpuTotal;
                            if (totalDelta > 0) {
                                self.cpuUsage = Math.round(100 * (1 - idleDelta / totalDelta)) || 0;
                            }
                        }
                        self._prevCpuIdle = idle;
                        self._prevCpuTotal = total;
                    } else if (line.indexOf("MemTotal:") === 0) {
                        self._memTotalKb = parseInt(line.match(/\d+/)[0]) || 0;
                    } else if (line.indexOf("MemAvailable:") === 0) {
                        var availKb = parseInt(line.match(/\d+/)[0]) || 0;
                        if (self._memTotalKb > 0) {
                            var usedKb = self._memTotalKb - availKb;
                            self.memUsed = (usedKb / 1048576).toFixed(1) + "G";
                            self.memTotal = (self._memTotalKb / 1048576).toFixed(1) + "G";
                            self.memUsage = Math.round((usedKb / self._memTotalKb) * 100) || 0;
                        }
                    }
                }
            }
        }
    }
    property real _memTotalKb: 0

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
