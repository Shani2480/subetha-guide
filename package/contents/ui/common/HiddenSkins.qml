import QtQuick
import QtCore
import Qt.labs.folderlistmodel
import org.kde.plasma.plasma5support as P5Support

// The skins kept out of the menus, shared with the Sub-Etha System Monitor in
// ${XDG_CONFIG_HOME:-~/.config}/subetha/hidden_themes.json:
//   { "hidden": [<skin id>, …] }
// A hidden skin stays installed, and in use if it is; the Theme Store's grid
// and the monitor's skin pickers leave it out, and the Theme Store's manager
// lists it to show again. Both apps replace the file by rename and follow it
// through a folder watcher, as ThemeSync does for theme_state.json.
QtObject {
    id: hidden

    property var ids: []                 // as last read or written

    readonly property string dir: decodeURIComponent(StandardPaths.writableLocation(StandardPaths.GenericConfigLocation)
                                                     .toString().replace(/^file:\/\//, "")) + "/subetha"
    readonly property string path: dir + "/hidden_themes.json"

    function has(id) { return ids.indexOf(id) >= 0 }
    function setHidden(id, on) {
        if (!/^[a-z0-9._-]{1,64}$/.test(id) || has(id) === on) return
        ids = on ? ids.concat([id]) : ids.filter(i => i !== id)
        write()
    }
    function quote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    function read() {
        var command = "cat " + quote(path) + " 2>/dev/null; true"
        if (runner.connectedSources.indexOf(command) < 0) runner.connectSource(command)
    }
    function apply(stdout) {
        var state = null
        try { state = JSON.parse(stdout) } catch (e) {}
        var list = state && Array.isArray(state.hidden) ? state.hidden : []
        list = list.filter(i => typeof i === "string" && /^[a-z0-9._-]{1,64}$/.test(i))
        if (JSON.stringify(list) !== JSON.stringify(ids)) ids = list
    }
    function write() {
        var json = JSON.stringify({ hidden: ids }, null, 2)
        var tmp = dir + "/.hidden_themes.json.guide"
        var command = "mkdir -p " + quote(dir) + " && printf '%s\\n' " + quote(json) + " > " + quote(tmp)
                    + " && mv -f " + quote(tmp) + " " + quote(path)
        if (writer.connectedSources.indexOf(command) < 0) writer.connectSource(command)
    }

    property P5Support.DataSource runner: P5Support.DataSource {
        engine: "executable"
        onNewData: (source, data) => { disconnectSource(source); hidden.apply(String(data["stdout"] || "")) }
    }
    property P5Support.DataSource writer: P5Support.DataSource {
        engine: "executable"
        onNewData: source => disconnectSource(source)
    }

    property FolderListModel folder: FolderListModel {
        folder: "file://" + encodeURI(hidden.dir)
        nameFilters: ["hidden_themes.json"]
        showDirs: false
        showDotAndDotDot: false
    }
    property Instantiator watch: Instantiator {
        model: hidden.folder
        delegate: QtObject {
            required property var fileModified
            onFileModifiedChanged: debounce.restart()
        }
    }
    property Timer debounce: Timer { interval: 15; onTriggered: hidden.read() }

    Component.onCompleted: read()
}
