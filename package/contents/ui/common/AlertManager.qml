import QtQuick
import "../system/code/system.js" as Sys

// The Guide's alert state: every reading judged against the configured
// thresholds as 0 (nominal), 1 (warning) or 2 (critical). Temperature and
// load are judged on their own and the higher one wins. Temperatures have a
// warning and a critical step; loads only a critical one, the disks their
// own warning level (DiskFeed's `critical`). With `enabled` off everything is
// nominal. A level rises or falls only once the reading has held it for
// `holdMs` (SustainedLevel), so a one-sample spike never trips an alert.
// `culprits` lists the readings past warning, worst first, each with the
// line the panel's hover card shows.
QtObject {
    id: alerts

    property bool enabled: true           // tempColorAlerts
    property bool animate: true           // enablePulsingAnimations: breathing, blinking, strobe, jitter
    property int cpuTempWarn: 75          // °C
    property int cpuTempCrit: 85
    property int gpuTempWarn: 75
    property int gpuTempCrit: 85
    property int cpuLoadCrit: 90          // %
    property int gpuLoadCrit: 95
    property int ramLoadCrit: 90
    property int holdMs: 3000             // alertHoldSeconds: how long a reading must stay at a level before it shows
    property string tempUnit: "C"
    property QtObject system              // a SystemFeed
    property QtObject disk                // a DiskFeed, or null while storage is off

    readonly property int nominal: 0
    readonly property int warning: 1
    readonly property int critical: 2

    // kind: "cpu" | "gpu"; celsius 0 or less: no reading
    function tempLevel(kind, celsius) {
        if (!enabled || !(celsius > 0)) return 0
        var crit = kind === "gpu" ? gpuTempCrit : cpuTempCrit, warn = kind === "gpu" ? gpuTempWarn : cpuTempWarn
        return celsius >= crit ? 2 : celsius >= warn ? 1 : 0
    }
    // kind: "cpu" | "gpu" | "ram"; percent 0-100
    function loadLevel(kind, percent) {
        if (!enabled) return 0
        var crit = kind === "gpu" ? gpuLoadCrit : kind === "ram" ? ramLoadCrit : cpuLoadCrit
        return percent >= crit ? 2 : 0
    }
    function level(kind, percent, celsius) { return Math.max(loadLevel(kind, percent), tempLevel(kind, celsius)) }

    readonly property bool hasGpu: !!system && system.hasGpu
    // as judged this sample...
    readonly property var rawVolumes: enabled && disk ? disk.volumes.filter(v => v.critical) : []
    readonly property SustainedLevel cpuTempHold: SustainedLevel {
        interval: alerts.holdMs; raw: alerts.system ? alerts.tempLevel("cpu", alerts.system.cpuTemp) : 0 }
    readonly property SustainedLevel cpuLoadHold: SustainedLevel {
        interval: alerts.holdMs; raw: alerts.system ? alerts.loadLevel("cpu", alerts.system.cpuUsage) : 0 }
    readonly property SustainedLevel gpuTempHold: SustainedLevel {
        interval: alerts.holdMs; raw: alerts.hasGpu ? alerts.tempLevel("gpu", alerts.system.gpuTemp) : 0 }
    readonly property SustainedLevel gpuLoadHold: SustainedLevel {
        interval: alerts.holdMs; raw: alerts.hasGpu ? alerts.loadLevel("gpu", alerts.system.gpuUsage) : 0 }
    readonly property SustainedLevel ramHold: SustainedLevel {
        interval: alerts.holdMs; raw: alerts.system ? alerts.loadLevel("ram", alerts.system.memPercent) : 0 }
    readonly property SustainedLevel diskHold: SustainedLevel {
        interval: alerts.holdMs; raw: alerts.rawVolumes.length > 0 ? 2 : 0 }
    // ...and as shown, once held (switching alerts off clears them at once)
    readonly property int cpuTemp: enabled ? cpuTempHold.level : 0
    readonly property int cpuLoad: enabled ? cpuLoadHold.level : 0
    readonly property int gpuTemp: enabled ? gpuTempHold.level : 0
    readonly property int gpuLoad: enabled ? gpuLoadHold.level : 0
    readonly property int ram: enabled ? ramHold.level : 0
    readonly property int cpu: Math.max(cpuTemp, cpuLoad)
    readonly property int gpu: Math.max(gpuTemp, gpuLoad)
    readonly property int disks: enabled ? diskHold.level : 0
    readonly property var criticalVolumes: disks === 2 ? rawVolumes : []

    // { key: cpu | gpu | ram | disk, level, text }, critical first
    readonly property var culprits: {
        var out = [], s = system
        if (!s) return out
        function t(c) { return Sys.temp(c, tempUnit) }
        if (cpuTemp) out.push({ key: "cpu", level: cpuTemp, text: cpuTemp === 2
            ? i18n("CPU THERMAL CEILING EXCEEDED [%1]", t(s.cpuTemp)) : i18n("CPU RUNNING WARM [%1]", t(s.cpuTemp)) })
        if (cpuLoad) out.push({ key: "cpu", level: 2, text: i18n("CPU LOAD CEILING EXCEEDED [%1%]", Math.round(s.cpuUsage)) })
        if (gpuTemp) out.push({ key: "gpu", level: gpuTemp, text: gpuTemp === 2
            ? i18n("GPU THERMAL CEILING EXCEEDED [%1]", t(s.gpuTemp)) : i18n("GPU RUNNING WARM [%1]", t(s.gpuTemp)) })
        if (gpuLoad) out.push({ key: "gpu", level: 2, text: i18n("GPU LOAD CEILING EXCEEDED [%1%]", Math.round(s.gpuUsage)) })
        if (ram) out.push({ key: "ram", level: 2, text: i18n("MEMORY NEARLY EXHAUSTED [%1%]", Math.round(s.memPercent)) })
        criticalVolumes.forEach(v => out.push({ key: "disk", level: 2,
            text: i18n("DISK QUOTA EXCEEDED: %1 [%2%]", v.label || v.mountPoint, v.usedPercentage) }))
        return out.sort((a, b) => b.level - a.level)
    }
    readonly property int worst: culprits.length ? culprits[0].level : 0

    // The critical badge's figure for a chip: the reading that tripped it.
    function criticalText(kind) {
        var s = system
        if (!s) return ""
        if (kind === "cpu") return cpuTemp === 2 ? Sys.temp(s.cpuTemp, tempUnit) : Math.round(s.cpuUsage) + "%"
        if (kind === "gpu") return gpuTemp === 2 ? Sys.temp(s.gpuTemp, tempUnit) : Math.round(s.gpuUsage) + "%"
        if (kind === "ram") return Math.round(s.memPercent) + "%"
        return ""
    }
}
