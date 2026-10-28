import QtQuick
import QtCore
import Qt.labs.folderlistmodel
import org.kde.plasma.plasma5support as P5Support

// The theme the Sub-Etha apps share with the Sub-Etha System Monitor, in
// ${XDG_CONFIG_HOME:-~/.config}/subetha/theme_state.json:
//   { "activeThemeId": "h2g2" | <skin id>, "variant": "dark" | "light" | "auto",
//     "syncThemeAcrossApps": true }
// "h2g2" is the Guide's own palette (activeSkin ""); "auto" leaves each app
// to resolve day and night its own way (here, Solar Auto).
//
// The owner binds `skin` and `mode` to the widget's activeSkin and
// themeMode: a change to either is written to the file, and a change in the
// file arrives as received(). The file is read first; until then nothing is
// written, so the shared choice wins over this widget's at start-up. Both
// apps replace the file by rename, which the folder model's watcher sees
// within milliseconds, so nothing polls. With syncThemeAcrossApps off the
// widget neither writes the theme nor follows it.
QtObject {
    id: sync

    property string skin: ""
    property string mode: "auto"
    signal received(string skin, string mode)

    property bool enabled: true          // syncThemeAcrossApps, as last read
    property bool ready: false           // the file has been read once
    property var last: null              // { activeThemeId, variant } as last read or written

    readonly property string dir: decodeURIComponent(StandardPaths.writableLocation(StandardPaths.GenericConfigLocation)
                                                     .toString().replace(/^file:\/\//, "")) + "/subetha"
    readonly property string path: dir + "/theme_state.json"
    readonly property var variants: ["dark", "light", "auto"]

    function themeId(skin) { return skin || "h2g2" }
    function skinOf(id) { return id === "h2g2" ? "" : id }
    function quote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    function read() {
        var command = "mkdir -p " + quote(dir) + " && cat " + quote(path) + " 2>/dev/null; true"
        if (runner.connectedSources.indexOf(command) < 0) runner.connectSource(command)
    }
    function apply(stdout) {
        var state = null
        try { state = JSON.parse(stdout) } catch (e) {}
        var first = !ready
        ready = true
        if (!state || typeof state !== "object" || typeof state.activeThemeId !== "string"
                || !/^[a-z0-9._-]{1,64}$/.test(state.activeThemeId)) {
            push()                       // missing or broken: this widget's theme starts it
            return
        }
        enabled = state.syncThemeAcrossApps !== false
        var variant = variants.indexOf(state.variant) >= 0 ? state.variant : mode
        last = { activeThemeId: state.activeThemeId, variant: variant }
        if (enabled && (skinOf(state.activeThemeId) !== skin || variant !== mode))
            received(skinOf(state.activeThemeId), variant)
    }
    function push() {
        if (!ready || !enabled) return
        var state = { activeThemeId: themeId(skin), variant: variants.indexOf(mode) >= 0 ? mode : "auto" }
        if (last && last.activeThemeId === state.activeThemeId && last.variant === state.variant) return
        last = state
        var json = JSON.stringify({ activeThemeId: state.activeThemeId, variant: state.variant, syncThemeAcrossApps: true }, null, 2)
        var tmp = dir + "/.theme_state.json.guide"
        var command = "mkdir -p " + quote(dir) + " && printf '%s\\n' " + quote(json) + " > " + quote(tmp)
                    + " && mv -f " + quote(tmp) + " " + quote(path)
        if (writer.connectedSources.indexOf(command) < 0) writer.connectSource(command)
    }
    onSkinChanged: Qt.callLater(push)
    onModeChanged: Qt.callLater(push)

    property P5Support.DataSource runner: P5Support.DataSource {
        engine: "executable"
        onNewData: (source, data) => { disconnectSource(source); sync.apply(String(data["stdout"] || "")) }
    }
    property P5Support.DataSource writer: P5Support.DataSource {
        engine: "executable"
        onNewData: source => disconnectSource(source)
    }

    // A write, ours or the monitor's, lands as a rename into the folder: the
    // file's row appears or its modification time changes.
    property FolderListModel folder: FolderListModel {
        folder: sync.ready ? "file://" + encodeURI(sync.dir) : ""
        nameFilters: ["theme_state.json"]
        showDirs: false
        showDotAndDotDot: false
    }
    property Instantiator watch: Instantiator {
        model: sync.folder
        delegate: QtObject {
            required property var fileModified
            onFileModifiedChanged: debounce.restart()
        }
    }
    property Timer debounce: Timer { interval: 15; onTriggered: sync.read() }

    Component.onCompleted: read()
}
