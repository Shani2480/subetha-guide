import QtQuick
import QtQuick.Layouts
import "code/disk.js" as Disk
import "../common"

// The body of the storage page, without frame or header: the commentary, one
// drawer pill per selected volume with its live read / write throughput, and
// a totals footer. Minimal: slim pills only. With `monitorLinks` a
// double-click on a pill emits monitorRequested("disks"). All data comes in
// as properties.
ColumnLayout {
    id: panel

    property QtObject theme
    property QtObject feed                // a DiskFeed
    property bool minimal: false
    property string storageUnit: "auto"   // auto GB TB percent
    property string valueFormat: "free"   // free used both
    property bool showIoThroughput: true
    property bool live: false
    property int entranceSerial: 0
    property bool monitorLinks: false
    signal monitorRequested(string tab)

    readonly property int count: feed ? feed.model.count : 0
    readonly property var totals: (feed ? feed.volumes : []).reduce((t, v) => ({ used: t.used + v.usedBytes, size: t.size + v.totalBytes }),
                                                                    { used: 0, size: 0 })

    spacing: minimal ? 8 : 10

    Text {
        visible: !panel.minimal
        Layout.fillWidth: true
        text: !panel.feed ? "" : !panel.theme.skinned ? panel.feed.commentary
            : panel.feed.anyCritical ? panel.theme.skinLine("critical", i18n("STORAGE NEARLY FULL."))
            : panel.theme.skinLine("nominal", i18n("STORAGE NOMINAL."))
        color: panel.theme.commentary
        font { family: panel.theme.mono; pixelSize: 12; bold: true }
        wrapMode: Text.WordWrap
    }
    Rectangle {
        visible: !panel.minimal
        Layout.fillWidth: true
        implicitHeight: 2
        color: panel.theme.dark ? panel.theme.tint(0.35) : panel.theme.ink
    }

    Repeater {
        model: panel.feed ? panel.feed.model : null
        delegate: DiskPillCard {
            required property int index
            required property string label
            required property string mountPoint
            required property int extraMounts
            required property string fsType
            required property string kind
            required property double totalBytes
            required property double usedBytes
            required property double availableBytes
            required property int usedPercentage
            required property double readRate
            required property double writeRate
            required property bool hasIo
            required property bool critical
            Layout.fillWidth: true
            Layout.topMargin: index === 0 && !panel.minimal ? 2 : 0
            theme: panel.theme
            minimal: panel.minimal
            storageUnit: panel.storageUnit
            valueFormat: panel.valueFormat
            live: panel.live
            entranceSerial: panel.entranceSerial
            cascadeIndex: index
            monitorTab: panel.monitorLinks ? "disks" : ""
            onMonitorRequested: tab => panel.monitorRequested(tab)
            volumeLabel: label
            volumeMount: mountPoint
            volumeExtraMounts: extraMounts
            volumeFs: fsType
            volumeKind: kind
            total: totalBytes
            used: usedBytes
            available: availableBytes
            percent: usedPercentage
            readBps: readRate
            writeBps: writeRate
            showIo: hasIo
            showThroughput: panel.showIoThroughput
            isCritical: critical
        }
    }
    Text {
        visible: panel.count === 0
        Layout.fillWidth: true
        Layout.topMargin: 6
        Layout.bottomMargin: 6
        horizontalAlignment: Text.AlignHCenter
        text: i18n("NO SELECTED VOLUMES MOUNTED.")
        color: panel.theme.tint(0.6)
        font { family: panel.theme.mono; pixelSize: 11 }
    }

    RowLayout {
        visible: !panel.minimal && panel.count > 0
        Layout.fillWidth: true
        Layout.topMargin: 2
        Text {
            Layout.fillWidth: true
            text: i18np("%1 VOLUME ONLINE", "%1 VOLUMES ONLINE", panel.count)
            color: panel.theme.cool
            font { family: panel.theme.mono; pixelSize: 10; bold: true; letterSpacing: 0.5 }
        }
        Text {
            text: i18n("TOTAL %1 / %2", Disk.bytes(panel.totals.used), Disk.bytes(panel.totals.size))
            color: panel.theme.tint(0.7)
            font { family: panel.theme.mono; pixelSize: 10; bold: true; letterSpacing: 0.5 }
        }
    }
}
