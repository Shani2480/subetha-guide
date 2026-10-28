import QtQuick
import "solar.js" as Solar

// The suite's shared design tokens: the 2005 film's cream Encyclopedia pages
// (light) and the 1981 BBC Sub-Etha terminal (dark), plus the "auto" switch
// between them at local sunrise and sunset.
//
// Synced into every widget at contents/ui/common/ by install.sh; edit the copy
// in the suite's common/ folder, not the synced one.
QtObject {
    id: theme

    property string mode: "auto"        // auto | light | dark
    property real latitude: 0           // 0, 0: no location, auto follows systemDark
    property real longitude: 0
    property bool systemDark: false     // the owner passes Kirigami.Theme's verdict
    property bool minimal: false        // displayMode "minimal": no raster, grid, reticles or commentary

    readonly property bool hasLocation: latitude !== 0 || longitude !== 0
    property bool sunUp: true
    readonly property bool dark: mode === "dark" || (mode === "auto" && (hasLocation ? !sunUp : systemDark))

    // ---- raw palette ----
    readonly property color cream:    "#F5F2EB"
    readonly property color paper:    "#EDE8DC"
    readonly property color charcoal: "#1B2028"
    readonly property color coral:    "#FF6B4A"
    readonly property color mustard:  "#FFBE1A"
    readonly property color teal:     "#26A69A"
    readonly property color crtBlack: "#040806"
    readonly property color crtCard:  "#07110C"
    readonly property color phosphor: "#00FF66"
    readonly property color amber:    "#FFB000"
    readonly property color cyan:     "#00E5FF"
    readonly property color red:      "#FF3333"

    // ---- roles ----
    readonly property color bg:     dark ? crtBlack : cream
    readonly property color card:   dark ? crtCard : paper
    readonly property color ink:    dark ? phosphor : charcoal     // text and outlines
    readonly property color badge:  dark ? amber : mustard         // DON'T PANIC, critical pulse start
    readonly property color accent: dark ? amber : coral           // commentary
    readonly property color cool:   dark ? cyan : teal             // charging, mains, I/O
    readonly property color alert:  dark ? red : "#E53935"
    // Fill by how healthy a level is: good, middling, bad
    readonly property color high:   dark ? phosphor : teal
    readonly property color mid:    dark ? amber : mustard
    readonly property color low:    dark ? red : coral

    readonly property string mono: "monospace"
    readonly property string sans: dark ? "monospace" : Qt.application.font.family
    // Shape and layout tokens, shared 1:1 by every widget so cards placed side
    // by side line up: radius 16 outer frames, 12 inner pills, 4px margins.
    readonly property real outerRadius: 16
    readonly property real pillRadius: 12
    readonly property real margin: 4

    // Stepped resizing: a desktop card snaps to one of three column widths and
    // three row heights (see SnapFrame.qml).
    readonly property real colWidthCompact: 260
    readonly property real colWidthStandard: 360
    readonly property real colWidthWide: 740
    readonly property real rowHeightPill: 110
    readonly property real rowHeightMedium: 240
    readonly property real rowHeightFull: 380
    function snapWidth(w) { return w < 310 ? colWidthCompact : w < 550 ? colWidthStandard : colWidthWide }
    // The smallest row step that holds `h`.
    function fitHeight(h) {
        return h <= rowHeightPill ? rowHeightPill : h <= rowHeightMedium ? rowHeightMedium
             : rowHeightFull + Math.max(0, Math.ceil((h - rowHeightFull) / rowHeightPill)) * rowHeightPill
    }
    // Past the full row, a taller box adds whole pill rows.
    function snapHeight(h) {
        return h < 175 ? rowHeightPill : h < 310 ? rowHeightMedium
             : rowHeightFull + Math.max(0, Math.floor((h - rowHeightFull) / rowHeightPill)) * rowHeightPill
    }
    readonly property bool flatShadow: !dark                   // 2px 2px solid charcoal, no blur
    readonly property bool scanlines: dark && !minimal
    readonly property bool grid: !minimal
    readonly property bool reticles: !minimal

    function tint(a) { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    // Battery-style level: higher is better.
    function level(p) { return p >= 50 ? high : p >= 20 ? mid : low }
    function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1) }

    // One single-shot timer aimed at the next sunrise or sunset, rather than a
    // clock polling all day. Owners also call refresh() when their view opens,
    // since a timer can sleep through a suspend.
    function refresh() {
        if (mode !== "auto" || !hasLocation) { sunTimer.stop(); return }
        var now = new Date()
        var sun = Solar.daylight(now, latitude, longitude)
        sunUp = sun.day
        sunTimer.interval = Math.max(60000, sun.next.getTime() - now.getTime() + 5000)
        sunTimer.restart()
    }
    property Timer sunTimer: Timer { repeat: false; onTriggered: theme.refresh() }
    onModeChanged: Qt.callLater(refresh)
    onLatitudeChanged: Qt.callLater(refresh)
    onLongitudeChanged: Qt.callLater(refresh)
    Component.onCompleted: refresh()
}
