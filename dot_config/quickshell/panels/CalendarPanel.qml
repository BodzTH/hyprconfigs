import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."

PanelWindow {
    id: calendarPopup
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
        onClicked: calendarPopup.visible = false
    }

    property date currentDate: new Date()
    property date displayedDate: new Date()

    readonly property int cellSize: 28
    readonly property var weekdays: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    onVisibleChanged: {
        if (visible) {
            var today = new Date();
            currentDate = today;
            displayedDate = today;
            updateCalendar();
        }
    }

    onDisplayedDateChanged: updateCalendar()
    onCurrentDateChanged: updateCalendar()

    ListModel {
        id: daysModel
    }

    /**
     * Shifts the displayed date to the next month.
     */
    function nextMonth() {
        var next = new Date(displayedDate.getFullYear(), displayedDate.getMonth() + 1, 1);
        displayedDate = next;
    }

    /**
     * Shifts the displayed date to the previous month.
     */
    function prevMonth() {
        var prev = new Date(displayedDate.getFullYear(), displayedDate.getMonth() - 1, 1);
        displayedDate = prev;
    }

    /**
     * Returns human-readable month name.
     */
    function getMonthName(monthIndex) {
        var months = [
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December"
        ];
        return months[monthIndex];
    }

    /**
     * Recomputes the 42 cells (6 weeks x 7 days) for the calendar grid.
     */
    function updateCalendar() {
        var year = displayedDate.getFullYear();
        var month = displayedDate.getMonth();

        var firstDayOfMonth = new Date(year, month, 1);
        var lastDayOfMonth = new Date(year, month + 1, 0);

        var daysInMonth = lastDayOfMonth.getDate();
        var daysInPrevMonth = new Date(year, month, 0).getDate();

        // 0=Sunday, 1=Monday... we want 0=Monday, 6=Sunday
        var startingDay = firstDayOfMonth.getDay() - 1;
        if (startingDay < 0) startingDay = 6;

        var calendarData = [];

        // Previous month filler days
        for (var i = startingDay - 1; i >= 0; i--) {
            calendarData.push({
                day: daysInPrevMonth - i,
                isCurrentMonth: false,
                isToday: false
            });
        }

        // Current month days
        var today = currentDate;
        var isCurrentMonthAndYear = (today.getFullYear() === year && today.getMonth() === month);

        for (var j = 1; j <= daysInMonth; j++) {
            var isToday = isCurrentMonthAndYear && (today.getDate() === j);
            calendarData.push({
                day: j,
                isCurrentMonth: true,
                isToday: isToday
            });
        }

        // Next month filler days to complete 42 cells
        var remainingCells = 42 - calendarData.length;
        for (var k = 1; k <= remainingCells; k++) {
            calendarData.push({
                day: k,
                isCurrentMonth: false,
                isToday: false
            });
        }

        // Update the ListModel
        for (var k = 0; k < 42; k++) {
            if (daysModel.count <= k) {
                daysModel.append(calendarData[k]);
            } else {
                daysModel.set(k, calendarData[k]);
            }
        }
    }

    Rectangle {
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
        anchors.topMargin: 52
        width: 260
        height: 290
        color: Theme.glassBg
        border.color: Theme.glassBorder
        border.width: 1
        radius: 19
        antialiasing: true

        focus: true
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Left) {
                calendarPopup.prevMonth();
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                calendarPopup.nextMonth();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                calendarPopup.visible = false;
                event.accepted = true;
            }
        }

        // Block background click propagation & support mouse wheel
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: (wheel) => {
                if (wheel.angleDelta.y > 0) {
                    calendarPopup.prevMonth();
                } else if (wheel.angleDelta.y < 0) {
                    calendarPopup.nextMonth();
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Header: Month, Year, Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Previous button
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    antialiasing: true
                    color: prevMouse.hovered ? Theme.bgSelection : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "<"
                        color: Theme.text
                        font.family: Theme.fontMain
                        font.pixelSize: Theme.fontSize
                        font.weight: Font.Bold
                    }

                    HoverHandler { id: prevMouse }
                    TapHandler {
                        onTapped: calendarPopup.prevMonth()
                    }
                }

                Text {
                    text: calendarPopup.getMonthName(calendarPopup.displayedDate.getMonth()) + " " + calendarPopup.displayedDate.getFullYear()
                    color: Theme.text
                    font.family: Theme.fontMain
                    font.pixelSize: Theme.fontSize + 2
                    font.weight: Font.Bold
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    renderType: Text.NativeRendering
                }

                // Next button
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    antialiasing: true
                    color: nextMouse.hovered ? Theme.bgSelection : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: ">"
                        color: Theme.text
                        font.family: Theme.fontMain
                        font.pixelSize: Theme.fontSize
                        font.weight: Font.Bold
                    }

                    HoverHandler { id: nextMouse }
                    TapHandler {
                        onTapped: calendarPopup.nextMonth()
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.bgSelection
            }

            // Weekdays
            Grid {
                columns: 7
                spacing: 4
                Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: calendarPopup.weekdays
                    Rectangle {
                        width: calendarPopup.cellSize
                        height: 20
                        color: "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: Theme.subtext0
                            font.family: Theme.fontMain
                            font.pixelSize: Theme.fontSize - 1
                            font.weight: Font.Bold
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }

            // Days Grid
            Grid {
                columns: 7
                spacing: 4
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: daysModel

                    Rectangle {
                        width: calendarPopup.cellSize
                        height: calendarPopup.cellSize
                        radius: 14
                        antialiasing: true
                        color: model.isToday ? Theme.text : "transparent"
                        border.color: model.isToday ? Theme.text : "transparent"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: model.day
                            color: model.isToday ? Theme.base : (model.isCurrentMonth ? Theme.text : Theme.subtext0)
                            font.family: Theme.fontMain
                            font.pixelSize: Theme.fontSize - 1
                            font.weight: model.isToday ? Font.Bold : Font.Normal
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }
        }
    }
}
