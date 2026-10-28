.pragma library
.import "../../common/i18n.js" as T

// Translated strings go through common/i18n.js (see there).
function i18n() { return T.tr("i18n", Array.prototype.slice.call(arguments)) }
function i18nc() { return T.tr("i18nc", Array.prototype.slice.call(arguments)) }
function i18np() { return T.tr("i18np", Array.prototype.slice.call(arguments)) }

// Formatting and the Guide's commentary for the system monitor. The numbers
// themselves come from ksystemstats through org.kde.ksysguard.sensors.

var HISTORY = 24            // samples kept for each sparkline
var HOT = 85                // °C: a CPU/GPU pill turns critical
var MELTDOWN = 95           // °C

// The CPU / GPU temperature bars run 30-100 °C; thresholds are set as a
// percentage of that scale.
var TEMP_MIN = 30
var TEMP_MAX = 100
function tempAt(percent) { return TEMP_MIN + (TEMP_MAX - TEMP_MIN) * percent / 100 }

function num(v) { var n = Number(v); return isFinite(n) ? n : 0 }

// Memory sizes in GB the way system monitors count them (1024-based).
function gb(bytes) {
    var g = num(bytes) / 1073741824
    return (g >= 100 ? Math.round(g) : g.toFixed(1)) + " GB"
}

// Transfer rates: KB/s below a megabyte, then MB/s, GB/s.
function rate(bps) {
    var b = num(bps)
    if (b >= 1e9) return (b / 1e9).toFixed(1) + " GB/s"
    if (b >= 1e6) return (b / 1e6).toFixed(1) + " MB/s"
    var k = b / 1e3
    return (k >= 100 ? Math.round(k) : k.toFixed(1)) + " KB/s"
}

// Amounts transferred: MB below a gigabyte, then GB, TB.
function amount(bytes) {
    var b = num(bytes)
    if (b >= 1e12) return (b / 1e12).toFixed(2) + " TB"
    if (b >= 1e9) return (b / 1e9).toFixed(1) + " GB"
    return Math.round(b / 1e6) + " MB"
}

function temp(celsius, unit) {
    var c = num(celsius)
    if (c <= 0) return "--°"
    return unit === "F" ? Math.round(c * 9 / 5 + 32) + "°F" : Math.round(c) + "°C"
}

function ghz(mhz) { return (num(mhz) / 1000).toFixed(2) + " GHZ" }

// Rolling history: a new array (so bindings see the change), oldest first.
function push(history, value) {
    var h = history.slice(Math.max(0, history.length - HISTORY + 1))
    h.push(num(value))
    return h
}

// A history scaled to 0..1 for SparklineGraph: by `max`, or by its own peak.
function norm(history, max) {
    var top = max > 0 ? max : Math.max.apply(null, (history || []).concat([1e-9]))
    return (history || []).map(function (v) { return Math.max(0, Math.min(1, num(v) / top)) })
}

// ---- host profile ----
// Read once when the specs banner first shows; none of it changes while the
// session runs. Memory type and speed come from the DMI tables through udev
// (systemd's dmi_memory_id), which, unlike dmidecode, needs no root.
var MARK = "@@"
var SPECS = "grep -m1 'model name' /proc/cpuinfo; nproc; echo @@;"
          + " lspci -mm 2>/dev/null | grep -E '\"(VGA compatible controller|3D controller|Display controller)\"'; echo @@;"
          + " grep MemTotal /proc/meminfo; udevadm info -q property /sys/devices/virtual/dmi/id 2>/dev/null"
          + " | grep -E '^MEMORY_DEVICE_[0-9]+_(SIZE|TYPE|CONFIGURED_SPEED_MTS|SPEED_MTS)='; echo @@;"
          + " uname -sr; . /etc/os-release 2>/dev/null; echo \"$NAME|$ID|$ID_LIKE\"; cat /proc/sys/kernel/hostname"

var VENDORS = [[/nvidia/i, "NVIDIA"], [/amd|ati/i, "AMD"], [/intel/i, "Intel"]]

