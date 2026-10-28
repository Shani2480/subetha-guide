import QtQuick
import "system/code/system.js" as Sys

// What the panel item shows: the chosen reading (panelDisplaySensor), three
// at once ("multiPill"), or, with a cycle interval, each available reading in
// turn. A reading is { key, label, text, shortText, fraction (0..1, or -1 for
// no meter), level ("ok" | "busy" | "alert"), glyph, and for the CPU and GPU
// readings load (0..1) and temp (°C) for the layered meter }; the weather reading
// is drawn with the live condition icon instead of a glyph. `keys` lists the
// readings that need data, so the feeds keep exactly those running while the
// popup is closed.
Item {
    id: panel

    property string sensor: "weather"
    property int cycleSeconds: 0
    property bool running: false          // the panel item is visible and the session unlocked
    property var sections: []             // enabled sections, for cycling and multiPill
    property string tempUnit: "C"
    property bool tempAlerts: true        // temperatures turn busy / alert at the thresholds below
    property int tempWarnPercent: 80      // of the 30-100 °C scale
    property int tempCriticalPercent: 90
    function tempLevel(c) {
        if (!tempAlerts || c <= 0) return "ok"
        var p = (c - Sys.TEMP_MIN) / (Sys.TEMP_MAX - Sys.TEMP_MIN) * 100
        return p >= tempCriticalPercent ? "alert" : p >= tempWarnPercent ? "busy" : "ok"
    }
    property QtObject weatherFeed
    property QtObject systemFeed
    property QtObject batteryFeed
    property QtObject timeEngine
    property bool clockSeconds: true

    readonly property var glyphs: ({
        cpuLoad: "M7 7 H17 V17 H7 Z M9.5 9.5 H14.5 V14.5 H9.5 Z M9 7 V4 M12 7 V4 M15 7 V4 M9 17 V20 M12 17 V20 M15 17 V20 M7 9 H4 M7 12 H4 M7 15 H4 M17 9 H20 M17 12 H20 M17 15 H20",
        cpuTemp: "M10 4 A2 2 0 0 1 14 4 V13.5 A4 4 0 1 1 10 13.5 Z M12 9 V17",
        gpuTemp: "M2 4 V19 M2 6 H21 V16 H2 M5 16 V18.5 H14 V16 M7 11 A3 3 0 1 0 13 11 A3 3 0 1 0 7 11 Z M16 9 H18.5 M16 11 H18.5 M16 13 H18.5",
        ramUsage: "M2 7 H22 V15 H2 Z M5 9.5 H8 V12.5 H5 Z M10.5 9.5 H13.5 V12.5 H10.5 Z M16 9.5 H19 V12.5 H16 Z M4 15 V17.5 M7 15 V17.5 M10 15 V17.5 M14 15 V17.5 M17 15 V17.5 M20 15 V17.5",
        netSpeed: "M12 4 V19 M6.5 13.5 L12 19 L17.5 13.5",
        battery: "M3 7 H19 V17 H3 Z M19 10 H21.5 V14 H19 M6 10 V14 M9 10 V14 M12 10 V14",
        clock: "M3 12 A9 9 0 1 0 21 12 A9 9 0 1 0 3 12 Z M12 7 V12 L15.5 14"
    })
    readonly property var labels: ({ weather: i18nc("panel label", "WX"), cpuLoad: i18nc("panel label", "CPU"),
                                     cpuTemp: i18nc("panel label", "CPU"), gpuTemp: i18nc("panel label", "GPU"),
                                     ramUsage: i18nc("panel label", "RAM"), netSpeed: i18nc("panel label", "NET"),
                                     battery: i18nc("panel label", "BAT"), clock: i18nc("panel label", "TIME") })

    function sectionOf(key) {
        return key === "weather" || key === "battery" || key === "clock" ? key : "system"
    }
    function available(key) {
        if (key === "weather") return !!weatherFeed && weatherFeed.hasData
        if (key === "gpuTemp") return !!systemFeed && systemFeed.hasGpu
        if (key === "battery") return !!batteryFeed && !!batteryFeed.panelDevice
        if (key === "clock") return !!timeEngine
        return !!systemFeed
    }
    // 12.4 MB/s -> "12.4M": the panel has no room for units.
    function shortRate(bps) {
        var b = Sys.num(bps)
        return b >= 1e9 ? (b / 1e9).toFixed(1) + "G" : b >= 1e6 ? (b / 1e6).toFixed(1) + "M" : Math.round(b / 1e3) + "K"
    }
    function levelOf(fraction) { return fraction >= 0.85 ? "alert" : fraction >= 0.5 ? "busy" : "ok" }
    function heat(celsius) { return celsius > 0 ? Math.max(0, Math.min(1, (celsius - 20) / 80)) : -1 }

    function reading(key) {
        var s = systemFeed, r = { key: key, label: labels[key] || "", glyph: glyphs[key] || "", fraction: -1, level: "ok" }
        if (key === "weather") {
            r.text = weatherFeed ? weatherFeed.tempText : "--°"
        } else if (key === "clock") {
            var t = timeEngine
            r.text = t ? t.hours + ":" + t.minutes + (clockSeconds ? ":" + t.seconds : "") + (t.meridiem ? " " + t.meridiem : "") : "--:--"
            // A vertical panel has room for the hours and minutes only.
            return Object.assign(r, { shortText: t ? t.hours + ":" + t.minutes : "--:--" })
        } else if (key === "cpuLoad") {
            r.text = Math.round(s.cpuUsage) + "%"; r.fraction = s.cpuUsage / 100
        } else if (key === "cpuTemp") {
            r.text = Sys.temp(s.cpuTemp, tempUnit); r.fraction = heat(s.cpuTemp)
            r.level = tempLevel(s.cpuTemp)
        } else if (key === "gpuTemp") {
            r.text = Sys.temp(s.gpuTemp, tempUnit); r.fraction = heat(s.gpuTemp)
            r.level = tempLevel(s.gpuTemp)
        } else if (key === "ramUsage") {
            r.text = Math.round(s.memPercent) + "%"; r.fraction = s.memPercent / 100
        } else if (key === "netSpeed") {
            r.text = "↓" + shortRate(s.rx)
        } else if (key === "battery") {
            var d = batteryFeed ? batteryFeed.panelDevice : null
            r.text = d ? d.percent + "%" : "--%"
            r.fraction = d ? d.percent / 100 : -1
            r.level = d && d.critical ? "alert" : "ok"
            return Object.assign(r, { shortText: r.text })
        }
        if (key === "cpuLoad" || key === "ramUsage") r.level = levelOf(r.fraction)
        if (key === "cpuLoad" || key === "cpuTemp") { r.load = s.cpuUsage / 100; r.temp = s.cpuTemp }
        if (key === "gpuTemp") { r.load = s.gpuUsage / 100; r.temp = s.gpuTemp }
        r.shortText = r.text.replace("°C", "°").replace("°F", "°")
        return r
    }

    readonly property var allKeys: ["clock", "weather", "cpuLoad", "cpuTemp", "gpuTemp", "ramUsage", "netSpeed", "battery"]
    // Readings of the switched-on sections, in a fixed order.
    readonly property var enabledKeys: (allKeys || []).filter(k => (sections || []).indexOf(sectionOf(k)) >= 0)
    readonly property bool cycling: cycleSeconds > 0 && sensor !== "multiPill"
    readonly property var cycleKeys: (enabledKeys || []).filter(k => available(k))
    readonly property var multiKeys: ["weather", "cpuLoad", "ramUsage", "battery"].filter(k => (enabledKeys || []).indexOf(k) >= 0 && available(k)).slice(0, 3)

    // Which readings need their feeds running.
    readonly property var keys: sensor === "multiPill" ? ["weather", "cpuLoad", "ramUsage", "battery"]
                              : cycling ? enabledKeys : [sensor]

    property int step: 0
    Timer {
        interval: Math.max(1, panel.cycleSeconds) * 1000
        repeat: true
        running: panel.running && panel.cycling && panel.cycleKeys.length > 1
        onTriggered: panel.step = (panel.step + 1) % Math.max(1, panel.cycleKeys.length)
    }
    readonly property var shownKeys: sensor === "multiPill" ? (multiKeys.length ? multiKeys : ["cpuLoad"])
                                   : cycling && cycleKeys.length ? [cycleKeys[step % cycleKeys.length]]
                                   : [sensor]
    readonly property var shown: shownKeys.map(k => reading(k))
}
