import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support
import "code/power.js" as Power

// Config-page picker for which batteries to show: Select All / Primary Only
// shortcuts over a checklist of the devices connected right now (read from
// the power engine), plus selected ones that are away, so a switched-off
// mouse keeps its tick. `selected` is the stored list; changes come back
// through picked().
ColumnLayout {
    id: picker

    property var selected: ["all"]
    signal picked(var keys)

    spacing: 2

    P5Support.DataSource {
        id: pm
        engine: "powermanagement"
        connectedSources: sources.filter(s => /^Battery\d*$/.test(s))
        onNewData: Qt.callLater(picker.rebuild)
    }
    property var discovered: []
    function rebuild() {
        var names = pm.sources.filter(s => /^Battery\d+$/.test(s) && pm.data[s] && pm.data[s]["Percent"] !== undefined)
        var primaryCount = names.filter(s => pm.data[s]["Is Power Supply"]).length
        var list = names.map(s => Power.describe(s, pm.data[s], {}, primaryCount))
        list.sort(Power.compare)
        discovered = list
    }

    readonly property var keys: selected || []
    readonly property bool allMode: keys.indexOf("all") >= 0
    readonly property bool primaryMode: keys.indexOf("primary") >= 0
    readonly property var rows: {
        var out = discovered.map(d => ({ key: d.key, name: d.name, primary: d.primary, percent: d.percent, connected: true }))
        keys.forEach(function (key) {
            if (key === "all" || key === "primary" || out.some(r => r.key === key)) return
            out.push({ key: key, name: key.slice(key.indexOf(":") + 1), primary: false, percent: -1, connected: false })
        })
        return out
    }
    function isChecked(row) {
        return allMode || (row.primary && primaryMode) || keys.indexOf(row.key) >= 0
    }
    // Ticking one device turns the "all" / "primary" shortcut into the explicit
    // list it stood for, then adds or removes that device.
    function setChecked(row, on) {
        var out = rows.filter(r => r.key !== row.key && isChecked(r)).map(r => r.key)
        if (on) out.push(row.key)
        picked(out)
    }

    RowLayout {
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        QQC2.Button {
            text: i18n("Select All")
            icon.name: "edit-select-all"
            highlighted: picker.allMode
            onClicked: picker.picked(["all"])
        }
        QQC2.Button {
            text: i18n("Primary Only")
            icon.name: "computer-laptop"
            highlighted: picker.primaryMode && picker.keys.length === 1
            onClicked: picker.picked(["primary"])
        }
    }
    Repeater {
        model: picker.rows
        QQC2.CheckBox {
            required property var modelData
            text: modelData.name
                  + (modelData.primary ? i18n("  (system battery)") : "")
                  + (modelData.connected ? "  · " + modelData.percent + "%" : i18n("  · not connected"))
            checked: picker.isChecked(modelData)
            onToggled: picker.setChecked(modelData, checked)
        }
    }
    QQC2.Label {
        visible: picker.rows.length === 0
        text: i18n("No battery-reporting devices found.")
        opacity: 0.7
    }
    QQC2.Label {
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        text: picker.allMode
            ? i18n("Select All also shows devices you connect later.")
            : i18n("Devices connected later appear only after you tick them here.")
        wrapMode: Text.WordWrap
        font: Kirigami.Theme.smallFont
        opacity: 0.7
    }
}
