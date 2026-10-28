import QtQuick
import QtQuick.Layouts
import "../common"

// The body of the power page, without frame or header: the commentary, one
// sliding pill per selected battery (the laptop's own with its live wattage)
// and a mains / power profile footer. Minimal: slim pills only. All data
// comes in as properties.
ColumnLayout {
    id: panel

    property QtObject theme
    property QtObject feed                // a BatteryFeed
    property bool minimal: false
    property bool percentageOnly: false
    property bool lowBlink: true
    property bool showPowerRate: true
    property bool live: false
    property int entranceSerial: 0

    readonly property int count: feed ? feed.model.count : 0

    spacing: minimal ? 8 : 10

    Text {
        visible: !panel.minimal
        Layout.fillWidth: true
        text: panel.feed ? panel.feed.commentary : ""
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
        delegate: BatteryPillCard {
            required property int index
            required property string name
            required property string kind
            required property int percent
            required property bool charging
            required property string status
            required property string detail
            required property bool critical
            required property bool primary
            Layout.fillWidth: true
            Layout.topMargin: index === 0 && !panel.minimal ? 2 : 0
            theme: panel.theme
            minimal: panel.minimal
            percentageOnly: panel.percentageOnly
            lowBlink: panel.lowBlink
            live: panel.live
            entranceSerial: panel.entranceSerial
            cascadeIndex: index
            deviceName: name
            deviceKind: kind
            level: percent
            isCharging: charging
            statusText: status
            detailText: detail
            isCritical: critical
            // The rate belongs to the laptop's own battery.
            watts: primary ? panel.feed.watts : NaN
            onMains: panel.feed.acPlugged
            showPowerRate: panel.showPowerRate
            tipText: !primary || !panel.feed.health ? ""
                   : i18n("HEALTH: %1", panel.feed.health.health >= 0 ? i18n("%1% OF DESIGN CAPACITY", panel.feed.health.health) : i18nc("not available", "N/A"))
                     + "\n" + i18n("CYCLES: %1", panel.feed.health.cycles >= 0 ? panel.feed.health.cycles : i18nc("not available", "N/A"))
        }
    }
    Text {
        visible: panel.count === 0
        Layout.fillWidth: true
        Layout.topMargin: 6
        Layout.bottomMargin: 6
        horizontalAlignment: Text.AlignHCenter
        text: i18n("NO SELECTED BATTERIES REPORTING ON THIS VESSEL.")
        color: panel.theme.tint(0.6)
        font { family: panel.theme.mono; pixelSize: 11 }
        wrapMode: Text.WordWrap
    }

    // ---- footer: mains and power profile ----
    RowLayout {
        visible: !panel.minimal
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 6
        Text {
            Layout.fillWidth: true
            text: panel.feed && panel.feed.acPlugged ? i18n("MAINS: CONNECTED") : i18n("MAINS: OFFLINE")
            color: panel.feed && panel.feed.acPlugged ? panel.theme.cool : panel.theme.tint(0.6)
            font { family: panel.theme.mono; pixelSize: 10; bold: true; letterSpacing: 0.5 }
            elide: Text.ElideRight
        }
        Repeater {
            model: panel.feed ? panel.feed.profiles : []
            delegate: Rectangle {
                required property string modelData
                readonly property bool active: modelData === panel.feed.currentProfile
                implicitWidth: chipText.implicitWidth + 14
                implicitHeight: chipText.implicitHeight + 6
                radius: height / 2
                color: active ? panel.theme.ink : "transparent"
                border.width: panel.theme.dark ? 1 : 2
                border.color: active ? panel.theme.ink : panel.theme.tint(panel.theme.dark ? 0.45 : 1)
                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: modelData === "power-saver" ? i18nc("power profile", "SAVER")
                        : modelData === "performance" ? i18nc("power profile", "PERFORMANCE")
                        : modelData === "balanced" ? i18nc("power profile", "BALANCED") : modelData.toUpperCase()
                    color: parent.active ? panel.theme.bg : panel.theme.ink
                    font { family: panel.theme.mono; pixelSize: 9; bold: true }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (!parent.active) panel.feed.setProfile(parent.modelData)
                }
            }
        }
    }
}
