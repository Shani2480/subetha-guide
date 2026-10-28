import QtQuick
import org.kde.plasma.plasma5support as P5Support
import "skins.js" as Skins

// Community skins installed under ~/.local/share/subetha/themes/<id>/ by
// contents/tools/skin_installer.sh. skinListModel holds every installed skin;
// `style` is the active one's look, checked, for SubEthaTheme.skin. The
// widget and the Theme Store each keep one.
//
// A skin is data, never code; skins.js parses skin.json (and is shared with
// the Sub-Etha System Monitor, so both apps read a skin alike).
QtObject {
    id: skins

    property string activeSkin: ""     // "" is the built-in palette
    property var skinListModel: []     // [{ id, name, author, version, description, dir, style }]
    property bool busy: false          // an install or remove is running

    readonly property var active: skinListModel.find(s => s.id === activeSkin) || null
    readonly property var style: active ? active.style : null

    signal finished(string action, string skinId, bool ok, string message)

    readonly property string installer: decodeURIComponent(Qt.resolvedUrl("../../tools/skin_installer.sh").toString().replace(/^file:\/\//, ""))

    function quote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
    function run(args) { return "sh " + [installer].concat(args).map(quote).join(" ") }

    // command -> { action, id } for the install / remove runs in flight
    property var jobs: ({})
    function start(action, id, args) {
        var command = run(args)
        if (action !== "list") { busy = true; jobs[command] = { action: action, id: id } }
        if (runner.connectedSources.indexOf(command) < 0) runner.connectSource(command)
    }
    function refresh() { start("list", "", ["list"]) }
    function install(url, id, sha256) { start("install", id, ["install", url, id].concat(sha256 ? [sha256] : [])) }
    function remove(id) { start("remove", id, ["remove", id]) }

    function installed(id) { return skinListModel.some(s => s.id === id) }
    function installedVersion(id) { var s = skinListModel.find(s => s.id === id); return s ? s.version : "" }
    // Dotted numeric versions: <0, 0 or >0, like a sort comparator.
    function compareVersions(a, b) {
        var x = String(a || "0").split("."), y = String(b || "0").split(".")
        for (var i = 0; i < Math.max(x.length, y.length); i++) {
            var d = (parseInt(x[i]) || 0) - (parseInt(y[i]) || 0)
            if (d !== 0) return d
        }
        return 0
    }

    function parse(stdout) {
        return String(stdout || "").split("\n").map(line => {
            var parts = line.split("\t")
            if (parts.length < 3 || !parts[0]) return null
            try {
                return Skins.entry(parts[0], parts[1], JSON.parse(parts.slice(2).join("\t")))
            } catch (e) {
                return null
            }
        }).filter(s => s)
    }

    property P5Support.DataSource runner: P5Support.DataSource {
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source)
            var job = skins.jobs[source]
            if (!job) {
                skins.skinListModel = skins.parse(data["stdout"])
                return
            }
            delete skins.jobs[source]
            skins.busy = Object.keys(skins.jobs).length > 0
            skins.finished(job.action, job.id, data["exit code"] === 0, String(data["stderr"] || "").trim())
            skins.refresh()
        }
    }

    onActiveSkinChanged: refresh()
    Component.onCompleted: refresh()
}