// "AMD Ryzen 7 9800X3D 8-Core Processor", 16 -> "AMD Ryzen 7 9800X3D (16T)"
function cpuName(line, threads) {
    var name = String(line || "").replace(/^model name\s*:\s*/, "")
        .replace(/\s+\d+-Core Processor\s*$/i, "").replace(/\s+with Radeon Graphics\s*$/i, "")
        .replace(/\((R|TM)\)/g, "").replace(/\s+CPU\s+@.*$/, "").replace(/\s+/g, " ").trim()
    return name ? name + (threads > 0 ? " (" + threads + "T)" : "") : i18nc("@info processor name", "UNKNOWN")
}

// lspci -mm: "77:00.0" "VGA compatible controller" "Advanced Micro Devices, Inc. [AMD/ATI]" "Rembrandt [Radeon 680M]"
//   -> "AMD Radeon 680M"
function gpuName(line) {
    var f = String(line).match(/"[^"]*"/g)
    if (!f || f.length < 3) return ""
    var vendorField = f[1].slice(1, -1), deviceField = f[2].slice(1, -1)
    var vendor = ""
    VENDORS.forEach(function (v) { if (!vendor && v[0].test(vendorField)) vendor = v[1] })
    var model = (deviceField.match(/\[([^\]]+)\]/) || [])[1] || deviceField
    return (vendor && model.indexOf(vendor) !== 0 ? vendor + " " : "") + model
}

function parseSpecs(stdout) {
    var p = String(stdout || "").split(MARK).map(function (x) { return x.trim().split("\n") })
    var cpu = p[0] || [], gpu = p[1] || [], mem = p[2] || [], os = p[3] || []

    var gpus = gpu.map(gpuName).filter(function (g) { return g })

    var kb = 0, size = 0, types = {}, speed = 0, modules = 0
    mem.forEach(function (l) {
        var m
        if ((m = l.match(/^MemTotal:\s+(\d+)/))) kb = Number(m[1])
        else if ((m = l.match(/^MEMORY_DEVICE_\d+_SIZE=(\d+)/))) { size += Number(m[1]); modules++ }
        else if ((m = l.match(/^MEMORY_DEVICE_\d+_TYPE=(\S+)/)) && m[1] !== "Unknown") types[m[1]] = true
        else if ((m = l.match(/^MEMORY_DEVICE_\d+_(?:CONFIGURED_)?SPEED_MTS=(\d+)/))) speed = Math.max(speed, Number(m[1]))
    })
    var type = Object.keys(types).join("/")
    var memory = size > 0 ? Math.round(size / 1073741824) + " GB" : i18n("%1 GB USABLE", (kb / 1048576).toFixed(1))
    if (type) memory += " " + type + (speed ? "-" + speed : "")
    if (modules > 1) memory += " · " + i18np("%1 MODULE", "%1 MODULES", modules)

    var kernel = (os[0] || "").replace(/^(\S+)\s+(\d+(?:\.\d+){1,2}).*$/, "$1 $2")
    var rel = (os[1] || "").split("|")
    var distro = rel[0] || ""
    var like = (rel[2] || "").split(" ")[0]
    if (like && distro.toLowerCase().indexOf(like.toLowerCase()) < 0)
        distro += " / " + like.charAt(0).toUpperCase() + like.slice(1)

    return {
        processor: cpuName(cpu[0], Number(cpu[1]) || 0),
        gpu: gpus.length ? gpus.join(" + ") : i18nc("@info no graphics card", "NONE DETECTED"),
        gpuFound: gpus.length > 0,        // the gpu line is a translated text: test this instead
        memory: memory,
        system: kernel + (distro ? " · " + distro : ""),
        host: (os[2] || "").trim()
    }
}

