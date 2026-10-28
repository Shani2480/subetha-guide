.pragma library
.import "../../common/i18n.js" as T

// Translated strings go through common/i18n.js (see there).
function i18n() { return T.tr("i18n", Array.prototype.slice.call(arguments)) }
function i18nc() { return T.tr("i18nc", Array.prototype.slice.call(arguments)) }
function i18np() { return T.tr("i18np", Array.prototype.slice.call(arguments)) }

// Turns the powermanagement data engine's per-battery sources ("Battery0",
// "Battery1", ...) into flat device records for the pill cards, and picks the
// Guide's commentary line for the whole set.

var CRITICAL = 15   // default alertThreshold: below it a pill pulses and reads DEPLETION IMMINENT

// UPower's battery type ("Mouse", "GamingInput", "Bluetooth", ...) to the
// card's icon. Generic Bluetooth batteries are guessed from the device name.
function deviceKind(type, name, isPowerSupply) {
    var t = (type || "").toLowerCase()
    var n = (name || "").toLowerCase()
    if (t === "battery") return isPowerSupply ? "laptop" : "other"
    if (t === "ups") return "ups"
    if (t === "mouse" || t === "touchpad") return "mouse"
    if (t === "keyboard") return "keyboard"
    if (t === "headset" || t === "headphone") return "headset"
    if (t === "phone" || t === "pda") return "phone"
    if (t === "gaminginput") return "controller"
    if (t === "tablet" || t === "pen") return "pen"
    if (/mouse|trackball|mx (master|anywhere)/.test(n)) return "mouse"
    if (/keyboard|keys/.test(n)) return "keyboard"
    if (/head(set|phone)|buds|airpods|earphone|wh-|wf-/.test(n)) return "headset"
    if (/controller|gamepad|dualsense|dualshock|xbox|joy-?con/.test(n)) return "controller"
    if (/pen|stylus/.test(n)) return "pen"
    if (/phone|pixel|galaxy/.test(n)) return "phone"
    return "other"
}

// "2H 05M", or "" when there is no estimate.
function duration(msec) {
    if (!msec || msec <= 0) return ""
    var minutes = Math.round(msec / 60000)
    var h = Math.floor(minutes / 60)
    var m = minutes % 60
    return h > 0 ? i18nc("time estimate: hours, minutes", "%1H %2M", h, (m < 10 ? "0" : "") + m)
                 : i18nc("time estimate: minutes", "%1M", m)
}

// summary: the engine's "Battery" source; it carries the only time estimate,
// which belongs to the primary battery when there is exactly one.
// opts: { threshold: alert level in %, showEstimate: include time to empty / full }
function describe(source, d, summary, primaryCount, opts) {
    opts = opts || {}
    var threshold = opts.threshold > 0 ? opts.threshold : CRITICAL
    var primary = !!d["Is Power Supply"]
    var pretty = d["Pretty Name"] || ""
    var product = d["Product"] || ""
    var vendor = d["Vendor"] || ""
    // The laptop battery is usually just "Battery"; the product name says more.
    var name = (pretty && pretty !== "Battery") ? pretty : (product || pretty || "Energy cell")
    var state = d["State"] || "Unknown"
    var percent = Math.max(0, Math.min(100, Math.round(d["Percent"] || 0)))
    var charging = state === "Charging"
    var msec = primary && primaryCount === 1 && opts.showEstimate !== false
             ? (summary["Smoothed Remaining msec"] || summary["Remaining msec"] || 0) : 0
    var time = duration(msec)

    var status
    if (charging) status = time ? i18n("CHARGING · %1 TO FULL", time) : i18n("CHARGING")
    else if (state === "Discharging") status = time ? i18n("DRAINING · %1 LEFT", time) : i18n("DRAINING")
    else if (state === "FullyCharged") status = i18n("FULLY CHARGED")
    else if (state === "NoCharge") status = d["Plugged in"] ? i18n("ON MAINS · HOLDING") : i18nc("battery state", "IDLE")
    else status = i18nc("battery state", "ONLINE")

    var detail = []
    if (vendor && name.toLowerCase().indexOf(vendor.toLowerCase()) < 0) detail.push(vendor)
    if (primary && d["Capacity"] > 0) detail.push(i18n("HEALTH %1%", Math.round(d["Capacity"])))
    if (primary && summary["Charge Stop Threshold"] > 0 && summary["Charge Stop Threshold"] < 100)
        detail.push(i18nc("charge stop threshold", "LIMIT %1%", summary["Charge Stop Threshold"]))

    var kind = deviceKind(d["Type"], pretty + " " + product, primary)
    return {
        source: source,
        // Stable across reconnects (unlike "BatteryN"): what selectedDevices stores.
        key: kind + ":" + name.toUpperCase(),
        // The fallback name is translated for display only; the key keeps it English.
        name: (name === "Energy cell" ? i18n("Energy cell") : name).toUpperCase(),
        kind: kind,
        percent: percent,
        charging: charging,
        status: status,
        detail: detail.join(" · ").toUpperCase(),
        primary: primary,
        critical: percent < threshold && !charging
    }
}

