import QtQuick
import Quickshell.Services.UPower as Up
import qs

BarItem {
    id: batteryWidget

    readonly property var bat: Up.UPower.displayDevice
    readonly property bool hasBat: bat ? bat.isPresent : false
    readonly property bool onBat: Up.UPower.onBattery
    readonly property int batPct: bat ? Math.round(bat.percentage) : 0

    width: contentRow.implicitWidth + 16
    
    HoverHandler { id: batteryHover }
    property bool isHoveredOrFocused: batteryHover.hovered || batteryWidget.activeFocus
    

    visible: hasBat

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: isHoveredOrFocused ? 4 : 0

        Behavior on spacing { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        Text {
            id: batteryIcon
            anchors.verticalCenter: parent.verticalCenter
            verticalAlignment: Text.AlignVCenter
            color: onBat ? Theme.text : Theme.success
            font.family: Theme.fontMain
            font.pixelSize: 14
            renderType: Text.NativeRendering
            text: {
                if (!hasBat) return "󰂎"
                return onBat ? "󰁾" : "󰂄"
            }
        }

        Text {
            id: batteryText
            anchors.verticalCenter: parent.verticalCenter
            verticalAlignment: Text.AlignVCenter
            color: Theme.text
            font.family: Theme.fontMain
            font.pixelSize: 10
            font.weight: Font.Bold
            renderType: Text.NativeRendering
            
            clip: true
            width: isHoveredOrFocused ? implicitWidth : 0
            opacity: isHoveredOrFocused ? 1.0 : 0.0

            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200 } }

            text: {
                if (!hasBat) return "00%"
                return batPct.toString().padStart(2, '0') + "%"
            }
        }
    }
}
