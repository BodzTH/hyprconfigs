pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

QtObject {
    id: self

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool isEnabled: adapter ? adapter.enabled : false

    // First device currently reporting a live connection, if any.
    readonly property var _connected: {
        var devices = Bluetooth.devices;
        return devices ? devices.values.find(d => d.connected) : null;
    }
    readonly property bool isConnected: !!_connected
    readonly property string connectedDevice: _connected ? (_connected.name || _connected.deviceName || "") : ""

    function toggle() {
        if (adapter) adapter.enabled = !adapter.enabled;
    }
}