// selected: the selectedDevices setting. "all" shows every device, "primary"
// every system battery; anything else is a device key.
function isSelected(device, selected) {
    if (!selected) return true
    if (selected.indexOf("all") >= 0) return true
    if (device.primary && selected.indexOf("primary") >= 0) return true
    return selected.indexOf(device.key) >= 0
}

// Primary batteries first, then peripherals by name.
function compare(a, b) {
    if (a.primary !== b.primary) return a.primary ? -1 : 1
    return a.name < b.name ? -1 : a.name > b.name ? 1 : 0
}

// The Guide's verdict on the whole set, judged by its weakest cell.
function commentary(devices, acPlugged) {
    if (!devices.length) return i18n("NO ENERGY CELLS DETECTED. MOSTLY HARMLESS.")
    var weakest = devices[0]
    var siphoning = false
    for (var i = 0; i < devices.length; i++) {
        if (devices[i].percent < weakest.percent) weakest = devices[i]
        if (devices[i].primary && devices[i].charging) siphoning = true
    }
    if (weakest.percent < 20 && !weakest.charging)
        return i18n("IMPROBABILITY SURGE IMMINENT. PLUG IN BEFORE DESTRUCTION.")
    if (acPlugged && siphoning) return i18n("SIPHONING ELECTRONS FROM LOCAL GRID. STANDBY.")
    if (weakest.percent >= 70) return i18n("ENERGY CELLS OPTIMAL. NO IMMEDIATE TOWEL REQUIRED.")
    if (weakest.percent >= 30) return i18n("DISCHARGING GRADUALLY. RELATIVELY HARMLESS.")
    return i18n("RESERVES DWINDLING. LOCATE TOWEL AND CHARGER.")
}

// ---- charge / discharge rate ----
// ksystemstats publishes each laptop battery's signed rate in watts
// (power/battery_BAT0/chargeRate: positive charging, negative draining).
// Without it, the kernel's own figures: power_now in µW, or current_now (µA)
// times voltage_now (µV), signed by the status.
var RATE_SENSORS = "kstatsviewer --list 2>/dev/null | grep -oE '^power/[^ /]+/chargeRate' | sort -u"
var RATE_SYSFS = "for b in /sys/class/power_supply/BAT*; do [ -d \"$b\" ] || continue;"
               + " echo \"$(cat $b/power_now 2>/dev/null || echo -) $(cat $b/current_now 2>/dev/null || echo -)"
               + " $(cat $b/voltage_now 2>/dev/null || echo -) $(cat $b/status 2>/dev/null)\"; done"

// Sum of the batteries' signed watts, or NaN when nothing reports.
function parseSysfsRate(stdout) {
    var total = NaN
    String(stdout || "").split("\n").forEach(function (line) {
        var f = line.trim().split(/\s+/)
        if (f.length < 4) return
        var uw = Number(f[0])
        if (!(uw > 0) && Number(f[1]) > 0 && Number(f[2]) > 0) uw = Number(f[1]) * Number(f[2]) / 1e6
        if (!isFinite(uw)) return
        var w = Math.abs(uw / 1e6)
        if (f[3] === "Discharging") w = -w
        total = (isNaN(total) ? 0 : total) + w
    })
    return total
}

// "+45.2 W [CHARGING]", "-12.4 W [DRAIN]", "0.0 W [IDLE / MAINS]"
function rateState(watts, onMains) {
    if (isNaN(watts)) return ""
    if (watts > 0.05) return "charging"
    if (watts < -0.05) return "drain"
    return onMains ? "mains" : "idle"
}
// Just the signed figure ("+45.2 W"), for the minimal pill.
function rateWatts(watts, onMains) {
    var state = rateState(watts, onMains)
    if (state === "") return ""
    var w = Math.abs(watts).toFixed(1) + " W"
    return state === "charging" ? "+" + w : state === "drain" ? "-" + w : "0.0 W"
}
function rateText(watts, onMains) {
    var state = rateState(watts, onMains)
    if (state === "") return ""
    var w = rateWatts(watts, onMains)
    return state === "charging" ? i18n("%1 [CHARGING]", w)
         : state === "drain" ? i18n("%1 [DRAIN]", w)
         : state === "mains" ? i18n("%1 [IDLE / MAINS]", w) : i18n("%1 [IDLE]", w)
}

// The laptop battery's wear: full charge against design capacity, and the
// charge cycle count (absent on some firmware).
var HEALTH = "for b in /sys/class/power_supply/BAT*; do [ -d $b ] || continue;"
           + " echo $(cat $b/energy_full 2>/dev/null || cat $b/charge_full 2>/dev/null)"
           + " $(cat $b/energy_full_design 2>/dev/null || cat $b/charge_full_design 2>/dev/null)"
           + " $(cat $b/cycle_count 2>/dev/null); break; done"

function parseHealth(stdout) {
    var p = String(stdout || "").trim().split(/\s+/).map(Number)
    var full = p[0], design = p[1]
    return {
        health: full > 0 && design > 0 ? Math.round(1000 * full / design) / 10 : -1,
        cycles: p.length > 2 && isFinite(p[2]) ? p[2] : -1
    }
}
