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
    // The active community skin's look, as SkinEngine.style parses it, or null
    // for the Guide's own. Its colours replace the raw palette below (so every
    // role and every direct use follows), and it brings tokens of its own: the
    // frame's border and shadow, gauge and graph colours, badge, commentary,
    // and the chassis and roamers it asks the built-in pieces to draw.
    property var skin: null
    readonly property bool skinned: !!skin
    function sc(key, fallback) { return skin && skin.colors[key] ? skin.colors[key] : fallback }
    // "idle", "stressed" (a critical reading); the owner sets it, BMO's face shows it
    property string mood: "idle"

    readonly property bool hasLocation: latitude !== 0 || longitude !== 0
    property bool sunUp: true
    readonly property bool dark: skin && skin.isDark !== null ? skin.isDark
                               : mode === "dark" || (mode === "auto" && (hasLocation ? !sunUp : systemDark))

    // ---- raw palette (a skin replaces all of it) ----
    readonly property color cream:    sc("background", "#F5F2EB")
    readonly property color paper:    sc("cardBackground", "#EDE8DC")
    readonly property color charcoal: sc("textPrimary", "#1B2028")
    readonly property color coral:    sc("accentSecondary", "#FF6B4A")
    readonly property color mustard:  sc("accent", "#FFBE1A")
    readonly property color teal:     sc("accentTertiary", "#26A69A")
    readonly property color crtBlack: sc("background", "#040806")
    readonly property color crtCard:  sc("cardBackground", "#07110C")
    readonly property color phosphor: sc("textPrimary", "#00FF66")
    readonly property color amber:    sc("accent", "#FFB000")
    readonly property color cyan:     sc("accentTertiary", "#00E5FF")
    readonly property color red:      sc("accentSecondary", "#FF3333")

    // ---- roles ----
    readonly property color bg:     dark ? crtBlack : cream
    readonly property color card:   dark ? crtCard : paper
    readonly property color ink:    dark ? phosphor : charcoal     // text and outlines
    readonly property color badge:  skin && skin.badgeColor ? skin.badgeColor : dark ? amber : mustard   // DON'T PANIC, critical pulse start
    readonly property color accent: dark ? amber : coral           // commentary
    readonly property color cool:   dark ? cyan : teal             // charging, mains, I/O
    readonly property color alert:  dark || skinned ? red : "#E53935"
    // Fill by how healthy a level is: good, middling, bad
    readonly property color high:   sc("accentGood", dark ? phosphor : teal)
    readonly property color mid:    dark ? amber : mustard
    readonly property color low:    dark ? red : coral

    // ---- skin-only roles; without a skin each is the Guide's own look ----
    readonly property color inkSoft:   sc("textSecondary", tint(0.6))     // subtitles
    readonly property color cardHover: sc("cardBackgroundHover", bg)       // a frame under the pointer
    readonly property color border:    sc("border", dark ? tint(0.55) : ink)
    readonly property real borderWidth: skin && skin.borderWidth !== null ? skin.borderWidth : 2
    readonly property color shadow:    sc("shadowColor", ink)
    readonly property real shadowX:    skin && skin.shadowOffset[0] !== null ? skin.shadowOffset[0] : 2
    readonly property real shadowY:    skin && skin.shadowOffset[1] !== null ? skin.shadowOffset[1] : 2
    // Gauges and graphs: transparent means "as the Guide colours it".
    readonly property color gaugeTrack: sc("gaugeTrack", "transparent")
    readonly property color gaugeUsage: sc("gaugeFillUsage", "transparent")
    readonly property color gaugeTemp:  sc("gaugeFillTemp", "transparent")
    readonly property color sparkline:  sc("sparkline", "transparent")
    readonly property color sparklineFill: sc("sparklineFill", "transparent")
    readonly property color netDown:    sc("netDown", cool)
    readonly property color netUp:      sc("netUp", dark ? amber : coral)
    readonly property string badgeText: skin ? skin.badgeText : ""
    readonly property color badgeInk:   skin && skin.badgeTextColor ? skin.badgeTextColor : dark ? badge : ink
    readonly property var quips: skin ? skin.quips : ({})
    readonly property var frame: skin ? skin.frame : null          // { style: "handheld", dpad, buttons, vents }
    readonly property var faces: skin ? skin.faces : ({})          // { idle, happy, stressed }: image URLs
    readonly property var roamers: skin ? skin.roamers : []        // see weather/SpriteRoamers.qml

    readonly property string mono: "monospace"
    readonly property string sans: skin && skin.font ? skin.font : dark ? "monospace" : Qt.application.font.family
    // Shape and layout tokens, shared 1:1 by every widget so cards placed side
    // by side line up: radius 16 outer frames, 12 inner pills, 4px margins.
    readonly property real outerRadius: skin && skin.borderRadius !== null ? skin.borderRadius : 16
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
    // A skin's chassis is its own ornament: no coordinate grid or reticles on it.
    readonly property bool grid: !minimal && !frame
    readonly property bool reticles: !minimal && !frame

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
