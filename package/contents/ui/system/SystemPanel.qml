import QtQuick
import QtQuick.Layouts
import "code/system.js" as Sys
import "../common"

// The body of the hardware page, without frame or header (the standalone
// widget and the Guide each put their own around it): the compute commentary,
// the optional host profile, a drawer pill each for CPU, RAM, GPU, network and
// fans with sparklines and gauges, and the sampling footer. Minimal: one slim
// pill per component. Otherwise each pill is small or large on its own
// (`sizes`, kind -> "small" | "large"), flipped by the tag on the pill, which
// emits sizeToggled(kind). All data comes in as properties.
ColumnLayout {
    id: panel

    property QtObject theme
    property QtObject telemetry           // a SystemFeed
    property var sensors: ["cpu", "ram", "net", "gpu", "fans"]
    property string tempUnit: "C"
    property bool showFanPercent: false
    property int fanMaxRpm: 6000
    property int interval: 2000
    property bool showGraphs: true
    property bool showSpecs: true
    property bool minimal: false
    property var sizes: ({})
    property bool sizeTogglesShown: true  // false: no [ - ] / [ + ] tags (the panel's hover card)
    property bool bare: false             // just the pills: no commentary, rule, host profile or footer
    property bool tempAlerts: true        // temperature colours on the CPU / GPU bars and a pulsing border when critical
    property int tempWarnPercent: 80      // of the 30-100 °C scale
    property int tempCriticalPercent: 90
    readonly property real hotC: Sys.tempAt(tempCriticalPercent)
    signal sizeToggled(string kind)
    property bool live: false
    property int entranceSerial: 0

    readonly property var t: telemetry
    function shows(kind) { return sensors.indexOf(kind) >= 0 }
    function small(kind) { return minimal || sizes[kind] === "small" }
    // Cascade positions follow the pills actually shown.
    readonly property var order: ["cpu", "ram", "gpu", "net", "fans"].filter(k => shows(k) && (k !== "gpu" || t.hasGpu))
    function slot(kind) { return Math.max(0, order.indexOf(kind)) }
    readonly property bool graphs: showGraphs && !minimal
    function temps(h) { return h.map(c => Math.max(0, Math.min(1, (c - 20) / 80))) }   // 20-100 °C
    // A skin's own commentary, judged on the Guide's thresholds; night is the
    // quiet hours (22:00-06:00) of a nominal machine. "" falls back to the Guide's.
    readonly property string skinQuip: {
        var q = theme.quips || {}
        if (!t || Object.keys(q).length === 0) return ""
        var load = Math.max(t.cpuUsage, t.gpuUsage), hour = new Date().getHours()
        var key = t.hottest > Sys.MELTDOWN ? "critical" : load > 85 || t.hottest > Sys.HOT ? "highLoad"
                : load >= 40 ? "moderate" : hour >= 22 || hour < 6 ? "night" : "nominal"
        return q[key] || ""
    }

    spacing: minimal ? 8 : 10

    Text {
        visible: !panel.minimal && !panel.bare
        Layout.fillWidth: true
        text: panel.skinQuip || panel.t.commentary
        color: panel.theme.commentary
        font { family: panel.theme.mono; pixelSize: 12; bold: true }
        wrapMode: Text.WordWrap
    }
    Rectangle {
        visible: !panel.minimal && !panel.bare
        Layout.fillWidth: true
        implicitHeight: 2
        color: panel.theme.dark ? panel.theme.tint(0.35) : panel.theme.ink
    }
    SpecsBanner {
        visible: panel.showSpecs && !panel.minimal && !panel.bare
        Layout.fillWidth: true
        Layout.topMargin: 2
        theme: panel.theme
        specs: panel.t.specs
    }

    TelemetryPillCard {
        visible: panel.shows("cpu")
        Layout.fillWidth: true
        Layout.topMargin: panel.minimal ? 0 : 2
        theme: panel.theme; live: panel.live; entranceSerial: panel.entranceSerial
        cascadeIndex: panel.slot("cpu")
        minimal: panel.small("cpu")
        sizeToggle: !panel.minimal && panel.sizeTogglesShown
        onSizeToggled: panel.sizeToggled("cpu")
        graphs: panel.graphs
        kind: "cpu"
        title: i18n("CPU CORE ARRAY")
        subtitle: i18np("%1 CORE", "%1 CORES", panel.t.cpuCores) + " · " + Sys.ghz(panel.t.cpuFreq)
        tempText: Sys.temp(panel.t.cpuTemp, panel.tempUnit)
        hot: panel.tempAlerts && panel.t.cpuTemp >= panel.hotC
        tempAlerts: panel.tempAlerts; tempWarnPercent: panel.tempWarnPercent; tempCriticalPercent: panel.tempCriticalPercent
        valueText: Math.round(panel.t.cpuUsage) + "%"
        percent: panel.t.cpuUsage
        graphData: Sys.norm(panel.t.cpuHistory, 100)
        graphData2: panel.temps(panel.t.cpuTempHistory)
        tempC: panel.t.cpuTemp
        detailText: panel.t.governor ? i18n("GOVERNOR %1", panel.t.governor.toUpperCase()) : ""
        tipText: i18n("USER %1% · SYSTEM %2% · IO WAIT %3%", Math.round(panel.t.cpuUser), Math.round(panel.t.cpuSystem),
                      Math.round(panel.t.cpuWait)) + "\n"
                 + i18np("CLOCK %2 – %3 ACROSS %1 CORE", "CLOCK %2 – %3 ACROSS %1 CORES", panel.t.cpuCores,
                         Sys.ghz(panel.t.cpuMinFreq), Sys.ghz(panel.t.cpuMaxFreq))
                 + (panel.t.governor ? "\n" + i18n("GOVERNOR %1", panel.t.governor.toUpperCase()) : "")
        minimalText: i18n("CPU %1%", Math.round(panel.t.cpuUsage)) + " · " + Sys.temp(panel.t.cpuTemp, panel.tempUnit)
    }
    TelemetryPillCard {
        visible: panel.shows("ram")
        Layout.fillWidth: true
        theme: panel.theme; live: panel.live; entranceSerial: panel.entranceSerial
        cascadeIndex: panel.slot("ram")
        minimal: panel.small("ram")
        sizeToggle: !panel.minimal && panel.sizeTogglesShown
        onSizeToggled: panel.sizeToggled("ram")
        graphs: panel.graphs
        kind: "ram"
        readonly property real pct: panel.t.memPercent
        title: i18n("PRIMARY BUFFER")
        subtitle: Sys.gb(panel.t.memUsed) + " / " + Sys.gb(panel.t.memTotal)
        hot: pct >= 90
        valueText: Math.round(pct) + "%"
        percent: pct
        graphData: Sys.norm(panel.t.ramHistory, 100)
        tipText: i18n("ACTIVE: %1 | CACHED: %2 | SWAP: %3", Sys.gb(panel.t.memApps), Sys.gb(panel.t.memCache),
                      Sys.gb(panel.t.swapUsed) + (panel.t.swapTotal > 0 ? " / " + Sys.gb(panel.t.swapTotal) : ""))
        detailText: i18n("APPS %1 · CACHE %2", Sys.gb(panel.t.memApps), Sys.gb(panel.t.memCache))
                    + (panel.t.swapTotal > 0 ? " · " + i18n("SWAP %1 / %2", Sys.gb(panel.t.swapUsed), Sys.gb(panel.t.swapTotal)) : "")
        minimalText: i18n("RAM %1 / %2 (%3%)", Sys.gb(panel.t.memUsed).replace(" GB", ""), Sys.gb(panel.t.memTotal),
                          Math.round(pct))
    }
    TelemetryPillCard {
        visible: panel.shows("gpu") && panel.t.hasGpu
        Layout.fillWidth: true
        theme: panel.theme; live: panel.live; entranceSerial: panel.entranceSerial
        cascadeIndex: panel.slot("gpu")
        minimal: panel.small("gpu")
        sizeToggle: !panel.minimal && panel.sizeTogglesShown
        onSizeToggled: panel.sizeToggled("gpu")
        graphs: panel.graphs
        kind: "gpu"
        readonly property real vramPct: panel.t.vramTotal > 0 ? 100 * panel.t.vramUsed / panel.t.vramTotal : 0
        // With several GPUs the sensor's own name says which one is shown.
        title: (panel.t.gpus.length < 2 && panel.t.specs && panel.t.specs.gpuFound ? panel.t.specs.gpu.split(" + ")[0]
               : panel.t.gpuName || i18n("GRAPHICS ENGINE")).toUpperCase()
        subtitle: i18n("VRAM %1 / %2", Sys.gb(panel.t.vramUsed), Sys.gb(panel.t.vramTotal))
        tempText: Sys.temp(panel.t.gpuTemp, panel.tempUnit)
        hot: panel.tempAlerts && panel.t.gpuTemp >= panel.hotC
        tempAlerts: panel.tempAlerts; tempWarnPercent: panel.tempWarnPercent; tempCriticalPercent: panel.tempCriticalPercent
        valueText: Math.round(panel.t.gpuUsage) + "%"
        percent: panel.t.gpuUsage
        secondaryPercent: vramPct
        tempC: panel.t.gpuTemp
        graphData: Sys.norm(panel.t.gpuHistory, 100)
        graphData2: panel.temps(panel.t.gpuTempHistory)
        tipText: { var g = panel.t.gpuInfo || {}
                   var na = i18nc("@info not available", "N/A")
                   return i18n("PCIE LINK: %1\nDRIVER: %2\nFAN DUTY: %3", g.link || na, g.driver || na,
                               g.fanDuty >= 0 ? g.fanDuty + "%" : na) }
        detailText: (panel.t.gpuClock > 0 ? i18n("CORE %1", Sys.ghz(panel.t.gpuClock)) + " · " : "")
                    + i18n("VRAM %1% IN USE", Math.round(vramPct))
        minimalText: i18n("GPU %1%", Math.round(panel.t.gpuUsage)) + " · " + Sys.temp(panel.t.gpuTemp, panel.tempUnit)
                     + " · " + i18n("%1 VRAM", Sys.gb(panel.t.vramUsed))
    }
    TelemetryPillCard {
        visible: panel.shows("net")
        Layout.fillWidth: true
        theme: panel.theme; live: panel.live; entranceSerial: panel.entranceSerial
        cascadeIndex: panel.slot("net")
        minimal: panel.small("net")
        sizeToggle: !panel.minimal && panel.sizeTogglesShown
        onSizeToggled: panel.sizeToggled("net")
        graphs: panel.graphs
        kind: "net"
        title: panel.t.iface ? panel.t.iface.toUpperCase() : i18n("ALL INTERFACES")
        subtitle: i18n("SUB-ETHA LINK") + (panel.t.networkName ? " · " + panel.t.networkName.toUpperCase() : "")
        rxText: Sys.rate(panel.t.rx)
        txText: Sys.rate(panel.t.tx)
        rxHistory: panel.t.rxHistory
        tipText: i18n("TOTAL RX %1 / TOTAL TX %2", Sys.amount(panel.t.rxTotal), Sys.amount(panel.t.txTotal))
        lanText: panel.t.localIp
        lanIface: panel.t.iface
        wanText: panel.t.wanState === "ok" ? panel.t.publicIp
               : panel.t.wanState === "offline" ? i18nc("@info network state", "OFFLINE") : i18n("RESOLVING...")
        identityTip: { var na = i18nc("@info not available", "N/A")
                       return i18n("GATEWAY: %1\nSUBNET: %2\nDNS: %3", panel.t.gateway || na, panel.t.cidr || na, panel.t.dns || na)
                            + "\n" + i18n("CLICK AN ADDRESS TO COPY IT") }
        detailText: i18n("SESSION ↓ %1 ↑ %2", Sys.amount(panel.t.rxTotal), Sys.amount(panel.t.txTotal))
                    + " · " + i18n("PEAK ↓ %1 ↑ %2", Sys.rate(Math.max.apply(null, panel.t.rxHistory.concat([0]))),
                                   Sys.rate(Math.max.apply(null, panel.t.txHistory.concat([0]))))
        txHistory: panel.t.txHistory
    }
    FanPillCard {
        visible: panel.shows("fans")
        Layout.fillWidth: true
        theme: panel.theme; live: panel.live; entranceSerial: panel.entranceSerial
        cascadeIndex: panel.slot("fans")
        minimal: panel.small("fans")
        sizeToggle: !panel.minimal && panel.sizeTogglesShown
        onSizeToggled: panel.sizeToggled("fans")
        graphs: panel.graphs
        fans: panel.t.fans
        histories: panel.t.fanHistory
        showPercent: panel.showFanPercent
        maxRpm: panel.fanMaxRpm
    }

    Text {
        visible: panel.order.length === 0
        Layout.fillWidth: true
        Layout.topMargin: 6
        Layout.bottomMargin: 6
        horizontalAlignment: Text.AlignHCenter
        text: i18n("NO SENSORS SELECTED.")
        color: panel.theme.tint(0.6)
        font { family: panel.theme.mono; pixelSize: 11 }
    }
    Text {
        visible: !panel.minimal && !panel.bare
        Layout.fillWidth: true
        Layout.topMargin: 2
        text: i18n("SAMPLING EVERY %1 S", (panel.interval / 1000).toFixed(1)) + " · " + i18n("%1-SAMPLE HISTORY", Sys.HISTORY)
        color: panel.theme.tint(0.55)
        font { family: panel.theme.mono; pixelSize: 10; bold: true; letterSpacing: 0.5 }
    }
}
