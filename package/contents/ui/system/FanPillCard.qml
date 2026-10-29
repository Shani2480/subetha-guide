import QtQuick
import QtQuick.Layouts
import "code/system.js" as Sys
import "../common"

// The cooling fans as one Guide drawer pill: a wireframe fan whose blades
// spin faster with the fastest fan, COOLING ARRAYS with a per-fan breakdown,
// the top RPM, and a segmented tachometer per fan. Minimal (small): the
// spinning glyph and one line of readings. With `sizeToggle` the first row
// ends in a [ - ] / [ + ] tag that emits sizeToggled.
SlidingPillContainer {
    id: card

    property bool minimal: false
    property var fans: []                 // [{ label, rpm }], fastest decides the spin
    property bool showPercent: false      // readings as % of maxRpm instead of RPM
    property int maxRpm: 6000             // full speed, for percentages and the gauge
    property bool graphs: true            // per-fan RPM sparklines (full mode)
    property var histories: ({})          // fan label -> RPM samples
    property bool sizeToggle: false

    signal sizeToggled()
    animateHeight: true

    verticalPadding: minimal ? 7 : 10
    leadIcon: minimal ? theme.icon("fan") : ""      // list rows: the fan in the row's left column
    leadGlyph: minimal ? framePath + " " + bladesPath : ""
    horizontalPadding: minimal ? 12 : 14

    readonly property real topRpm: fans.length ? Math.max.apply(null, fans.map(f => f.rpm)) : 0
    readonly property real duty: Math.min(100, 100 * topRpm / Math.max(1, maxRpm))
    function reading(rpm) {
        return showPercent ? Math.round(Math.min(100, 100 * rpm / Math.max(1, maxRpm))) + "%" : Sys.rpm(rpm)
    }
    function speedColor(p) { return p >= 85 ? theme.low : p >= 50 ? theme.mid : theme.high }

    readonly property string framePath: "M3 3 H21 V21 H3 Z M3 6 H6 V3 M18 3 V6 H21 M21 18 H18 V21 M6 21 V18 H3"
    readonly property string bladesPath: "M11 12 A1 1 0 1 0 13 12 A1 1 0 1 0 11 12 Z "
        + "M12 11 C12 7 13.5 5.5 16 6 C17 8 15 10.5 12.5 11.2 M13 12 C17 12 18.5 13.5 18 16 C16 17 13.5 15 12.8 12.5 "
        + "M12 13 C12 17 10.5 18.5 8 18 C7 16 9 13.5 11.5 12.8 M11 12 C7 12 5.5 10.5 6 8 C8 7 10.5 9 11.2 11.5"

    ColumnLayout {
        width: parent.width
        spacing: card.minimal ? 5 : 8

        RowLayout {
            Layout.fillWidth: true
            spacing: card.minimal ? 8 : 12

            Item {   // static frame, spinning blades
                visible: !card.leading
                Layout.preferredWidth: card.minimal ? 18 : 30
                Layout.preferredHeight: Layout.preferredWidth
                VectorGlyph {
                    anchors.fill: parent
                    path: card.framePath
                    source: card.theme.icon("fan")
                    color: card.theme.tint(card.minimal ? 0 : 0.6)
                    strokeWidth: card.theme.stroke(1.3, 1.6)
                }
                VectorGlyph {
                    id: blades
                    visible: card.theme.icon("fan") === ""
                    anchors.fill: parent
                    path: card.bladesPath
                    color: card.theme.ink
                    strokeWidth: card.theme.stroke(1.5, 1.8)
                    // One turn takes 30000 / RPM ms, never faster than 400 ms.
                    NumberAnimation on rotation {
                        running: card.live && card.topRpm > 0
                        from: 0; to: 360
                        loops: Animation.Infinite
                        duration: Math.max(400, 30000 / Math.max(1, card.topRpm))
                    }
                }
            }

            // minimal: FANS 2400 RPM · CPU / 2600 RPM · GPU
            Text {
                visible: card.minimal
                Layout.fillWidth: true
                text: card.fans.length === 0 ? i18n("FANS --")
                    : i18n("FANS %1", card.fans.map(f => card.reading(f.rpm) + " · " + f.label).join(" / "))
                color: card.theme.ink
                font { family: card.theme.rowFamily; pixelSize: card.theme.rowSize(11); bold: card.theme.rowBold }
                elide: Text.ElideRight
            }

            ColumnLayout {
                visible: !card.minimal
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: card.theme.lex("fansTitle", i18n("COOLING ARRAYS"), i18n("FANS"))
                    color: card.theme.ink
                    font { family: card.theme.sans; pixelSize: 13; bold: true; letterSpacing: 0.4 }
                }
                Text {
                    Layout.fillWidth: true
                    text: card.fans.length === 0 ? i18n("NO FAN TELEMETRY")
                        : card.fans.map(f => f.label + ": " + card.reading(f.rpm)).join(" · ")
                    color: card.theme.tint(card.theme.dark ? 0.7 : 0.75)
                    font { family: card.theme.mono; pixelSize: 10 }
                    elide: Text.ElideRight
                }
            }
            Text {
                visible: !card.minimal
                Layout.alignment: Qt.AlignVCenter
                text: card.reading(card.topRpm)
                color: card.theme.ink
                font { family: card.theme.mono; pixelSize: card.showPercent ? 24 : 20; bold: true }
            }
            SizeToggle {
                visible: card.sizeToggle
                Layout.alignment: card.minimal ? (Qt.AlignVCenter | Qt.AlignRight) : (Qt.AlignTop | Qt.AlignRight)
                theme: card.theme
                small: card.minimal
                onToggled: card.sizeToggled()
            }
        }

        Item {   // one RPM trace per fan, on the full-speed scale
            visible: card.graphs && !card.minimal && card.fans.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            Repeater {
                model: card.fans
                SparklineGraph {
                    required property var modelData
                    required property int index
                    anchors.fill: parent
                    historyData: (card.histories[modelData.label] || []).map(v => v / Math.max(1, card.maxRpm))
                    strokeColor: card.theme.taskGraphs ? card.theme.osColor("controls", index === 0 ? "graphDown" : "graphUp", index === 0 ? "#00C000" : "#E07000")
                               : index === 0 ? card.speedColor(card.duty) : card.theme.cool
                    fillColor: index === 0 && !card.theme.taskGraphs ? Qt.rgba(strokeColor.r, strokeColor.g, strokeColor.b, 0.18) : "transparent"
                    lineWidth: index === 0 && !card.theme.taskGraphs ? 1.5 : 1
                    TaskGrid { z: -1; anchors.fill: parent; theme: card.theme; visible: card.theme.taskGraphs && index === 0 }
                }
            }
        }

        Repeater {   // one tachometer per fan (one overall gauge when no fan reports)
            model: card.minimal ? 0 : Math.max(1, card.fans.length)
            RowLayout {
                id: tachRow
                required property int index
                readonly property var fan: card.fans[index] || { label: i18n("FANS"), rpm: 0 }
                readonly property real duty: Math.min(100, 100 * fan.rpm / Math.max(1, card.maxRpm))
                Layout.fillWidth: true
                Layout.bottomMargin: index === Math.max(1, card.fans.length) - 1 ? 2 : 0
                spacing: 6
                Text {
                    Layout.preferredWidth: 46
                    text: tachRow.fan.label
                    color: card.theme.tint(0.6)
                    font { family: card.theme.mono; pixelSize: 9; bold: true }
                    elide: Text.ElideRight
                }
                DynamicMetricGauge {
                    id: tach
                    Layout.fillWidth: true
                    Layout.preferredHeight: 7
                    theme: card.theme
                    shape: card.theme.skinned ? card.theme.gaugeShape : "segmented"
                    segments: 20
                    value: Math.round(tachRow.duty / 100 * segments) / segments
                    fillColor: card.speedColor(tachRow.duty)
                    outlined: false
                    live: card.theme.live
                }
                Text {
                    Layout.preferredWidth: 62
                    horizontalAlignment: Text.AlignRight
                    text: card.reading(tachRow.fan.rpm)
                    color: card.theme.ink
                    font { family: card.theme.mono; pixelSize: 9; bold: true }
                }
            }
        }
    }
}
