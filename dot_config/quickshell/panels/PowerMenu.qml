import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs

PanelWindow {
    id: powerMenuPopup
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
        onClicked: powerMenuPopup.visible = false
    }

    property int selectedIndex: 0

    // ▓▒░ CGROUP-SAFE LAUNCH — do not go back to bare Quickshell.execDetached here
    //
    // execDetached detaches the *process* but not the *cgroup*: the child reparents
    // to init yet stays inside quickshell.service. That unit is KillMode=control-group
    // (the systemd default), so the instant quickshell's main PID exits, systemd
    // SIGTERMs everything left in the group.
    //
    // That is fatal for hyprshutdown specifically, because its sequence is:
    //   1. ask every app and layer client to exit  <- this kills quickshell
    //   2. WAIT for them to exit                   <- killed here, with quickshell
    //   3. dispatch hl.dsp.exit()                  <- never reached
    //   4. run --post-cmd                          <- never reached
    // It cannot survive the thing it is waiting for. Observed 2026-09-21: apps and
    // bar closed, Hyprland stayed up, machine never rebooted.
    //
    // systemd-run puts the command in its own transient scope under app.slice --
    // a sibling of quickshell.service, not a child -- so quickshell dying, crashing
    // or being restarted by Restart=on-failure no longer takes it down.
    function runDetached(description, command) {
        Quickshell.execDetached([
            "systemd-run", "--user", "--scope", "--quiet", "--collect",
            "--slice=app.slice", "--description=" + description,
            "bash", "-c", command
        ])
    }

    // ▓▒░ ACTIONS — one definition each, called from both the keyboard handler
    // and the TapHandler. They used to be duplicated per input path, which meant
    // a fix applied to one silently left the other broken.
    //
    // keycheck.sh forces every keyboard back to layout 0 (English) so the lock
    // password is typed in the expected layout -- kb_layout is "us,ara". It can
    // never fail, so it is chained with `;` not `&&`: the lock must still happen.

    // Lock and suspend both go through logind rather than naming hyprlock here.
    // ~/.config/hypr/hypridle.conf's general:lock_cmd is the single definition of
    // "lock this session" (it already does faillock --reset, a pidof guard and
    // --grace 1); calling hyprlock directly duplicated it and broke hypridle's
    // sleep-inhibit detection. Suspend needs no lock step at all -- hypridle's
    // before_sleep_cmd locks on PrepareForSleep and its inhibitor holds the
    // suspend until the session is genuinely locked, which is what the old
    // `hyprlock & sleep 1.2` was guessing at.
    function doLock()     { runDetached("lock session", "~/.config/scripts/keycheck.sh; loginctl lock-session") }
    function doSuspend()  { runDetached("suspend",      "~/.config/scripts/keycheck.sh; systemctl suspend") }

    // --no-fork: run in the foreground of the scope so systemd supervises
    // hyprshutdown itself rather than a daemonized grandchild.
    //
    // --post-cmd is upstream's documented way to reboot/power off, and it is kept.
    // It does carry one residual race: the scope lives under user@1000.service,
    // Linger=no, so once SDDM's session ends the scope is torn down -- and the
    // post-cmd only runs after Hyprland has exited. The margin is wide (post-cmd
    // is one logind call; teardown has to walk Hyprland -> start-hyprland ->
    // sddm-helper -> logind -> user@1000.service first) and this is unchanged
    // from before the cgroup fix, which strictly improved survivability. It was
    // never the cause of the observed failure.
    //
    // If reboot/poweroff ever logs you out WITHOUT powering the machine down,
    // that race is the place to look, not the cgroup. Diagnosis: the scope died
    // early, so nothing issued the logind call. Two ways out, in order of
    // preference:
    //   1. "hyprshutdown --no-fork --no-exit -t '...' ; systemctl reboot"
    //      -- issues the power action while the session is still fully alive, so
    //      nothing has to outlive Hyprland. UNVERIFIED: if --no-exit does not
    //      return on its own once apps are closed, every reboot would hang on
    //      the dialog, so test it before adopting.
    //   2. loginctl enable-linger -- keeps user@1000.service (and the scope)
    //      alive past session end. Guaranteed, but it also starts your user
    //      units at boot without a login, which is a much broader change.
    function doLogout()   { runDetached("hyprshutdown (logout)",   "hyprshutdown --no-fork") }
    function doReboot()   { runDetached("hyprshutdown (reboot)",   "hyprshutdown --no-fork -t 'Rebooting...' --post-cmd 'systemctl reboot'") }
    function doPoweroff() { runDetached("hyprshutdown (poweroff)", "hyprshutdown --no-fork -t 'Shutting down...' --post-cmd 'systemctl poweroff'") }

    onVisibleChanged: {
        if (visible) {
            selectedIndex = 0;
            powerMenuRect.forceActiveFocus();
        }
    }

    Rectangle {
        id: powerMenuRect
        anchors { top: parent.top; right: parent.right }
        anchors.topMargin: 52
        anchors.rightMargin: 16
        width: 290
        height: 54
        color: Theme.glassBg
        border.color: Theme.glassBorder
        border.width: 1
        radius: 19
        antialiasing: true
        focus: true

        // Block background click propagation
        MouseArea { anchors.fill: parent; onClicked: {} }

        Keys.onLeftPressed: selectedIndex = (selectedIndex - 1 + 5) % 5
        Keys.onUpPressed: selectedIndex = (selectedIndex - 1 + 5) % 5
        Keys.onRightPressed: selectedIndex = (selectedIndex + 1) % 5
        Keys.onDownPressed: selectedIndex = (selectedIndex + 1) % 5
        Keys.onTabPressed: selectedIndex = (selectedIndex + 1) % 5
        Keys.onBacktabPressed: selectedIndex = (selectedIndex - 1 + 5) % 5
        Keys.onEscapePressed: powerMenuPopup.visible = false
        Keys.onReturnPressed: {
            powerMenuPopup.visible = false
            buttons.itemAt(selectedIndex).modelData.run()
        }

        // Same style as the hyprlock power buttons (hypr/hyprlock.conf): bare
        // white outline glyphs, no per-button background, accent when hovered
        // or keyboard-selected. The moon is the octicon one hyprlock uses — the
        // Material sleep glyph is filled.
        RowLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 6

            Repeater {
                id: buttons
                model: [
                    { icon: String.fromCodePoint(0xf456),  run: () => powerMenuPopup.doLock() },     // lock
                    { icon: String.fromCodePoint(0xf4ee),  run: () => powerMenuPopup.doSuspend() },  // suspend
                    { icon: String.fromCodePoint(0xf08b),  run: () => powerMenuPopup.doLogout() },   // logout
                    { icon: String.fromCodePoint(0xf0709), run: () => powerMenuPopup.doReboot() },   // reboot
                    { icon: String.fromCodePoint(0xf0425), run: () => powerMenuPopup.doPoweroff() }  // poweroff
                ]

                delegate: Item {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.centerIn: parent
                        text: modelData.icon
                        color: (hover.hovered || selectedIndex === index) ? Theme.accent : Theme.text
                        Behavior on color { ColorAnimation { duration: 120 } }
                        font.family: Theme.fontMain
                        font.pixelSize: 18
                    }

                    HoverHandler {
                        id: hover
                        onHoveredChanged: if (hovered) selectedIndex = index
                    }
                    TapHandler {
                        onTapped: {
                            powerMenuPopup.visible = false
                            modelData.run()
                        }
                    }
                }
            }
        }
    }
}
