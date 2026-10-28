.pragma library
.import "../../common/i18n.js" as T

// Translated strings go through common/i18n.js (see there).
function i18n() { return T.tr("i18n", Array.prototype.slice.call(arguments)) }
function i18nc() { return T.tr("i18nc", Array.prototype.slice.call(arguments)) }
function i18np() { return T.tr("i18np", Array.prototype.slice.call(arguments)) }

// Parses one sample of the disk probe (df + lsblk + /proc/diskstats, see
// COMMAND) into volume records for the pill cards, and picks the Guide's
// commentary for the set.

var MARK_LSBLK = "@@LSBLK"
var MARK_STATS = "@@STATS"
// df lists real filesystems only; lsblk adds label, transport and removability
// per device path; diskstats gives the I/O counters behind the R/W rates.
var COMMAND = "timeout 5 df -B1 --output=source,fstype,size,used,avail,target"
            + " -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs -x ramfs 2>/dev/null;"
            + " echo " + MARK_LSBLK + "; lsblk -J -b -o PATH,KNAME,LABEL,FSTYPE,RM,HOTPLUG,ROTA,TRAN,TYPE 2>/dev/null;"
            + " echo " + MARK_STATS + "; cat /proc/diskstats"

var CRITICAL = 90   // default warningThreshold: used % at which a pill pulses CRITICAL QUOTA EXCEEDED

function section(text, from, to) {
    var a = from ? text.indexOf(from) : 0
    if (a < 0) return ""
    if (from) a += from.length
    var b = to ? text.indexOf(to, a) : -1
    return b < 0 ? text.slice(a) : text.slice(a, b)
}

// lsblk -J nests partitions under their disk on some versions and lists them
// flat on others; either way, carry the disk's transport and flags down.
function blockInfo(json) {
    var map = {}
    var tree
    try { tree = JSON.parse(json).blockdevices || [] } catch (e) { return map }
    function walk(list, inherited) {
        for (var i = 0; i < list.length; i++) {
            var d = list[i]
            var info = {
                kname: d.kname || "",
                label: d.label || "",
                tran: d.tran || inherited.tran || "",
                rota: d.rota === true || d.rota === "1" || inherited.rota,
                removable: d.rm === true || d.rm === "1" || d.hotplug === true || d.hotplug === "1" || inherited.removable
            }
            if (d.path) map[d.path] = info
            if (d.children) walk(d.children, info)
        }
    }
    walk(tree, { tran: "", rota: false, removable: false })
    return map
}

// { kname: { read: bytes, written: bytes } } from /proc/diskstats
// (fields 6 and 10 are sectors of 512 bytes).
function ioCounters(text) {
    var map = {}
    var lines = text.split("\n")
    for (var i = 0; i < lines.length; i++) {
        var f = lines[i].trim().split(/\s+/)
        if (f.length < 10) continue
        map[f[2]] = { read: Number(f[5]) * 512, written: Number(f[9]) * 512 }
    }
    return map
}

