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
// `tipText` is the technical detail shown in a themed tooltip on hover, with
// a double-click hint while the pill links to a monitor tab (`monitorTab`).
// Net, large: a LAN / WAN identity strip under the plot; clicking an address
// copies it and flashes [COPIED], hovering it shows gateway, CIDR and DNS.
// Alerts (`tempLevel`, `loadLevel`, from the AlertManager; the pill takes the
// higher): a severity pip before the title, a static accent dot when
// nominal, an amber [WARN] at a warning, a crimson [CRITICAL: <figure>]
// blinking every 300 ms when critical; the tripped figure turns amber or
// crimson and, on the CRT terminal and glitch skins, jitters a pixel now and
// then; the pill's border and halo follow (SlidingPillContainer).
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
    property int tempLevel: 0             // cpu / gpu: 0 nominal, 1 warning, 2 critical
    property int loadLevel: 0             // 0 nominal, 2 critical
    property string criticalText: ""      // the figure in [CRITICAL: ...]
    property string tipText: ""           // hover detail for the whole pill
    property string lanText: ""           // net: "192.168.1.91", or "" while unknown
    property string lanIface: ""
    property string wanText: ""           // net: address, "RESOLVING..." or "OFFLINE"
    property string identityTip: ""       // net: gateway, CIDR, DNS
    property string valueText: ""
    property string tempText: ""
    readonly property bool hot: alertLevel === 2
    property real percent: 0              // main gauge
    property real secondaryPercent: 0     // gpu: VRAM half of the split gauge
    property bool graphs: true            // the rolling sparklines (full mode)
    property var graphData: []            // main reading, scaled 0..1
    property var graphData2: []           // cpu / gpu: temperature, scaled 0..1
    property var rxHistory: []            // net: bytes/s
    property var txHistory: []
    property string rxText: ""
    property string txText: ""
    property var coreHistories: []        // cpu: one history (0..1) per core, if the feed has them

    signal sizeToggled()

    alertLevel: Math.max(tempLevel, loadLevel)
    tint: theme.sectionTint(({ cpu: "cpu", gpu: "gpu", ram: "memory", net: "network" })[kind])
    animateHeight: true
    verticalPadding: minimal ? 7 : 10
    horizontalPadding: minimal ? 12 : 14

    // an analog-dial skin: cpu load and gpu temperature on a round meter beside the figures
    readonly property bool dialed: !minimal && theme.skinned && theme.gaugeShape === "analog-dial" && (kind === "cpu" || kind === "gpu")
    // ...or as small cartoon half-dials: usage, speed and temperature for the cpu, load for the gpu
    readonly property bool semiDials: dialed && theme.controls.dialStyle === "semicircle"
    property real speedFraction: -1       // cpu: clock over its maximum, 0..1; below 0 unknown (the load stands in)
    // a skin's own picture for this component, if it ships one
    readonly property string skinIcon: theme.icon(kind === "net" ? "netDown" : kind)
    readonly property color rxColor: theme.netDown
    readonly property color txColor: theme.netUp
    // a skin's sparkline colours, or the load colour as the Guide has it
    readonly property bool skinGraph: theme.sparkline.a > 0
    function loadColor(p) { return p >= 85 ? theme.low : p >= 50 ? theme.mid : theme.high }
    function levelInk(level, resting) { return level === 2 ? theme.critColor : level === 1 ? theme.warnColor : resting }

    // motion at a critical alert: the pip blinks, the figure jitters
    readonly property bool alertMoving: theme.alertMotion && live && alertLevel === 2
    property bool blinkOn: true
    Timer {
        interval: 300
        repeat: true
        running: card.alertMoving
        onTriggered: card.blinkOn = !card.blinkOn
        onRunningChanged: if (!running) card.blinkOn = true
    }
    property real jitterY: 0
    SequentialAnimation on jitterY {
        running: card.alertMoving && card.theme.alertJitter
        loops: Animation.Infinite
        onRunningChanged: if (!running) card.jitterY = 0
        PauseAnimation { duration: 1100 }
        PropertyAction { value: -1 }
        PauseAnimation { duration: 70 }
        PropertyAction { value: 0 }
        PauseAnimation { duration: 260 }
        PropertyAction { value: -1 }
        PauseAnimation { duration: 50 }
        PropertyAction { value: 0 }
    }

    readonly property var glyphs: ({
        cpu: "M7 7 H17 V17 H7 Z M9.5 9.5 H14.5 V14.5 H9.5 Z M9 7 V4 M12 7 V4 M15 7 V4 M9 17 V20 M12 17 V20 M15 17 V20 M7 9 H4 M7 12 H4 M7 15 H4 M17 9 H20 M17 12 H20 M17 15 H20",
        ram: "M2 7 H22 V15 H2 Z M5 9.5 H8 V12.5 H5 Z M10.5 9.5 H13.5 V12.5 H10.5 Z M16 9.5 H19 V12.5 H16 Z M4 15 V17.5 M7 15 V17.5 M10 15 V17.5 M14 15 V17.5 M17 15 V17.5 M20 15 V17.5",
        gpu: "M2 4 V19 M2 6 H21 V16 H2 M5 16 V18.5 H14 V16 M7 11 A3 3 0 1 0 13 11 A3 3 0 1 0 7 11 Z M16 9 H18.5 M16 11 H18.5 M16 13 H18.5",
        net: "M12 14 V21 M8.5 21 H15.5 M11 13 A1 1 0 1 0 13 13 A1 1 0 1 0 11 13 Z M9 10.5 A4 4 0 0 1 15 10.5 M6.5 8 A7.5 7.5 0 0 1 17.5 8 M4 5.5 A11 11 0 0 1 20 5.5",
        down: theme.chevrons ? "M6 9 L12 15 L18 9" : "M12 4 V19 M6.5 13.5 L12 19 L17.5 13.5",
        up: theme.chevrons ? "M6 15 L12 9 L18 15" : "M12 20 V5 M6.5 10.5 L12 5 L17.5 10.5"
    })

    ColumnLayout {
        width: parent.width
        spacing: card.minimal ? 5 : 8

        HoverHandler { id: pillHover }
        SubEthaTooltip {
            theme: card.theme
            shown: pillHover.hovered && !identityHover.hovered
            text: card.tipText + (card.monitorTab && card.tipText ? "\n" + i18n("DOUBLE-CLICK: OPEN IN SYSTEM MONITOR") : "")
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
                source: card.skinIcon
                color: card.theme.ink
                strokeWidth: card.theme.stroke(1.6, 2)
            }
            SeverityPip { visible: card.alertLevel > 0; compact: true }
            Text {
                visible: card.kind !== "net"
                Layout.fillWidth: true
                text: card.minimalText
                color: card.levelInk(card.alertLevel, card.theme.ink)
                font { family: card.theme.mono; pixelSize: 11; bold: true }
                elide: Text.ElideRight
            }
            // net: ↓ rx  ↑ tx with vector arrows
            RowLayout {
                visible: card.kind === "net"
                Layout.fillWidth: true
                spacing: 4
                VectorGlyph { Layout.preferredWidth: 13; Layout.preferredHeight: 13; path: card.glyphs.down; source: card.theme.icon("netDown"); color: card.rxColor; strokeWidth: 2.4 }
                Text { text: card.rxText; color: card.rxColor; font { family: card.theme.mono; pixelSize: 11; bold: true } }
                Item { implicitWidth: 8 }
                VectorGlyph { Layout.preferredWidth: 13; Layout.preferredHeight: 13; path: card.glyphs.up; source: card.theme.icon("netUp"); color: card.txColor; strokeWidth: 2.4 }
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
            tempLevel: card.tempLevel
            metric: card.kind
            loadLevel: card.loadLevel
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
                source: card.skinIcon
                color: card.theme.ink
                strokeWidth: card.theme.stroke(1.5, 1.8)
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    SeverityPip {}
                    Text {
                        Layout.fillWidth: true
                        text: card.title
                        color: card.theme.ink
                        font { family: card.theme.sans; pixelSize: 13; bold: true; letterSpacing: 0.4 }
                        elide: Text.ElideRight
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: card.subtitle
                    color: card.theme.tint(card.theme.dark ? 0.7 : 0.75)
                    font { family: card.theme.mono; pixelSize: 10 }
                    elide: Text.ElideRight
                }
            }
            Image {   // the skin's hero illustration, in the row's free space
                readonly property string art: card.theme.art(({ cpu: "cpu", gpu: "gpu", ram: "memory", net: "network" })[card.kind])
                visible: art !== ""
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 64; Layout.preferredHeight: 40
                source: art
                sourceSize: Qt.size(128, 80)
                fillMode: Image.PreserveAspectFit
            }
            // cpu / gpu: temperature badge
            Badge {
                visible: card.tempText !== "" && !(card.dialed && (card.kind === "gpu" || card.semiDials))
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: tempLabel.implicitWidth + 12
                implicitHeight: tempLabel.implicitHeight + 6
                fillColor: card.tempLevel === 2 ? card.theme.critColor : "transparent"
                strokeWidth: card.theme.stroke(1, 1.5)
                strokeColor: card.levelInk(card.tempLevel, card.theme.tint(card.theme.dark ? 0.6 : 1))
                transform: Translate { y: card.tempLevel === 2 ? card.jitterY : 0 }
                Text {
                    id: tempLabel
                    anchors.centerIn: parent
                    text: card.tempText
                    color: card.tempLevel === 2 ? (card.theme.dark ? card.theme.bg : "#FFFFFF")
                         : card.levelInk(card.tempLevel, card.theme.ink)
                    font { family: card.theme.mono; pixelSize: 11; bold: true }
                }
            }
            Row {
                visible: card.semiDials
                Layout.alignment: Qt.AlignVCenter
                spacing: 4
                SemiDial {
                    width: 52; height: 42; theme: card.theme
                    value: card.percent / 100; valueText: Math.round(card.percent) + "%"
                    caption: card.theme.lex(card.kind === "gpu" ? "dialLoad" : "dialUsage", "LOAD", card.kind === "gpu" ? "LOAD" : "USAGE")
                }
                SemiDial {
                    visible: card.kind === "cpu"
                    width: 52; height: 42; theme: card.theme
                    value: card.speedFraction >= 0 ? card.speedFraction : card.percent / 100
                    caption: card.theme.lex("dialSpeed", "SPEED", "SPEED")
                }
                SemiDial {
                    visible: card.kind === "cpu"
                    width: 52; height: 42; theme: card.theme
                    value: card.tempC / Math.max(1, card.theme.controls.dialTempMax || 100)
                    valueText: card.tempText
                    caption: card.theme.lex("dialTemp", "TEMP", "TEMP")
                }
            }
            AnalogDial {
                visible: card.dialed && !card.semiDials
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 72; Layout.preferredHeight: 72
                theme: card.theme
                temperature: card.kind === "gpu"
                value: temperature ? card.tempC / Math.max(1, (card.theme.controls.dialTempMax || 100)) : card.percent / 100
                valueText: temperature ? card.tempText : Math.round(card.percent) + "%"
                caption: temperature ? card.theme.lex("dialTemp", "TEMP", "Temperature") : card.theme.lex("dialUsage", "LOAD", "Usage")
            }
            Text {
                visible: card.kind !== "net" && !(card.dialed && card.kind === "cpu")
                Layout.alignment: Qt.AlignVCenter
                text: card.valueText
                color: card.levelInk(card.loadLevel, card.theme.ink)
                font { family: card.theme.mono; pixelSize: 24; bold: true }
                transform: Translate { y: card.loadLevel === 2 ? card.jitterY : 0 }
                Text {   // glitch frame: a crimson ghost a pixel to the side while it jitters
                    visible: card.jitterY !== 0 && card.loadLevel === 2
                    x: 1.5
                    text: parent.text
                    color: card.theme.critColor
                    opacity: 0.5
                    font: parent.font
                }
            }
            // net: live RX / TX readouts
            ColumnLayout {
                visible: card.kind === "net"
                Layout.alignment: Qt.AlignVCenter
                spacing: 1
                Text {
                    Layout.alignment: Qt.AlignRight
                    text: card.theme.labels.rx ? card.theme.labels.rx + "  " + card.rxText : i18n("RX: %1", card.rxText)
                    color: card.rxColor
                    font { family: card.theme.mono; pixelSize: 12; bold: true }
                }
                Text {
                    Layout.alignment: Qt.AlignRight
                    text: card.theme.labels.tx ? card.theme.labels.tx + "  " + card.txText : i18n("TX: %1", card.txText)
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
            Layout.preferredHeight: card.theme.taskGraphs ? 36 : 24
            TaskGrid { anchors.fill: parent; theme: card.theme; visible: card.theme.taskGraphs }
            SparklineGraph {
                anchors.fill: parent
                historyData: card.graphData
                strokeColor: card.theme.taskGraphs ? card.theme.osColor("controls", "graphDown", card.theme.sparkline.a > 0 ? card.theme.sparkline : "#00C000")
                           : card.skinGraph ? card.theme.sparkline : card.loadColor(card.percent)
                fillColor: card.theme.taskGraphs ? "transparent"
                         : card.skinGraph && card.theme.sparklineFill.a > 0 ? card.theme.sparklineFill
                         : Qt.rgba(strokeColor.r, strokeColor.g, strokeColor.b, 0.18)
                lineWidth: card.theme.taskGraphs ? 1 : card.skinGraph ? card.theme.sparklineWidth : 1.5
                stepped: card.theme.sparklineStepped
                dangerColor: card.theme.sparklineDanger
                dangerAbove: card.theme.sparklineDangerAbove
                hotColor: card.theme.sparklineHot
                hotAbove: card.theme.sparklineHotAbove
            }
            SparklineGraph {
                anchors.fill: parent
                visible: card.graphData2.length > 1
                historyData: card.graphData2
                strokeColor: card.levelInk(card.tempLevel, card.theme.tint(card.theme.dark ? 0.55 : 0.6))
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
                color: card.levelInk(card.loadLevel, card.loadColor(card.percent))   // the colour of the solid fill
                font { family: card.theme.mono; pixelSize: 9; bold: true }
            }
            Text {
                visible: card.tempC > 0
                text: i18n("TEMP %1", card.tempText)
                color: card.levelInk(card.tempLevel, card.theme.dark || card.theme.skinned ? card.theme.amber : "#B07800")
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
            tempLevel: card.tempLevel
            metric: card.kind
            loadLevel: card.loadLevel
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
            // Task Manager's Networking tab: received and sent as two thin
            // lines over one grid, no fill; otherwise RX up, TX hanging down
            readonly property bool task: card.theme.taskGraphs
            TaskGrid { anchors.fill: parent; theme: card.theme; visible: parent.task }
            SparklineGraph {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: parent.task ? parent.height : parent.height / 2 - 1
                historyData: card.rxHistory.map(v => v / parent.peak)
                strokeColor: parent.task ? card.theme.osColor("controls", "graphDown", "#0050FF") : card.rxColor
                fillColor: parent.task ? "transparent" : Qt.rgba(strokeColor.r, strokeColor.g, strokeColor.b, 0.18)
                lineWidth: parent.task ? 1 : 1.5
                stepped: card.theme.sparklineStepped
            }
            Rectangle {
                visible: !parent.task
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 1
                color: card.theme.tint(0.35)
            }
            SparklineGraph {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: parent.task ? parent.height : parent.height / 2 - 1
                historyData: card.txHistory.map(v => v / parent.peak)
                strokeColor: parent.task ? card.theme.osColor("controls", "graphUp", "#E07000") : card.txColor
                fillColor: parent.task ? "transparent" : Qt.rgba(strokeColor.r, strokeColor.g, strokeColor.b, 0.18)
                lineWidth: parent.task ? 1 : 1.5
                stepped: card.theme.sparklineStepped
                inverted: !parent.task
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
                label: card.theme.labels.lan || i18n("LAN IP")
                value: card.lanText || i18nc("@info network state", "OFFLINE")
                tag: card.theme.labels.lanTag || card.lanIface.toUpperCase()
                copyable: card.lanText !== ""
            }
            Address {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                label: card.theme.labels.wan || i18n("WAN IP")
                value: card.wanText
                tag: card.theme.labels.wanTag || (card.theme.skinned ? "WAN" : "SEC-ZZ9")
                copyable: /^[0-9a-fA-F:.]+$/.test(card.wanText)
            }
        }

        // a skin's per-core traces (controls.coreGraph "multi"), one row a core
        Repeater {
            model: !card.minimal && card.kind === "cpu" && card.theme.controls.coreGraph === "multi" && card.graphs
                   ? card.coreHistories.slice(0, 8) : []
            RowLayout {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: 6
                readonly property var colors: card.theme.controls.coreColors || []
                readonly property color ink: colors.length ? colors[index % colors.length] : card.theme.high
                Text {
                    Layout.preferredWidth: 52
                    text: (card.theme.controls.coreLabel || "CPU ") + (index + 1)
                    color: parent.ink
                    font { family: card.theme.mono; pixelSize: 9; bold: true }
                }
                SparklineGraph {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 12
                    historyData: modelData
                    strokeColor: parent.ink
                    fillColor: "transparent"
                    lineWidth: 1.2
                    stepped: true            // jagged, scope-like
                }
            }
        }

        // a skin's character in the corner (narrative.vignettes), on its own row
        Repeater {
            model: card.minimal ? [] : card.theme.vignettesAt(({ cpu: "cpu", gpu: "gpu", ram: "memory" })[card.kind] || "")
            Vignette {
                required property var modelData
                Layout.alignment: Qt.AlignRight
                Layout.maximumWidth: card.width - 30
                theme: card.theme
                art: modelData.art
                text: modelData.text
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
        Badge {   // [COPIED]
            visible: copied.running
            anchors.verticalCenter: parent.verticalCenter
            width: copiedText.implicitWidth + 10
            height: copiedText.implicitHeight + 2
            fillColor: card.theme.ink
            strokeWidth: 0
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

    // The alert level before the title: an accent dot, [WARN], or a blinking
    // [CRITICAL: figure]; `compact` (the small pill) shows [WARN] / [CRIT].
    component SeverityPip: Item {
        id: pip
        property bool compact: false
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: card.alertLevel === 0 ? 6 : tag.implicitWidth
        implicitHeight: card.alertLevel === 0 ? 6 : tag.implicitHeight
        Rectangle {
            visible: card.alertLevel === 0
            anchors.fill: parent
            radius: 3
            color: card.theme.accent
        }
        Badge {
            id: tag
            visible: card.alertLevel > 0
            implicitWidth: tagText.implicitWidth + 10
            implicitHeight: tagText.implicitHeight + 2
            fillColor: card.alertLevel === 2 ? card.theme.critColor : card.theme.warnColor
            strokeWidth: 0
            opacity: card.blinkOn ? 1 : 0.12
            Text {
                id: tagText
                anchors.centerIn: parent
                text: card.alertLevel === 1 ? i18n("[WARN]")
                    : pip.compact || !card.criticalText ? i18n("[CRIT]") : i18n("[CRITICAL: %1]", card.criticalText)
                color: card.theme.dark ? card.theme.bg : "#FFFFFF"
                font { family: card.theme.mono; pixelSize: 9; bold: true; letterSpacing: 0.3 }
            }
        }
    }

    // A small label in the theme's pill shape: no corner marks or shadow at this size.
    component Badge: ThemeShapeContainer {
        theme: card.theme
        role: "pill"
        cornerBrackets: false
        shadowType: "none"
    }

    // A gauge in the theme's gaugeShape: blocks, or one continuous bar;
    // the fill colour follows the load (good / busy / hot).
    component Gauge: Item {
        id: gauge
        property int segments: 20
        property real segmentHeight: 8
        property real value: 0                 // percent
        property string metric: card.kind === "ram" ? "memory" : ""
        readonly property bool skinFill: card.theme.gaugeSlot && card.theme.gaugeUsage.a > 0
        implicitHeight: segmentHeight
        DynamicMetricGauge {
            width: gauge.width; height: gauge.segmentHeight
            theme: card.theme
            shape: card.theme.skinned ? card.theme.gaugeShape : card.theme.gaugeSlot ? "slot" : "segmented"
            segments: gauge.segments
            blockRadius: card.theme.gaugeBlockRadius
            value: Math.max(0, Math.min(100, gauge.value)) / 100
            fillColor: gauge.skinFill ? card.theme.gaugeUsage : card.loadColor(gauge.value)
            metric: gauge.metric
            nominal: card.alertLevel === 0
            outlined: gauge.skinFill
            blockTrack: card.theme.tint(card.theme.dark ? 0.3 : 0.45)
            live: card.live
        }
    }
}
