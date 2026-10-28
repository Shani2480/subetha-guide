import QtQuick
import QtQuick.Layouts
import "../common"

// One hardware component as a Guide drawer pill.
//   cpu: chip glyph, clock / cores, temperature badge, load, load + heat graph, gauge
//   ram: memory stick, used / total, utilisation, usage graph, capacity gauge
//   gpu: graphics card, model + VRAM, temperature badge, load, load + heat graph, core | VRAM split gauge
//   net: Sub-Etha antenna, interface, RX / TX readouts, two-way throughput plot
// Minimal (small): glyph, one line of figures and a slim bar (net: arrows and
// rates). Full (large) adds `detailText`, a line of sub-metrics under the
// header (governor, memory breakdown, clocks, session totals). With
// `sizeToggle` the first row ends in a [ - ] / [ + ] tag that emits
// sizeToggled; the pill animates its height as it switches.
// `tipText` is the technical detail shown in a themed tooltip on hover.
// Net, large: a LAN / WAN identity strip under the plot; clicking an address
// copies it and flashes [COPIED], hovering it shows gateway, CIDR and DNS.
// The border pulses when a chip runs hot or memory is nearly full.
SlidingPillContainer {
    id: card

    property string kind: "cpu"
    property bool minimal: false
    property string title: ""
    property string subtitle: ""
    property string minimalText: ""
    property string detailText: ""        // full: sub-metrics line under the header
    property bool sizeToggle: false       // show the [ - ] / [ + ] tag
    property real tempC: 0                // cpu / gpu: temperature in °C, layered behind the load bar
    property bool tempAlerts: true        // the bar's temperature wash changes colour at the thresholds
    property int tempWarnPercent: 80      // of the 30-100 °C scale
    property int tempCriticalPercent: 90
    readonly property real tempPct: tempC > 0 ? Math.max(0, Math.min(100, (tempC - 30) / 70 * 100)) : 0
    property string tipText: ""           // hover detail for the whole pill
    property string lanText: ""           // net: "192.168.1.91", or "" while unknown
    property string lanIface: ""
    property string wanText: ""           // net: address, "RESOLVING..." or "OFFLINE"
    property string identityTip: ""       // net: gateway, CIDR, DNS
    property string valueText: ""
    property string tempText: ""
    property bool hot: false
    property real percent: 0              // main gauge
    property real secondaryPercent: 0     // gpu: VRAM half of the split gauge
    property bool graphs: true            // the rolling sparklines (full mode)
    property var graphData: []            // main reading, scaled 0..1
    property var graphData2: []           // cpu / gpu: temperature, scaled 0..1
    property var rxHistory: []            // net: bytes/s
    property var txHistory: []
    property string rxText: ""
    property string txText: ""

    signal sizeToggled()

    critical: hot
    animateHeight: true
    verticalPadding: minimal ? 7 : 10
    horizontalPadding: minimal ? 12 : 14

    readonly property color rxColor: theme.netDown
    readonly property color txColor: theme.netUp
    // a skin's sparkline colours, or the load colour as the Guide has it
    readonly property bool skinGraph: theme.sparkline.a > 0
    function loadColor(p) { return p >= 85 ? theme.low : p >= 50 ? theme.mid : theme.high }

    readonly property var glyphs: ({
        cpu: "M7 7 H17 V17 H7 Z M9.5 9.5 H14.5 V14.5 H9.5 Z M9 7 V4 M12 7 V4 M15 7 V4 M9 17 V20 M12 17 V20 M15 17 V20 M7 9 H4 M7 12 H4 M7 15 H4 M17 9 H20 M17 12 H20 M17 15 H20",
        ram: "M2 7 H22 V15 H2 Z M5 9.5 H8 V12.5 H5 Z M10.5 9.5 H13.5 V12.5 H10.5 Z M16 9.5 H19 V12.5 H16 Z M4 15 V17.5 M7 15 V17.5 M10 15 V17.5 M14 15 V17.5 M17 15 V17.5 M20 15 V17.5",
        gpu: "M2 4 V19 M2 6 H21 V16 H2 M5 16 V18.5 H14 V16 M7 11 A3 3 0 1 0 13 11 A3 3 0 1 0 7 11 Z M16 9 H18.5 M16 11 H18.5 M16 13 H18.5",
        net: "M12 14 V21 M8.5 21 H15.5 M11 13 A1 1 0 1 0 13 13 A1 1 0 1 0 11 13 Z M9 10.5 A4 4 0 0 1 15 10.5 M6.5 8 A7.5 7.5 0 0 1 17.5 8 M4 5.5 A11 11 0 0 1 20 5.5",
        down: "M12 4 V19 M6.5 13.5 L12 19 L17.5 13.5",
        up: "M12 20 V5 M6.5 10.5 L12 5 L17.5 10.5"
    })

    ColumnLayout {
        width: parent.width
        spacing: card.minimal ? 5 : 8

        HoverHandler { id: pillHover }
        SubEthaTooltip {
            theme: card.theme
            shown: pillHover.hovered && !identityHover.hovered
            text: card.tipText
        }

        // ---- minimal ----
        RowLayout {
            visible: card.minimal
            Layout.fillWidth: true
            spacing: 8
            VectorGlyph {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                path: card.glyphs[card.kind]
                color: card.theme.ink
                strokeWidth: card.theme.dark ? 1.6 : 2
            }
            Text {
                visible: card.kind !== "net"
                Layout.fillWidth: true
                text: card.minimalText
                color: card.hot ? card.alertInk : card.theme.ink
                font { family: card.theme.mono; pixelSize: 11; bold: true }
                elide: Text.ElideRight
            }
            // net: ↓ rx  ↑ tx with vector arrows
            RowLayout {
                visible: card.kind === "net"
                Layout.fillWidth: true
                spacing: 4
                VectorGlyph { Layout.preferredWidth: 13; Layout.preferredHeight: 13; path: card.glyphs.down; color: card.rxColor; strokeWidth: 2.4 }
                Text { text: card.rxText; color: card.rxColor; font { family: card.theme.mono; pixelSize: 11; bold: true } }
                Item { implicitWidth: 8 }
                VectorGlyph { Layout.preferredWidth: 13; Layout.preferredHeight: 13; path: card.glyphs.up; color: card.txColor; strokeWidth: 2.4 }
                Text { text: card.txText; color: card.txColor; font { family: card.theme.mono; pixelSize: 11; bold: true } }
                Item { Layout.fillWidth: true }
            }
            SizeToggle {
                visible: card.sizeToggle
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                theme: card.theme
                small: true
                onToggled: card.sizeToggled()
            }
        }
        Gauge {
            visible: card.minimal && card.kind === "ram"
            Layout.fillWidth: true
            Layout.bottomMargin: 2
            segments: 20
            segmentHeight: 6
            value: card.percent
        }
        DualMetricBar {   // cpu / gpu: load over temperature on one track
            visible: card.minimal && (card.kind === "cpu" || card.kind === "gpu")
            Layout.fillWidth: true
            Layout.bottomMargin: 2
            segments: 20          // as the small RAM gauge
            segmentHeight: 6
            theme: card.theme
            live: card.live
            usageFraction: card.percent / 100
            tempValue: card.tempC
            alerts: card.tempAlerts
            warnPercent: card.tempWarnPercent
            criticalPercent: card.tempCriticalPercent
        }

        // ---- full: header row ----
        RowLayout {
            visible: !card.minimal
            Layout.fillWidth: true
            spacing: 12

            VectorGlyph {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                path: card.glyphs[card.kind]
                color: card.theme.ink
                strokeWidth: card.theme.dark ? 1.5 : 1.8
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: card.title
                    color: card.theme.ink
                    font { family: card.theme.sans; pixelSize: 13; bold: true; letterSpacing: 0.4 }
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: card.subtitle
                    color: card.theme.tint(card.theme.dark ? 0.7 : 0.75)
                    font { family: card.theme.mono; pixelSize: 10 }
                    elide: Text.ElideRight
                }
            }
            // cpu / gpu: temperature badge
            Rectangle {
                visible: card.tempText !== ""
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: tempLabel.implicitWidth + 12
                implicitHeight: tempLabel.implicitHeight + 6
                radius: card.theme.dark ? 0 : height / 2
                color: card.hot ? card.alertInk : "transparent"
                border.width: card.theme.dark ? 1 : 1.5
                border.color: card.hot ? card.alertInk : card.theme.tint(card.theme.dark ? 0.6 : 1)
                Text {
                    id: tempLabel
                    anchors.centerIn: parent
                    text: card.tempText
                    color: card.hot ? (card.theme.dark ? card.theme.bg : "#FFFFFF") : card.theme.ink
                    font { family: card.theme.mono; pixelSize: 11; bold: true }
                }
            }
            Text {
                visible: card.kind !== "net"
                Layout.alignment: Qt.AlignVCenter
                text: card.valueText
                color: card.hot ? card.alertInk : card.theme.ink
                font { family: card.theme.mono; pixelSize: 24; bold: true }
            }
            // net: live RX / TX readouts
            ColumnLayout {
                visible: card.kind === "net"
                Layout.alignment: Qt.AlignVCenter
                spacing: 1
                Text {
                    Layout.alignment: Qt.AlignRight
                    text: i18n("RX: %1", card.rxText)
                    color: card.rxColor
                    font { family: card.theme.mono; pixelSize: 12; bold: true }
                }
                Text {
                    Layout.alignment: Qt.AlignRight
                    text: i18n("TX: %1", card.txText)
                    color: card.txColor
                    font { family: card.theme.mono; pixelSize: 12; bold: true }
                }
            }
            SizeToggle {
                visible: card.sizeToggle
                theme: card.theme
                small: false
                onToggled: card.sizeToggled()
            }
        }
        Text {   // full: sub-metrics
            visible: !card.minimal && card.detailText !== ""
            Layout.fillWidth: true
            text: card.detailText
            color: card.theme.tint(card.theme.dark ? 0.6 : 0.7)
            font { family: card.theme.mono; pixelSize: 10; bold: true; letterSpacing: 0.3 }
            elide: Text.ElideRight
        }

        // ---- full: bottom ----
        Item {   // load history, with the temperature traced over it
            visible: card.graphs && !card.minimal && card.kind !== "net"
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            SparklineGraph {
                anchors.fill: parent
                historyData: card.graphData
                strokeColor: card.skinGraph ? card.theme.sparkline : card.loadColor(card.percent)
                fillColor: card.skinGraph && card.theme.sparklineFill.a > 0 ? card.theme.sparklineFill
                         : Qt.rgba(strokeColor.r, strokeColor.g, strokeColor.b, 0.18)
                lineWidth: card.skinGraph ? 2 : 1.5
            }
            SparklineGraph {
                anchors.fill: parent
                visible: card.graphData2.length > 1
                historyData: card.graphData2
                strokeColor: card.hot ? card.alertInk : card.theme.tint(card.theme.dark ? 0.55 : 0.6)
                fillColor: "transparent"
                lineWidth: 1
            }
        }
        Gauge {
            visible: !card.minimal && card.kind === "ram"
            Layout.fillWidth: true
            Layout.bottomMargin: 2
            segments: 24
            segmentHeight: 9
            value: card.percent
        }
        // cpu / gpu: the key for the layered bar, then the bar
        RowLayout {
            visible: !card.minimal && (card.kind === "cpu" || card.kind === "gpu")
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: i18n("LOAD %1%", Math.round(card.percent))
                color: card.loadColor(card.percent)   // the colour of the solid fill
                font { family: card.theme.mono; pixelSize: 9; bold: true }
            }
            Text {
                visible: card.tempC > 0
                text: i18n("TEMP %1", card.tempText)
                color: card.tempAlerts && card.tempPct >= card.tempCriticalPercent ? card.alertInk
                     : card.tempAlerts && card.tempPct >= card.tempWarnPercent ? "#FF8A1A"
                     : card.theme.dark ? card.theme.amber : "#B07800"
                opacity: 0.9
                font { family: card.theme.mono; pixelSize: 9; bold: true }
            }
            Item { Layout.fillWidth: true }
        }
        DualMetricBar {
            visible: !card.minimal && (card.kind === "cpu" || card.kind === "gpu")
            Layout.fillWidth: true
            Layout.bottomMargin: card.kind === "gpu" ? 0 : 2
            segments: 24          // as the large RAM gauge
            segmentHeight: 9
            theme: card.theme
            live: card.live
            usageFraction: card.percent / 100
            tempValue: card.tempC
            alerts: card.tempAlerts
            warnPercent: card.tempWarnPercent
            criticalPercent: card.tempCriticalPercent
        }
        RowLayout {   // gpu: VRAM gauge
            visible: !card.minimal && card.kind === "gpu"
            Layout.fillWidth: true
            Layout.bottomMargin: 2
            spacing: 6
            Text { text: "VRAM"; color: card.theme.tint(0.6); font { family: card.theme.mono; pixelSize: 9; bold: true } }
            Gauge { Layout.fillWidth: true; segments: 24; segmentHeight: 6; value: card.secondaryPercent }
        }
        Item {   // net: RX above the baseline, TX hanging below, on one shared scale
            visible: card.graphs && !card.minimal && card.kind === "net"
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            Layout.bottomMargin: 2
            readonly property real peak: Math.max(1, Math.max.apply(null, card.rxHistory.concat(card.txHistory).concat([0])))
            SparklineGraph {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: parent.height / 2 - 1
                historyData: card.rxHistory.map(v => v / parent.peak)
                strokeColor: card.rxColor
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 1
                color: card.theme.tint(0.35)
            }
            SparklineGraph {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: parent.height / 2 - 1
                historyData: card.txHistory.map(v => v / parent.peak)
                strokeColor: card.txColor
                inverted: true
            }
        }

        // net: LAN | WAN identity strip (stacked when narrow); an address copies on click
        GridLayout {
            visible: !card.minimal && card.kind === "net"
            Layout.fillWidth: true
            Layout.bottomMargin: 2
            columns: card.width >= 440 ? 2 : 1
            columnSpacing: 10
            rowSpacing: 3
            HoverHandler { id: identityHover }
            SubEthaTooltip {
                theme: card.theme
                shown: identityHover.hovered
                text: card.identityTip
            }
            Address {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                label: i18n("LAN IP")
                value: card.lanText || i18nc("@info network state", "OFFLINE")
                tag: card.lanIface.toUpperCase()
                copyable: card.lanText !== ""
            }
            Address {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                label: i18n("WAN IP")
                value: card.wanText
                tag: "SEC-ZZ9"
                copyable: /^[0-9a-fA-F:.]+$/.test(card.wanText)
            }
        }
    }

    TextEdit { id: clipboard; visible: false }   // copy() needs a text item to go through
    function copyText(t) { clipboard.text = t; clipboard.selectAll(); clipboard.copy(); clipboard.text = "" }

    // One address readout: "LAN IP: 192.168.1.91 [WLAN0]", flashing a
    // [COPIED] badge for a moment after a click has copied the address.
    component Address: Item {
        id: address
        property string label: ""
        property string value: ""
        property string tag: ""
        property bool copyable: false
        implicitHeight: addressText.implicitHeight
        Text {
            id: addressText
            width: parent.width
            text: address.label + ": " + address.value + (address.tag ? " [" + address.tag + "]" : "")
            color: copyArea.containsMouse && address.copyable ? card.theme.accent : card.theme.tint(card.theme.dark ? 0.8 : 0.85)
            font { family: card.theme.mono; pixelSize: 10; bold: true }
            elide: Text.ElideRight
            opacity: copied.running ? 0 : 1
        }
        Rectangle {   // [COPIED]
            visible: copied.running
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: copiedText.implicitWidth + 10
            implicitHeight: copiedText.implicitHeight + 2
            radius: card.theme.dark ? 0 : height / 2
            color: card.theme.ink
            Text {
                id: copiedText
                anchors.centerIn: parent
                text: i18n("[COPIED]")
                color: card.theme.bg
                font { family: card.theme.mono; pixelSize: 9; bold: true }
            }
        }
        Timer { id: copied; interval: 1100 }
        MouseArea {
            id: copyArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: address.copyable
            cursorShape: Qt.PointingHandCursor
            onClicked: { card.copyText(address.value); copied.restart() }
        }
    }

    // Segmented gauge; fill colour follows the load (good / busy / hot).
    component Gauge: Row {
        id: gauge
        property int segments: 20
        property real segmentHeight: 8
        property real value: 0
        readonly property int filled: Math.round(Math.max(0, Math.min(100, value)) / 100 * segments)
        readonly property color fill: card.loadColor(value)
        spacing: 2
        Repeater {
            model: gauge.segments
            Rectangle {
                required property int index
                readonly property bool on: index < gauge.filled
                width: (gauge.width - gauge.spacing * (gauge.segments - 1)) / gauge.segments
                height: gauge.segmentHeight
                radius: card.theme.dark ? 0 : Math.min(2, height / 2)
                color: on ? gauge.fill : "transparent"
                border.width: 1
                border.color: on ? gauge.fill : card.theme.tint(card.theme.dark ? 0.3 : 0.45)
            }
        }
    }
}