// Mounts that are not storage a person thinks of as "a disk".
function hidden(target, fstype, size, showBoot) {
    if (size <= 0) return true
    if (/^\/(tmp|snap|proc|sys|dev)(\/|$)/.test(target)) return true
    if (/^\/run\//.test(target) && !/^\/run\/media\//.test(target)) return true
    if (/^\/var\/lib\/(snapd|docker|containers)\//.test(target)) return true
    if (/^fuse\./.test(fstype) && !/^fuse\.(sshfs|rclone|gocryptfs|encfs)/.test(fstype)) return true
    if (!showBoot && /^\/(boot|efi)(\/|$)/.test(target)) return true
    return false
}

// The mount a volume is named after when it is mounted several times
// (btrfs subvolumes): / first, then /home, then the shortest path.
function rank(target) { return target === "/" ? 0 : target === "/home" ? 1 : 2 + target.length }

function kindOf(info, source) {
    if (info.removable || info.tran === "usb") return "usb"
    if (info.tran === "nvme" || /\/nvme/.test(source)) return "nvme"
    if (info.rota) return "hdd"
    if (/^\/dev\//.test(source)) return "ssd"
    return "network"
}

function volumeName(info, kind, target) {
    if (info.label) return info.label.toUpperCase().replace(/[\s-]+/g, "_")
    var role = target === "/" ? "ROOT" : target === "/home" ? "HOME"
             : (target.split("/").filter(s => s).pop() || "VOLUME").toUpperCase().replace(/[\s-]+/g, "_")
    return kind.toUpperCase() + "_" + role
}

// "342 GB", "2.0 TB": decimal units, as on the drive's box.
function bytes(n) {
    var units = ["B", "KB", "MB", "GB", "TB", "PB"]
    var i = 0
    while (n >= 1000 && i < units.length - 1) { n /= 1000; i++ }
    return (i === 0 || n >= 100 ? Math.round(n) : n.toFixed(1)) + " " + units[i]
}
function rate(bps) { return bps < 1000 ? "0 B/s" : bytes(bps) + "/s" }

// An amount in the storageUnit setting: auto picks the unit, GB and TB are fixed.
function amount(n, unit) {
    if (unit === "GB") { var g = n / 1e9; return (g >= 100 ? Math.round(g) : g.toFixed(1)) + " GB" }
    if (unit === "TB") return (n / 1e12).toFixed(2) + " TB"
    return bytes(n)
}

// The figure a card shows, per storageUnit ("auto", "GB", "TB", "percent")
// and valueFormat ("free", "used", "both").
function valueText(v, unit, format) {
    var used = v.usedPercentage, free = 100 - v.usedPercentage
    if (unit === "percent") {
        return format === "used" ? i18n("%1% USED", used)
             : format === "both" ? i18n("%1% USED", used) + " · " + i18n("%1% FREE", free)
             : i18n("%1% FREE", free)
    }
    return format === "used" ? i18n("%1 USED", amount(v.usedBytes, unit))
         : format === "both" ? amount(v.usedBytes, unit) + " / " + amount(v.totalBytes, unit)
         : i18n("%1 FREE", amount(v.availableBytes, unit))
}

// selected: the selectedMountPoints setting ("all", or mount paths). A volume
// matches if any of its mounts is selected, so ticking /home finds it even
// when it is a btrfs subvolume shown under /.
function isSelected(v, selected, hideRemovable) {
    if (hideRemovable && v.isRemovable) return false
    if (!selected) return true
    if (selected.indexOf("all") >= 0) return true
    var mounts = v.mounts.split("\n")
    for (var i = 0; i < mounts.length; i++)
        if (selected.indexOf(mounts[i]) >= 0) return true
    return false
}

// Volume records from one probe sample. `previous` is the last sample's
// { counters, time } so read/write rates can be derived.
// opts: { showBoot: list /boot and EFI, threshold: warning used % }
function parse(stdout, previous, now, opts) {
    opts = opts || {}
    var showBoot = !!opts.showBoot
    var threshold = opts.threshold > 0 ? opts.threshold : CRITICAL
    var df = section(stdout, "", MARK_LSBLK).split("\n").slice(1)
    var blocks = blockInfo(section(stdout, MARK_LSBLK, MARK_STATS))
    var counters = ioCounters(section(stdout, MARK_STATS, ""))
    var dt = previous && previous.time ? (now - previous.time) / 1000 : 0

    var bySource = {}
    var order = []
    for (var i = 0; i < df.length; i++) {
        var f = df[i].trim().split(/\s+/)
        if (f.length < 6) continue
        var source = f[0], fstype = f[1]
        var size = Number(f[2]), used = Number(f[3]), avail = Number(f[4])
        var target = f.slice(5).join(" ")
        if (hidden(target, fstype, size, showBoot)) continue
        var v = bySource[source]
        if (v) {
            v.targets.push(target)
            if (rank(target) < rank(v.mountPoint)) v.mountPoint = target
            continue
        }
        bySource[source] = { source: source, fsType: fstype, totalBytes: size, usedBytes: used,
                             availableBytes: avail, mountPoint: target, targets: [target] }
        order.push(source)
    }

    var volumes = order.map(function (src) {
        var v = bySource[src]
        var info = blocks[src] || { kname: "", label: "", tran: "", rota: false, removable: false }
        var kind = kindOf(info, src)
        // df's Use%: used against what a user can write (excludes root-reserved blocks).
        var pct = v.usedBytes + v.availableBytes > 0
                ? Math.round(100 * v.usedBytes / (v.usedBytes + v.availableBytes)) : 0
        var io = counters[info.kname]
        var prev = previous && previous.counters ? previous.counters[info.kname] : null
        var readRate = io && prev && dt > 0 ? Math.max(0, (io.read - prev.read) / dt) : 0
        var writeRate = io && prev && dt > 0 ? Math.max(0, (io.written - prev.written) / dt) : 0
        return {
            source: src,
            deviceNode: src,
            label: volumeName(info, kind, v.mountPoint),
            mountPoint: v.mountPoint,
            // Every mount of the device, newline-separated (a ListModel role
            // cannot hold an array), the named one first.
            mounts: v.targets.sort((a, b) => rank(a) - rank(b)).join("\n"),
            extraMounts: v.targets.length - 1,
            fsType: v.fsType,
            kind: kind,
            isRemovable: kind === "usb",
            totalBytes: v.totalBytes,
            usedBytes: v.usedBytes,
            availableBytes: v.availableBytes,
            usedPercentage: pct,
            readRate: readRate,
            writeRate: writeRate,
            hasIo: !!io,
            critical: pct >= threshold
        }
    })
    volumes.sort(function (a, b) {
        if (a.isRemovable !== b.isRemovable) return a.isRemovable ? 1 : -1
        return rank(a.mountPoint) - rank(b.mountPoint)
    })
    return { volumes: volumes, counters: counters, time: now }
}

// The Guide's verdict on the set, judged by its fullest volume's free share.
function commentary(volumes) {
    if (!volumes.length) return i18n("NO STORAGE VOLUMES DETECTED. SUSPICIOUSLY TIDY.")
    var free = 100
    for (var i = 0; i < volumes.length; i++) free = Math.min(free, 100 - volumes[i].usedPercentage)
    if (free < 5) return i18n("IMPROBABILITY COLLAPSE IMMINENT. TOWEL CANNOT SAVE THIS DISK.")
    if (free < 15) return i18n("SECTOR MEMORY FULL. IMMEDIATE PURGE STRONGLY ADVISED.")
    if (free < 40) return i18n("STORAGE DENSITY RISING. A MODEST PURGE WOULD NOT GO AMISS.")
    if (free < 85) return i18n("DATA ENTROPY ACCUMULATING AT NORMAL PARAMETERS.")
    return i18n("VAST EXPANSES OF SUB-ETHA SILICON VACUUM AVAILABLE.")
}
