import QtQuick
import QtQuick.Layouts
import "code/power.js" as Power
import "../common"

// One battery as a Guide pill. Full: device glyph, name, status and detail,
// the big percentage and a ten-segment fuel gauge. Minimal: glyph, name,
// percentage and a slim meter. percentageOnly drops the gauges. Below 15% (and not charging) the border pulses amber/red
// and DEPLETION IMMINENT appears; with `lowBlink` the percentage and the badge
// blink on and off like the disk's CRITICAL QUOTA EXCEEDED. `tipText` (the laptop battery's health and
// cycle count) shows in a themed tooltip on hover.
SlidingPillContainer {
    id: card

    property bool minimal: false
    property bool percentageOnly: false
    property bool lowBlink: true          // blink the percentage and DEPLETION IMMINENT while critical

    // Blinks on and off while critical and on screen (the disk warning's rhythm).
    property real flash: 1
    SequentialAnimation on flash {
        running: card.isCritical && card.lowBlink && card.live && card.theme.alertMotion
        loops: Animation.Infinite
        onRunningChanged: if (!running) card.flash = 1
        PauseAnimation { duration: 700 }
        NumberAnimation { to: 0.15; duration: 120 }
        PauseAnimation { duration: 280 }
        NumberAnimation { to: 1; duration: 120 }
    }
    property string deviceName: ""
    property string deviceKind: "other"   // laptop mouse keyboard headset phone controller pen ups other
    property int level: 0
    property bool isCharging: false
    property string statusText: ""
    property string detailText: ""
    property bool isCritical: false
    property real watts: NaN              // signed charge rate; NaN: not reported for this device
    property bool onMains: false
    property bool showPowerRate: true
    property string tipText: ""
    readonly property string rateState: showPowerRate ? Power.rateState(watts, onMains) : ""
    readonly property color rateColor: rateState === "charging" ? theme.high
                                     : rateState === "drain" ? (theme.dark || theme.skinned ? theme.amber : "#B07800")
                                     : theme.tint(0.6)

    critical: isCritical
    verticalPadding: minimal ? 7 : 10
    horizontalPadding: minimal ? 12 : 14

    readonly property color levelColor: isCharging ? theme.cool : theme.level(level)

    readonly property var glyphs: ({
        laptop: "M5 5 H19 V15 H5 Z M2 18 H22 L20.5 20 H3.5 Z M10 18 V18.8 H14 V18",
        mouse: "M12 3 C8.5 3 6 5.5 6 9.5 V15 C6 18.8 8.6 21 12 21 C15.4 21 18 18.8 18 15 V9.5 C18 5.5 15.5 3 12 3 Z M12 3 V10 M6 10 H18 M12 5.5 V7.5",
        keyboard: "M2 7 H22 V17 H2 Z M5 10 H6 M8.5 10 H9.5 M12 10 H13 M15.5 10 H16.5 M18.5 10 H19 M5 12.5 H7 M9.5 12.5 H10.5 M13 12.5 H14 M16.5 12.5 H19 M7 14.8 H17",
        headset: "M4 15 V12 A8 8 0 0 1 20 12 V15 M3 14 H7 V20.5 H3 Z M17 14 H21 V20.5 H17 Z M19 20.5 Q19 22.5 14.5 22.5",
        phone: "M7 2 H17 V22 H7 Z M7 5 H17 M7 18.5 H17 M11 20.3 H13",
        controller: "M7 7 H17 C20.5 7 22 11 22 15 C22 18.5 19.5 19.5 17.5 17.5 L15.5 15 H8.5 L6.5 17.5 C4.5 19.5 2 18.5 2 15 C2 11 3.5 7 7 7 Z M7.5 9.5 V13.5 M5.5 11.5 H9.5 M15.5 10.5 H16.5 M18 12.5 H19",
        pen: "M4 20 L5 15 L16 4 L20 8 L9 19 Z M14 6 L18 10 M5 15 L9 19",
        ups: "M4 3 H20 V21 H4 Z M8 7 H16 M8 10 H16 M13 12.5 L10.5 16 H13.5 L11 19.5",
        other: "M3 7 H19 V17 H3 Z M19 10 H21.5 V14 H19 M6 10 V14 M9 10 V14 M12 10 V14"
    })

    // While charging the next empty gauge segment blinks in the charging colour.
    property real blink: 1
    SequentialAnimation on blink {
        running: card.isCharging && card.level < 100 && card.live
        loops: Animation.Infinite
        onRunningChanged: if (!running) card.blink = 1
        NumberAnimation { to: 0.2; duration: 500 }
        NumberAnimation { to: 1; duration: 500 }
    }

    ColumnLayout {
        width: parent.width

        HoverHandler { id: pillHover }
        SubEthaTooltip { theme: card.theme; shown: pillHover.hovered; text: card.tipText }
        spacing: 5

        // ---- minimal: name and percentage over a slim meter ----
        RowLayout {
            visible: card.minimal
            Layout.fillWidth: true
            spacing: 8
            VectorGlyph {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                path: card.glyphs[card.deviceKind] || card.glyphs.other
                color: card.theme.ink
                strokeWidth: card.theme.stroke(1.6, 2)
            }
            Text {
                Layout.fillWidth: true
                text: card.deviceName
                color: card.isCritical ? card.alertInk : card.theme.ink
                font { family: card.theme.sans; pixelSize: 12; bold: true; letterSpacing: 0.4 }
                elide: Text.ElideRight
            }
            Text {   // minimal wattage: "+45.2 W"
                visible: card.rateState !== ""
                text: Power.rateWatts(card.watts, card.onMains)
                color: card.rateColor
                font { family: card.theme.mono; pixelSize: 11; bold: true }
            }
            Text {
                text: card.isCharging ? i18nc("charging, battery percent", "CHG %1%", card.level) : card.level + "%"
                opacity: card.isCritical ? card.flash : 1
                color: card.isCritical ? card.alertInk : card.isCharging ? card.theme.cool : card.theme.ink
                font { family: card.theme.mono; pixelSize: 12; bold: true }
            }
        }
        Gauge {
            visible: card.minimal && !card.percentageOnly
            Layout.fillWidth: true
            Layout.bottomMargin: 2
            segments: 20
            segmentHeight: 6
            stretch: true
        }

        // ---- full ----
        RowLayout {
            visible: !card.minimal
            Layout.fillWidth: true
            Layout.bottomMargin: 2
            spacing: 12

            VectorGlyph {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                path: card.glyphs[card.deviceKind] || card.glyphs.other
                color: card.theme.ink
                strokeWidth: card.theme.stroke(1.5, 1.8)
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: card.deviceName
                    color: card.theme.ink
                    font { family: card.theme.sans; pixelSize: 13; bold: true; letterSpacing: 0.4 }
                    elide: Text.ElideRight
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Rectangle {
                        visible: card.isCritical
                        opacity: card.flash
                        implicitWidth: warnText.implicitWidth + 10
                        implicitHeight: warnText.implicitHeight + 4
                        radius: card.theme.skinned ? Math.min(height / 2, card.theme.pillRadius) : card.theme.dark ? 0 : height / 2
                        color: card.alertInk
                        Text {
                            id: warnText
                            anchors.centerIn: parent
                            text: i18n("DEPLETION IMMINENT")
                            color: card.theme.dark ? card.theme.bg : "#FFFFFF"
                            font { family: card.theme.mono; pixelSize: 9; bold: true }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: card.statusText
                        color: card.isCharging ? card.theme.cool : card.theme.tint(card.theme.dark ? 0.75 : 0.8)
                        font { family: card.theme.mono; pixelSize: 10; bold: card.isCharging }
                        elide: Text.ElideRight
                    }
                }
                Text {   // live wattage
                    visible: card.rateState !== ""
                    Layout.fillWidth: true
                    text: Power.rateText(card.watts, card.onMains)
                    color: card.rateColor
                    font { family: card.theme.mono; pixelSize: 11; bold: true }
                    elide: Text.ElideRight
                }
                Text {
                    visible: card.detailText !== ""
                    Layout.fillWidth: true
                    text: card.detailText
                    color: card.theme.tint(0.5)
                    font { family: card.theme.mono; pixelSize: 9 }
                    elide: Text.ElideRight
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 4
                Text {
                    Layout.alignment: Qt.AlignRight
                    text: card.level + "%"
                    opacity: card.isCritical ? card.flash : 1
                    color: card.isCritical ? card.alertInk : card.theme.ink
                    font { family: card.theme.mono; pixelSize: 24; bold: true }
                }
                Gauge {
                    visible: !card.percentageOnly
                    Layout.alignment: Qt.AlignRight
                    segments: 10
                    segmentHeight: 10
                }
            }
        }
    }

    // Segmented fuel gauge; `stretch` spreads the segments over the full width.
    component Gauge: Item {
        id: gauge
        property int segments: 10
        property real segmentHeight: 10
        property bool stretch: false
        readonly property int filled: Math.ceil(card.level / (100 / segments))
        implicitWidth: stretch ? 0 : segments * 9 - 2
        implicitHeight: segmentHeight
        DynamicMetricGauge {
            width: gauge.width; height: gauge.segmentHeight
            theme: card.theme
            shape: card.theme.skinned ? card.theme.gaugeShape : "segmented"
            segments: gauge.segments
            blockWidth: gauge.stretch ? 0 : 7
            value: gauge.filled / gauge.segments
            fillColor: card.levelColor
            outlined: false
            pulseIndex: card.isCharging ? gauge.filled : -1
            pulseOpacity: 0.6 * card.blink
            live: card.theme.live
        }
    }
}
