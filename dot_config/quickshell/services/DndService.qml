pragma Singleton
import QtQuick

QtObject {
    id: self

    property bool isEnabled: false

    function toggle() {
        isEnabled = !isEnabled;
    }
}
