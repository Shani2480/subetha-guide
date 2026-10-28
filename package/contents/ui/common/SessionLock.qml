import QtQuick
import org.kde.plasma.workspace.dbus as DBus

// Whether the session is locked: ScreenSaver.GetActive every 5 s while
// `watching`; one small D-Bus call, no process. Feeds pause on a lock.
Item {
    id: lock
    property bool watching: true
    property bool locked: false
    function check() {
        var reply = DBus.SessionBus.asyncCall({ service: "org.freedesktop.ScreenSaver", path: "/ScreenSaver",
                                                iface: "org.freedesktop.ScreenSaver", member: "GetActive", arguments: [] })
        reply.finished.connect(() => { if (!reply.isError) lock.locked = !!reply.value })
    }
    Timer { interval: 5000; repeat: true; running: lock.watching; triggeredOnStart: true; onTriggered: lock.check() }
}
