import QtQuick
import org.kde.plasma.plasma5support as P5Support
import org.kde.ksysguard.sensors as Sensors
import "code/system.js" as Sys

// The hardware telemetry behind the system pills: ksystemstats sensors pushed
// over D-Bus and throttled to `interval`, a once-a-minute discovery of the
// active interface and fan sensors, the one-off host profile, and a rolling
// HISTORY-sample history of every reading for the sparklines. Nothing runs
// unless `live` (the card is on screen and the session unlocked);
// `panelKinds` keeps just the readings the panel item shows running while
// the popup is closed (cpuLoad cpuTemp gpuTemp ramUsage netSpeed), with
// their history, so the panel's hover card opens on a drawn sparkline.
// Network identity: LAN address, CIDR, gateway and DNS from the discovery
// pass; the public address from api.ipify.org, fetched once the network
// pill is wanted and again when the connection changes, at most every
// 15 minutes.
Item {
    id: feed

    property var sensors: ["cpu", "ram", "net", "gpu", "fans"]
    property int interval: 2000
    property bool live: false
    property var panelKinds: []
    property string gpuChoice: "auto"     // "auto" (the first GPU) or a ksystemstats id such as "gpu1"
    property bool wantSpecs: false
    function wants(kind) { return sensors.indexOf(kind) >= 0 }
    function panelWants(kind) { return panelKinds.indexOf(kind) >= 0 }

    // ---- sensors ----
    component Feed: Sensors.Sensor { updateRateLimit: feed.interval }
    Feed { id: cpuUsageSensor;  sensorId: "cpu/all/usage";              enabled: (feed.live && feed.wants("cpu")) || feed.panelWants("cpuLoad") || feed.panelWants("cpuTemp") }
    Feed { id: cpuTempSensor;   sensorId: "cpu/all/maximumTemperature"; enabled: (feed.live && feed.wants("cpu")) || feed.panelWants("cpuTemp") || feed.panelWants("cpuLoad") }
    Feed { id: cpuFreqSensor;   sensorId: "cpu/all/averageFrequency";   enabled: feed.live && feed.wants("cpu") }
    Feed { id: cpuUserSensor;   sensorId: "cpu/all/user";               enabled: feed.live && feed.wants("cpu") }
    Feed { id: cpuSystemSensor; sensorId: "cpu/all/system";             enabled: feed.live && feed.wants("cpu") }
    Feed { id: cpuWaitSensor;   sensorId: "cpu/all/wait";               enabled: feed.live && feed.wants("cpu") }
    Feed { id: cpuMinFreqSensor; sensorId: "cpu/all/minimumFrequency";  enabled: feed.live && feed.wants("cpu") }
    Feed { id: cpuMaxFreqSensor; sensorId: "cpu/all/maximumFrequency";  enabled: feed.live && feed.wants("cpu") }
    Feed { id: cpuCoresSensor;  sensorId: "cpu/all/coreCount";          enabled: feed.live && feed.wants("cpu") }
    Feed { id: memUsedSensor;   sensorId: "memory/physical/used";       enabled: (feed.live && feed.wants("ram")) || feed.panelWants("ramUsage") }
    Feed { id: memTotalSensor;  sensorId: "memory/physical/total";      enabled: (feed.live && feed.wants("ram")) || feed.panelWants("ramUsage") }
    Feed { id: memAppSensor;    sensorId: "memory/physical/application"; enabled: feed.live && feed.wants("ram") }
    Feed { id: memCacheSensor;  sensorId: "memory/physical/cache";      enabled: feed.live && feed.wants("ram") }
    Feed { id: swapUsedSensor;  sensorId: "memory/swap/used";           enabled: feed.live && feed.wants("ram") }
    Feed { id: swapTotalSensor; sensorId: "memory/swap/total";          enabled: feed.live && feed.wants("ram") }
    Feed { id: gpuNameSensor;   sensorId: feed.gpuPrefix + "name";              enabled: (feed.live && feed.wants("gpu")) || feed.panelWants("gpuTemp") }
    Feed { id: gpuUsageSensor;  sensorId: feed.gpuPrefix + "usage";             enabled: (feed.live && feed.wants("gpu")) || feed.panelWants("gpuTemp") }
    Feed { id: gpuTempSensor;   sensorId: feed.gpuPrefix + "temperature";       enabled: (feed.live && feed.wants("gpu")) || feed.panelWants("gpuTemp") }
    Feed { id: vramUsedSensor;  sensorId: feed.gpuPrefix + "usedVram";          enabled: feed.live && feed.wants("gpu") }
    Feed { id: vramTotalSensor; sensorId: feed.gpuPrefix + "totalVram";         enabled: feed.live && feed.wants("gpu") }
    Feed { id: gpuClockSensor;  sensorId: feed.gpuPrefix + "coreFrequency";     enabled: feed.live && feed.wants("gpu") }
    // GPUs found by discovery, [{ id: "gpu0", name }]; the chosen one, or the first.
    property var gpus: []
    readonly property string gpuId: gpus.some(g => g.id === gpuChoice) ? gpuChoice : gpus.length ? gpus[0].id : "gpu0"
    readonly property string gpuPrefix: "gpu/" + gpuId + "/"
    readonly property string gpuInfoCommand: Sys.gpuInfoCommand(Sys.gpuVendorId(gpuName))
    onGpuIdChanged: { gpuHistory = []; gpuTempHistory = []; gpuInfo = null }
    readonly property string netPrefix: "network/" + (iface || "all") + "/"
    Feed { id: netRxSensor;     sensorId: feed.netPrefix + "download";  enabled: (feed.live && feed.wants("net")) || feed.panelWants("netSpeed") }
    Feed { id: netTxSensor;     sensorId: feed.netPrefix + "upload";    enabled: (feed.live && feed.wants("net")) || feed.panelWants("netSpeed") }
    Feed { id: netRxTotalSensor; sensorId: feed.netPrefix + "totalDownload"; enabled: feed.live && feed.wants("net") }
    Feed { id: netTxTotalSensor; sensorId: feed.netPrefix + "totalUpload";   enabled: feed.live && feed.wants("net") }
    Feed { id: netNameSensor;   sensorId: feed.netPrefix + "network";   enabled: feed.live && feed.wants("net") && feed.iface !== "" }

    // Fans: one sensor per fan the discovery found.
    property var fanDefs: []
    Instantiator {
        id: fanFeeds
        model: feed.fanDefs
        delegate: Sensors.Sensor {
            required property var modelData
            readonly property string label: modelData.label
            sensorId: modelData.id
            updateRateLimit: feed.interval
            enabled: feed.live && feed.wants("fans")
        }
    }
    // A header that has never reported a spin is an empty one; a fan that has
    // spun once stays listed even when it stops (a GPU fan at idle).
    property var fanSeen: ({})
    function readFans() {
        var out = []
        var seen = fanSeen
        for (var i = 0; i < fanFeeds.count; i++) {
            var s = fanFeeds.objectAt(i)
            if (!s) continue
            var rpm = Sys.num(s.value)
            if (rpm > 0) seen[s.sensorId] = true
            if (seen[s.sensorId]) out.push({ label: s.label, rpm: rpm })
        }
        fanSeen = seen
        return out
    }

    // ---- discovery (interface, fans) and the host profile ----
    P5Support.DataSource {
        id: shell
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source)
            if (source === Sys.SPECS) {
                feed.specs = Sys.parseSpecs(data["stdout"])
                return
            }
            if (source === feed.gpuInfoCommand) {
                feed.gpuInfo = Sys.parseGpuInfo(data["stdout"])
                return
            }
            var found = Sys.parseDiscovery(data["stdout"])
            feed.iface = found.iface
            feed.governor = found.governor
            feed.discovered = true
            feed.localIp = found.localIp
            feed.cidr = found.cidr
            feed.gateway = found.gateway
            feed.dns = found.dns
            if (feed.wanState === "waiting") feed.fetchPublicIp()   // discovery found no address: offline
            if (JSON.stringify(found.fans) !== JSON.stringify(feed.fanDefs)) feed.fanDefs = found.fans
            if (JSON.stringify(found.gpus) !== JSON.stringify(feed.gpus)) feed.gpus = found.gpus
        }
    }
    function run(cmd) { if (shell.connectedSources.indexOf(cmd) < 0) shell.connectSource(cmd) }
    readonly property bool sampling: live || panelKinds.length > 0
    Timer { interval: 60000; repeat: true; running: feed.sampling; triggeredOnStart: true; onTriggered: feed.run(Sys.DISCOVER) }
    property var specs: null
    readonly property bool specsWanted: wantSpecs && live && specs === null
    onSpecsWantedChanged: if (specsWanted) run(Sys.SPECS)
    property var gpuInfo: null            // { driver, link, fanDuty }
    // Run once the GPU's name is known, so the details come from the same card.
    readonly property bool gpuInfoWanted: live && wants("gpu") && gpuInfo === null && gpuName !== ""
    onGpuInfoWantedChanged: if (gpuInfoWanted) run(gpuInfoCommand)

    // ---- network identity ----
    property string localIp: ""
    property string cidr: ""              // e.g. 192.168.1.91/24
    property string gateway: ""
    property string dns: ""
    property string publicIp: ""
    property string wanState: "idle"      // idle | waiting (for discovery) | resolving | ok | offline
    property bool discovered: false
    property double wanFetchedAt: 0
    readonly property bool wanWanted: wants("net") && (live || panelWants("netSpeed"))
    // Once when first wanted, then on a change of connection; a change inside
    // 15 minutes of the last lookup waits for the window to pass.
    function fetchPublicIp() {
        if (!wanWanted) return
        if (localIp === "") { wanState = discovered ? "offline" : "waiting"; return }
        if (wanState === "resolving") return
        var wait = wanFetchedAt + 15 * 60000 - Date.now()
        if (wanState === "ok" && wait > 0) { wanDeferred.interval = wait; wanDeferred.restart(); return }
        wanState = "resolving"
        wanFetchedAt = Date.now()
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            wanTimeout.stop()
            var ip = String(xhr.responseText || "").trim()
            if (xhr.status === 200 && /^[0-9a-fA-F:.]{3,45}$/.test(ip)) { feed.publicIp = ip; feed.wanState = "ok" }
            else feed.wanState = "offline"
        }
        xhr.open("GET", "https://api.ipify.org")
        xhr.send()
        wanTimeout.request = xhr
        wanTimeout.restart()
    }
    Timer { id: wanDeferred; onTriggered: feed.fetchPublicIp() }
    Timer {
        id: wanTimeout
        property var request: null
        interval: 10000
        onTriggered: { if (request) request.abort(); feed.wanState = "offline" }
    }
    onWanWantedChanged: if (wanWanted && wanState === "idle") fetchPublicIp()
    onLocalIpChanged: if (wanState !== "idle") fetchPublicIp()
    onIfaceChanged: if (wanState !== "idle") fetchPublicIp()

    // ---- readings ----
    property string iface: ""
    property string governor: ""          // cpufreq scaling governor, e.g. "performance"
    readonly property real cpuUsage: Sys.num(cpuUsageSensor.value)
    readonly property real cpuTemp: Sys.num(cpuTempSensor.value)
    readonly property real cpuFreq: Sys.num(cpuFreqSensor.value)
    readonly property real cpuUser: Sys.num(cpuUserSensor.value)
    readonly property real cpuSystem: Sys.num(cpuSystemSensor.value)
    readonly property real cpuWait: Sys.num(cpuWaitSensor.value)
    readonly property real cpuMinFreq: Sys.num(cpuMinFreqSensor.value)
    readonly property real cpuMaxFreq: Sys.num(cpuMaxFreqSensor.value)
    readonly property int cpuCores: Sys.num(cpuCoresSensor.value)
    readonly property real memUsed: Sys.num(memUsedSensor.value)
    readonly property real memTotal: Sys.num(memTotalSensor.value)
    readonly property real memPercent: memTotal > 0 ? 100 * memUsed / memTotal : 0
    readonly property real memApps: Sys.num(memAppSensor.value)
    readonly property real memCache: Sys.num(memCacheSensor.value)
    readonly property real swapUsed: Sys.num(swapUsedSensor.value)
    readonly property real swapTotal: Sys.num(swapTotalSensor.value)
    readonly property string gpuName: gpuNameSensor.value ? String(gpuNameSensor.value) : ""
    readonly property bool hasGpu: gpuName !== "" || Sys.num(vramTotalSensor.value) > 0
    readonly property real gpuUsage: Sys.num(gpuUsageSensor.value)
    readonly property real gpuTemp: Sys.num(gpuTempSensor.value)
    readonly property real vramUsed: Sys.num(vramUsedSensor.value)
    readonly property real vramTotal: Sys.num(vramTotalSensor.value)
    readonly property real gpuClock: Sys.num(gpuClockSensor.value)      // MHz
    readonly property real rx: Sys.num(netRxSensor.value)
    readonly property real tx: Sys.num(netTxSensor.value)
    readonly property real rxTotal: Sys.num(netRxTotalSensor.value)    // bytes this session
    readonly property real txTotal: Sys.num(netTxTotalSensor.value)
    readonly property string networkName: netNameSensor.value ? String(netNameSensor.value) : ""
    property var fans: []

    // ---- histories: one sample per interval, never per frame ----
    property var cpuHistory: []
    property var cpuTempHistory: []
    property var ramHistory: []
    property var gpuHistory: []
    property var gpuTempHistory: []
    property var rxHistory: []
    property var txHistory: []
    property var fanHistory: ({})      // fan label -> RPM samples
    Timer {
        interval: feed.interval
        repeat: true
        running: feed.sampling
        triggeredOnStart: true
        onTriggered: {
            feed.cpuHistory = Sys.push(feed.cpuHistory, feed.cpuUsage)
            feed.cpuTempHistory = Sys.push(feed.cpuTempHistory, feed.cpuTemp)
            feed.ramHistory = Sys.push(feed.ramHistory, feed.memPercent)
            feed.gpuHistory = Sys.push(feed.gpuHistory, feed.gpuUsage)
            feed.gpuTempHistory = Sys.push(feed.gpuTempHistory, feed.gpuTemp)
            feed.rxHistory = Sys.push(feed.rxHistory, feed.rx)
            feed.txHistory = Sys.push(feed.txHistory, feed.tx)
            var fans = feed.readFans()
            var fh = {}
            fans.forEach(f => fh[f.label] = Sys.push(feed.fanHistory[f.label] || [], f.rpm))
            feed.fanHistory = fh
            feed.fans = fans
        }
    }

    readonly property real hottest: Math.max(cpuTemp, hasGpu ? gpuTemp : 0)
    readonly property string commentary: Sys.commentary(Math.max(cpuUsage, gpuUsage), hottest,
                                                        wants("fans") ? fans.map(f => f.rpm) : [])
}