// ---- discovery ----
// One cheap command, run when the card opens and once a minute after: the
// interface carrying the default route, and the fan sensors ksystemstats
// exposes (their ids depend on the board, e.g. lmsensors/asus-isa-000a/fan1).
var MARK_FANS = "@@FANS"
var DISCOVER = "ip -o route get 1.1.1.1 2>/dev/null || ip -o route show default 2>/dev/null;"
             + " echo @@GOV; cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null;"
             + " echo @@ADDR; ip -4 -o addr show 2>/dev/null;"
             + " echo @@DNS; resolvectl dns 2>/dev/null || grep '^nameserver' /etc/resolv.conf 2>/dev/null;"
             + " echo " + MARK_FANS + "; kstatsviewer --list 2>/dev/null | grep -E '^(lmsensors/[^ ]+/fan[0-9]+|gpu/gpu[0-9]+/usage) '"

// "cpu_fan" -> "CPU", "Chassis Fan 2" -> "CASE 2", "fan3" -> "FAN 3"
function fanLabel(name, id) {
    var n = (name || "").toLowerCase()
    var digit = (n.match(/(\d+)/) || id.match(/fan(\d+)$/) || ["", ""])[1]
    if (/pump|aio/.test(n)) return i18nc("@label fan name", "PUMP")
    if (/cpu/.test(n)) return "CPU"
    if (/gpu|vga/.test(n)) return "GPU"
    if (/chassis|case|sys|intake|exhaust/.test(n))
        return digit ? i18nc("@label fan name, %1 its number", "CASE %1", digit) : i18nc("@label fan name", "CASE")
    return digit ? i18nc("@label fan name, %1 its number", "FAN %1", digit) : i18nc("@label fan name", "FAN")
}

// The discovery output, cut at its @@MARK lines into { route, GOV, ADDR, DNS, FANS }.
function chunks(stdout) {
    var out = { route: "" }, cur = "route"
    String(stdout || "").split("\n").forEach(function (line) {
        var m = line.match(/^@@([A-Z]+)\s*$/)
        if (m) { cur = m[1]; out[cur] = ""; return }
        out[cur] = (out[cur] || "") + line + "\n"
    })
    return out
}

// Interface, governor, fans, and the network identity: LAN address and
// CIDR, gateway and first DNS server for the interface carrying the route.
function parseDiscovery(stdout) {
    var c = chunks(stdout)
    var route = c.route || ""
    var dev = route.match(/\bdev\s+(\S+)/)
    var iface = dev ? dev[1] : ""
    var via = route.match(/\bvia\s+(\S+)/)
    var src = route.match(/\bsrc\s+(\S+)/)
    var cidr = ""
    String(c.ADDR || "").split("\n").forEach(function (line) {
        var m = line.match(/^\d+:\s+(\S+)\s+inet\s+(\S+)/)
        if (m && m[1] === iface && !cidr) cidr = m[2]
    })
    var dns = ""
    var dnsText = String(c.DNS || "")
    var link = dnsText.match(new RegExp("\\(" + iface.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "\\):\\s*(\\S+)"))
    var global = dnsText.match(/^Global:\s*(\S+)/m)
    var ns = dnsText.match(/^nameserver\s+(\S+)/m)
    dns = link ? link[1] : global ? global[1] : ns ? ns[1] : ""
    var fans = [], gpus = []
    String(c.FANS || "").split("\n").forEach(function (line) {
        var m = line.match(/^(lmsensors\/\S+\/fan\d+)\s*(.*)$/)
        if (m) fans.push({ id: m[1], label: fanLabel(m[2], m[1]) })
        var g = line.match(/^gpu\/(gpu\d+)\/usage\s+(.*?)\s*Usage\s*$/)
        if (g) gpus.push({ id: g[1], name: g[2] })
    })
    gpus.sort(function (a, b) { return Number(a.id.slice(3)) - Number(b.id.slice(3)) })
    fans.sort(function (a, b) { return a.label < b.label ? -1 : a.label > b.label ? 1 : 0 })
    return {
        iface: iface, governor: String(c.GOV || "").trim(), fans: fans, gpus: gpus,
        localIp: src ? src[1] : (cidr ? cidr.split("/")[0] : ""), cidr: cidr,
        gateway: via ? via[1] : "", dns: dns
    }
}

