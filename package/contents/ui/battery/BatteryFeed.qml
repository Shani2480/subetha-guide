import QtQuick
import org.kde.plasma.plasma5support as P5Support
import org.kde.ksysguard.sensors as Sensors
import "code/power.js" as Power

// The power data behind the battery pills. The powermanagement engine
// publishes a "Battery" summary (with the time estimate), "AC Adapter",
// "Power Profiles" and one "BatteryN" source per UPower battery: the laptop's
// own plus every mouse, keyboard, headset, controller, pen or phone that
// reports a level. `model` holds the selected devices, diffed in place so
// only a newly connected device gets a fresh card. `watts` is the laptop
// batteries' signed charge rate, sampled only while `live` and `wantRate`.
Item {
    id: feed

    property bool running: true           // false: disconnect from the engine entirely
    property var selected: ["all"]        // selectedDevices
    property int threshold: 15
    property bool showEstimate: true
    property bool live: false
    property bool wantRate: true
    property int interval: 2000

    readonly property alias model: deviceModel
    property var devices: []
    readonly property var pmData: pmSource.data
    readonly property bool acPlugged: !!(pmData["AC Adapter"] && pmData["AC Adapter"]["Plugged in"])
    readonly property var profileData: pmData["Power Profiles"] || ({})
    readonly property var profiles: profileData["Installed"] ? (profileData["Profiles"] || []) : []
    readonly property string currentProfile: profileData["Current Profile"] || ""
    readonly property string commentary: Power.commentary(devices, acPlugged)
    // The panel shows the laptop battery, or the weakest peripheral without one.
    readonly property var panelDevice: {
        var pick = null
        for (var i = 0; i < devices.length; i++) {
            var d = devices[i]
            if (d.primary) return d
            if (!pick || d.percent < pick.percent) pick = d
        }
        return pick
    }
    readonly property bool anyCritical: devices.some(d => d.critical)

    ListModel { id: deviceModel }

    P5Support.DataSource {
        id: pmSource
        engine: "powermanagement"
        connectedSources: !feed.running ? [] : sources.filter(s => s === "Battery" || s === "AC Adapter"
                                           || s === "Power Profiles" || /^Battery\d+$/.test(s))
        onNewData: Qt.callLater(feed.sync)
        onSourceRemoved: Qt.callLater(feed.sync)
    }

    function sync() {
        var summary = pmSource.data["Battery"] || {}
        var names = pmSource.sources.filter(s => /^Battery\d+$/.test(s) && pmSource.data[s]
                                              && pmSource.data[s]["Percent"] !== undefined)
        var primaryCount = names.filter(s => pmSource.data[s]["Is Power Supply"]).length
        var opts = { threshold: threshold, showEstimate: showEstimate }
        var fresh = names.map(s => Power.describe(s, pmSource.data[s], summary, primaryCount, opts))
                         .filter(d => Power.isSelected(d, selected))
        fresh.sort(Power.compare)

        var keep = {}
        fresh.forEach(d => keep[d.source] = true)
        for (var i = deviceModel.count - 1; i >= 0; i--)
            if (!keep[deviceModel.get(i).source]) deviceModel.remove(i)
        for (var j = 0; j < fresh.length; j++) {
            var at = -1
            for (var k = j; k < deviceModel.count; k++)
                if (deviceModel.get(k).source === fresh[j].source) { at = k; break }
            if (at < 0) deviceModel.insert(j, fresh[j])
            else {
                if (at !== j) deviceModel.move(at, j, 1)
                deviceModel.set(j, fresh[j])
            }
        }
        devices = fresh
    }
    onSelectedChanged: sync()
    onThresholdChanged: sync()
    onShowEstimateChanged: sync()
    Component.onCompleted: sync()

    function setProfile(profile) {
        var service = pmSource.serviceForSource("PowerDevil")
        var op = service.operationDescription("setPowerProfile")
        op.profile = profile
        service.startOperationCall(op)
    }

    // ---- charge rate ----
    readonly property bool rateLive: live && wantRate
    property var rateSensorIds: null      // null: not looked up yet; []: none, use sysfs
    property real sysfsWatts: NaN
    Instantiator {
        id: rateFeeds
        model: feed.rateSensorIds || []
        delegate: Sensors.Sensor {
            required property string modelData
            sensorId: modelData
            updateRateLimit: feed.interval
            enabled: feed.rateLive
        }
    }
    property real sensorWatts: NaN
    readonly property real watts: rateSensorIds && rateSensorIds.length > 0 ? sensorWatts : sysfsWatts

    P5Support.DataSource {
        id: shell
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source)
            if (source === Power.HEALTH)
                feed.health = Power.parseHealth(data["stdout"])
            else if (source === Power.RATE_SENSORS)
                feed.rateSensorIds = String(data["stdout"] || "").split("\n").filter(l => l !== "")
            else
                feed.sysfsWatts = Power.parseSysfsRate(data["stdout"])
        }
    }
    function run(cmd) { if (shell.connectedSources.indexOf(cmd) < 0) shell.connectSource(cmd) }
    property var health: null             // { health: % of design capacity, cycles }, -1 where unknown
    readonly property bool healthWanted: live && health === null
    onHealthWantedChanged: if (healthWanted) run(Power.HEALTH)
    onRateLiveChanged: if (rateLive && rateSensorIds === null) run(Power.RATE_SENSORS)
    Timer {
        interval: feed.interval
        repeat: true
        running: feed.rateLive && feed.rateSensorIds !== null
        triggeredOnStart: true
        onTriggered: {
            if (feed.rateSensorIds.length === 0) { feed.run(Power.RATE_SYSFS); return }
            var sum = NaN
            for (var i = 0; i < rateFeeds.count; i++) {
                var s = rateFeeds.objectAt(i)
                var v = s ? Number(s.value) : NaN
                if (isFinite(v)) sum = (isNaN(sum) ? 0 : sum) + v
            }
            feed.sensorWatts = sum
        }
    }
}
