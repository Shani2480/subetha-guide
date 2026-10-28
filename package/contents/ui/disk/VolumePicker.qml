import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support
import "code/disk.js" as Disk

// Config-page picker for which volumes to show: All Volumes / Root Only
// shortcuts over a checklist from the widget's own probe (so the list is
// exactly what the widget can show), plus selected mount points that are not
// mounted now, so an unplugged drive keeps its tick. `selected` is the stored
// list; changes come back through picked().
ColumnLayout {
    id: picker

    property var selected: ["/"]
    property bool showBoot: false
    signal picked(var keys)

    spacing: 4

    P5Support.DataSource {
        id: probe
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source)
            picker.mounted = Disk.parse(data["stdout"], null, Date.now(), { showBoot: true }).volumes
        }
    }
    property var mounted: []
    Component.onCompleted: probe.connectSource(Disk.COMMAND)

    readonly property var keys: selected || []
    readonly property bool allMode: keys.indexOf("all") >= 0
    readonly property var rows: {
        var out = mounted.filter(v => showBoot || !/^\/(boot|efi)(\/|$)/.test(v.mountPoint))
                         .map(v => ({ key: v.mountPoint, mounts: v.mounts.split("\n"), label: v.label,
                                      detail: Disk.bytes(v.totalBytes) + " · " + v.fsType.toUpperCase()
                                              + (v.isRemovable ? i18n(" · removable") : ""),
                                      connected: true }))
        keys.forEach(function (path) {
            if (path === "all" || out.some(r => r.mounts.indexOf(path) >= 0)) return
            out.push({ key: path, mounts: [path], label: path, detail: i18n("not mounted"), connected: false })
        })
        return out
    }
    function isChecked(row) {
        return allMode || row.mounts.some(m => keys.indexOf(m) >= 0)
    }
    // Ticking one volume turns "all" into the explicit list it stood for.
    function setChecked(row, on) {
        var out = rows.filter(r => r.key !== row.key && isChecked(r)).map(r => r.key)
        if (on) out.push(row.key)
        picked(out)
    }

    RowLayout {
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        QQC2.Button {
            text: i18n("All Volumes")
            icon.name: "edit-select-all"
            highlighted: picker.allMode
            onClicked: picker.picked(["all"])
        }
        QQC2.Button {
            text: i18n("Root Only")
            icon.name: "drive-harddisk-root"
            highlighted: picker.keys.length === 1 && picker.keys[0] === "/"
            onClicked: picker.picked(["/"])
        }
    }
    Repeater {
        model: picker.rows
        ColumnLayout {
            required property var modelData
            spacing: 0
            QQC2.CheckBox {
                text: modelData.label + "   " + modelData.key
                checked: picker.isChecked(modelData)
                onToggled: picker.setChecked(modelData, checked)
            }
            QQC2.Label {
                Layout.leftMargin: Kirigami.Units.gridUnit * 1.6
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                text: modelData.detail
                      + (modelData.mounts.length > 1 ? i18n(" · also %1", modelData.mounts.slice(1).join(", ")) : "")
                font: Kirigami.Theme.smallFont
                opacity: modelData.connected ? 0.7 : 0.5
                elide: Text.ElideRight
            }
        }
    }
    QQC2.Label {
        visible: picker.rows.length === 0
        text: i18n("Scanning mounted volumes…")
        opacity: 0.7
    }
}