// One-off GPU details for the hover card: kernel driver, PCIe link and fan
// duty of the first display card, plus a driver version (NVIDIA's own, else
// the kernel the in-tree driver ships with).
// PCI vendor id of a GPU from its name, so the details describe the same card.
function gpuVendorId(name) {
    var n = String(name || "")
    return /nvidia|geforce|rtx|gtx|quadro|tesla/i.test(n) ? "0x10de"
         : /radeon|amd|ati\b|rembrandt|navi|vega|polaris|phoenix/i.test(n) ? "0x1002"
         : /intel|iris|uhd|arc\b|xe\b/i.test(n) ? "0x8086" : ""
}
// The first display card of that vendor (any card when unknown).
function gpuInfoCommand(vendorId) {
    return GPUINFO.replace("[ -r $d/vendor ] || continue;",
                           "[ -r $d/vendor ] || continue;" + (vendorId ? " [ \"$(cat $d/vendor)\" = " + vendorId + " ] || continue;" : ""))
}
var GPUINFO = "for c in /sys/class/drm/card[0-9]; do d=$c/device; [ -r $d/vendor ] || continue;"
            + " echo DRIVER $(basename $(readlink -f $d/driver) 2>/dev/null);"
            + " echo LINK $(cat $d/current_link_speed 2>/dev/null) x$(cat $d/current_link_width 2>/dev/null);"
            + " echo PWM $(cat $d/hwmon/hwmon*/pwm1 2>/dev/null | head -1); break; done;"
            + " echo NV $(head -1 /proc/driver/nvidia/version 2>/dev/null | grep -oE '[0-9]+\\.[0-9]+(\\.[0-9]+)?' | head -1);"
            + " echo KERNEL $(uname -r)"

function parseGpuInfo(stdout) {
    var v = {}
    String(stdout || "").split("\n").forEach(function (line) {
        var m = line.match(/^([A-Z]+)\s*(.*)$/)
        if (m) v[m[1]] = m[2].trim()
    })
    var driver = (v.DRIVER || "").toUpperCase()
    var link = (v.LINK || "").replace(/^x$/, "").replace(/ PCIe/, "")
    var pwm = Number(v.PWM)
    return {
        driver: driver ? driver + " " + (v.NV || (v.KERNEL || "").split("-")[0]) : "",
        link: link && link.indexOf("GT/s") >= 0 ? link : "",
        fanDuty: v.PWM !== "" && isFinite(pwm) ? Math.round(pwm / 255 * 100) : -1
    }
}

function rpm(v) { return Math.round(num(v)) + " RPM" }

// The Guide's verdict, judged in order: heat, then load, then the fans. `load`
// is the busier of CPU and GPU, `hottest` the hotter of the two (°C), `fans`
// the current RPM of each active fan.
function commentary(load, hottest, fans) {
    fans = fans || []
    var fastest = fans.length ? Math.max.apply(null, fans) : -1
    if (hottest > MELTDOWN) return i18n("MELTDOWN IMMINENT. CONSULTING EARTH V2 BLUEPRINTS.")
    if (load > 85 || hottest > HOT) return i18n("SILICON ANXIETY DETECTED. COOLING TOWEL STRONGLY ADVISED.")
    if (fastest > 1800) return i18n("COOLING TURBINES AT HIGH VELOCITY. DISPLACING SUB-ETHA THERMALS.")
    if (load >= 40) return i18n("INFINITE IMPROBABILITY ENGINE CALCULATING PROBABILITIES.")
    if (fastest >= 0 && fastest < 600) return i18n("ACOUSTIC RESONANCE MINIMAL. RELATIVELY HARMLESS.")
    return i18n("EDDIE COMPUTE CORE NOMINAL. TEA CONSUMPTION UNINTERRUPTED.")
}
