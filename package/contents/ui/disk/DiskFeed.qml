import QtQuick
import org.kde.plasma.plasma5support as P5Support
import "code/disk.js" as Disk

// The storage data behind the volume pills: one shell probe (df + lsblk +
// /proc/diskstats, see Disk.COMMAND) through the executable engine, every
// 2 s while the card is on screen (`fast`) for the live I/O rates, once a
// minute otherwise. `model` holds the selected volumes, updated in place so
// their cards survive each sample.
Item {
    id: feed

    property bool running: true
    property bool fast: false
    property var selected: ["/"]          // selectedMountPoints
    property bool hideRemovable: false
    property bool showBoot: false
    property int threshold: 90

    readonly property alias model: volumeModel
    property var volumes: []
    readonly property string commentary: Disk.commentary(volumes)
    // The panel shows the root volume, or the fullest one without a root.
    readonly property var panelVolume: {
        var pick = null
        for (var i = 0; i < volumes.length; i++) {
            if (volumes[i].mountPoint === "/") return volumes[i]
            if (!pick || volumes[i].usedPercentage > pick.usedPercentage) pick = volumes[i]
        }
        return pick
    }
    readonly property bool anyCritical: volumes.some(v => v.critical)

    ListModel { id: volumeModel }
    property var lastSample: null

    P5Support.DataSource {
        id: probe
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source)
            if (data["exit code"] === 0 || data["stdout"]) feed.apply(data["stdout"])
        }
    }
    function sample() {
        if (probe.connectedSources.indexOf(Disk.COMMAND) < 0) probe.connectSource(Disk.COMMAND)
    }
    Timer {
        interval: feed.fast ? 2000 : 60000
        running: feed.running
        repeat: true
        triggeredOnStart: true
        onTriggered: feed.sample()
    }
    onFastChanged: if (fast && running) sample()

    // A fresh probe (stdout) re-parses; undefined only re-filters the last one.
    function apply(stdout) {
        if (stdout !== undefined)
            lastSample = Disk.parse(stdout, lastSample, Date.now(), { showBoot: showBoot, threshold: threshold })
        if (!lastSample) return
        var fresh = lastSample.volumes.filter(v => Disk.isSelected(v, selected, hideRemovable))
        var keep = {}
        fresh.forEach(v => keep[v.source] = true)
        for (var i = volumeModel.count - 1; i >= 0; i--)
            if (!keep[volumeModel.get(i).source]) volumeModel.remove(i)
        for (var j = 0; j < fresh.length; j++) {
            var at = -1
            for (var k = j; k < volumeModel.count; k++)
                if (volumeModel.get(k).source === fresh[j].source) { at = k; break }
            if (at < 0) volumeModel.insert(j, fresh[j])
            else {
                if (at !== j) volumeModel.move(at, j, 1)
                volumeModel.set(j, fresh[j])
            }
        }
        volumes = fresh
    }
    onShowBootChanged: sample()
    onThresholdChanged: sample()
    onSelectedChanged: apply(undefined)
    onHideRemovableChanged: apply(undefined)
}
