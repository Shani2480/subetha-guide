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
    // A skin with light and dark variants follows the mode like the Guide
    // does; the variant in use is laid over its base colours, badge, frame
    // and ground line. One without them keeps its single look (isDark).
    readonly property var variant: skin && skin.variants ? skin.variants[dark ? "dark" : "light"] : null
    readonly property var skinColors: !skin ? ({}) : variant ? Object.assign({}, skin.colors, variant.colors) : skin.colors
    function sc(key, fallback) { return skinColors[key] ? skinColors[key] : fallback }
    // "idle", "stressed" (a critical reading); the owner sets it, BMO's face shows it
    property string mood: "idle"
    property bool live: false           // the Guide is on screen; gates a skin's ambient flicker
    // Two readings for a skin's analog dials, 0..1: the busier of CPU and GPU, and the hotter.
    property real meterA: 0
    property real meterB: 0

    readonly property bool hasLocation: latitude !== 0 || longitude !== 0
    property bool sunUp: true
    readonly property bool dark: skin && !skin.variants && skin.isDark !== null ? skin.isDark
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
    readonly property color badge:  variant && variant.badgeColor ? variant.badgeColor : skin && skin.badgeColor ? skin.badgeColor : dark ? amber : mustard   // DON'T PANIC, critical pulse start
    readonly property color accent: dark ? amber : coral           // commentary
    readonly property color cool:   dark ? cyan : teal             // charging, mains, I/O
    readonly property color alert:  dark || skinned ? red : "#E53935"
    // Fill by how healthy a level is: good, middling, bad
    readonly property color high:   sc("accentGood", dark ? phosphor : teal)
    readonly property color mid:    dark ? amber : mustard
    readonly property color low:    dark ? red : coral

    // ---- skin-only roles; without a skin each is the Guide's own look ----
    readonly property color inkSoft:   sc("textSecondary", tint(0.6))     // subtitles
    readonly property color commentary: sc("commentary", accent)          // the sections' one-line verdicts
    readonly property color cardHover: sc("cardBackgroundHover", bg)       // a frame under the pointer
    readonly property color border:    sc("border", dark ? tint(0.55) : ink)
    // a glow's colour on the terminal is a soft phosphor, not solid ink
    readonly property color shadow:    sc("shadowColor", !skin && dark ? tint(0.4) : ink)

    // ---- geometry: the shape of cards, pills, gauges and buttons ----
    // A skin's `geometry` block (SkinEngine.parseGeometry), else what its
    // older tokens imply (borderRadius, frame.chamfer, gaugeStyle, the shadow
    // offset and blur), else the Guide's own: the 1981 terminal sharp with
    // corner reticles, segmented gauges and a phosphor glow; the 2005 pages
    // rounded with capsule pills and gauges and a flat 2px charcoal shadow.
    // ThemeShapeContainer draws them; the shape names are documented there.
    readonly property var geo: skin ? skin.geometry : ({})
    function gv(key, fallback) { var v = geo[key]; return v === null || v === undefined || v === "" ? fallback : v }
    readonly property real legacyChamfer: frame && frame.chamfer ? frame.chamfer : 0
    readonly property real legacyRadius: skin && skin.borderRadius !== null ? skin.borderRadius : -1
    readonly property string cardShape: gv("cardShape", legacyChamfer > 0 ? "chamfer"
                                                      : legacyRadius === 0 || (!skin && dark) ? "sharp" : "rounded")
    readonly property string pillShape: gv("pillShape", skin ? (legacyRadius === 0 ? "sharp" : "rounded") : dark ? "sharp" : "stadium")
    readonly property string gaugeShape: gv("gaugeShape", !skin ? (dark ? "segmented" : "stadium")
                                                        : ({ blocks: "segmented", slot: "flat", tube: "stadium" })[skin.gaugeStyle])
    readonly property real cornerRadius: gv("cornerRadius", legacyRadius >= 0 ? legacyRadius : 12)
    readonly property real pillCornerRadius: gv("pillRadius", Math.min(12, cornerRadius))
    readonly property real chamferCut: gv("chamferCut", legacyChamfer || 12)
    readonly property real pillChamferCut: gv("pillChamferCut", Math.min(6, chamferCut))
    readonly property real stadiumMax: 24       // a tall stadium card is a well-rounded box, not a lozenge
    readonly property string borderStyle: gv("borderStyle", "solid")
    readonly property real borderWidth: gv("borderWidth", skin && skin.borderWidth !== null ? skin.borderWidth : 2)
    // L corner marks on the outer cards; "tech-brackets" borders put them on pills too
    readonly property bool cornerBrackets: gv("hasCornerBrackets", skin ? !!(frame && frame.brackets) : true)
    readonly property color bracketColor: frame && frame.brackets ? frame.brackets : !skin ? (dark ? amber : ink) : border
    readonly property bool legacyShadow: !!skin && (skin.shadowOffset[0] || skin.shadowOffset[1]) && shadow.a > 0
    readonly property string shadowType: geo.hasDropShadow === false ? "none"
        : gv("shadowType", !skin ? (dark ? "glow" : "flat-2d")
                         : legacyShadow ? (skin.shadowBlur > 0 ? "soft" : "flat-2d") : "none")
    readonly property real shadowX: shadowType === "glow" || shadowType === "none" ? 0
        : (geo.shadowOffset || [])[0] ?? (skin && skin.shadowOffset[0] !== null ? skin.shadowOffset[0] : 2)
    readonly property real shadowY: shadowType === "glow" || shadowType === "none" ? 0
        : (geo.shadowOffset || [])[1] ?? (skin && skin.shadowOffset[1] !== null ? skin.shadowOffset[1] : 2)
    // px; an older skin's blur was a 0..1 fraction of 24px
    readonly property real shadowBlur: gv("shadowBlur", skin && skin.shadowBlur !== null ? skin.shadowBlur * 24 : shadowType === "glow" ? 6 : 0)

    // A ThemeShapeContainer's shape, radius and cut by role: "card" (outer
    // frames), "pill" (pills, buttons and badges) or "gauge" (a continuous
    // gauge's track and fill; a segmented one draws square blocks).
    function shapeOf(role) { return role === "pill" ? pillShape : role === "gauge" ? ({ segmented: "sharp", flat: "sharp" })[gaugeShape] || gaugeShape : cardShape }
    function radiusOf(role) { return role === "pill" ? pillCornerRadius : role === "gauge" ? 2 : cornerRadius }
    function chamferOf(role) { return role === "card" ? chamferCut : pillChamferCut }
    readonly property real chamfer:    cardShape === "chamfer" ? chamferCut : 0      // a frame's 45° cut corners
    // Gauges and graphs: transparent means "as the Guide colours it".
    readonly property color gaugeTrack: sc("gaugeTrack", "transparent")
    readonly property color gaugeUsage: sc("gaugeFillUsage", "transparent")
    readonly property color gaugeTemp:  sc("gaugeFillTemp", "transparent")
    readonly property color gaugeEdge:  sc("gaugeFillEdge", border)
    readonly property real gaugeEdgeWidth: skin && skin.gaugeEdgeWidth !== null ? skin.gaugeEdgeWidth : 1.5
    readonly property bool gaugeSlot:   gaugeShape !== "segmented"               // one continuous bar, not blocks
    readonly property bool gaugeTube:   gaugeShape === "stadium" && !!skin && skin.gaugeStyle === "tube"   // ...as a glass tube
    readonly property real gaugeBlockRadius: pillShape === "sharp" || pillShape === "chamfer" ? 0 : 2        // a segmented gauge's blocks
    readonly property real tempPulseC:  skin && skin.tempPulseC !== null ? skin.tempPulseC : 0   // 0: pulse only when critical
    readonly property color sparkline:  sc("sparkline", "transparent")
    readonly property color sparklineFill: sc("sparklineFill", "transparent")
    readonly property bool sparklineStepped: !!skin && skin.sparklineStyle === "stepped"
    readonly property real sparklineWidth: skin && skin.sparklineWidth !== null ? skin.sparklineWidth : 2
    // a red band over the top of the graph, and/or the trace turning red, past a load fraction
    readonly property color sparklineDanger: sc("sparklineDanger", "transparent")
    readonly property real sparklineDangerAbove: skin && skin.sparklineDangerAbove !== null ? skin.sparklineDangerAbove : 0.85
    readonly property color sparklineHot: sc("sparklineHot", "transparent")
    readonly property real sparklineHotAbove: skin && skin.sparklineHotAbove !== null ? skin.sparklineHotAbove : 0.75
    readonly property color netDown:    sc("netDown", cool)
    readonly property color netUp:      sc("netUp", dark ? amber : coral)
    readonly property string badgeText: skin ? skin.badgeText : ""
    readonly property color badgeInk:   variant && variant.badgeTextColor ? variant.badgeTextColor
                                      : skin && skin.badgeTextColor ? skin.badgeTextColor : dark ? badge : ink
    readonly property var quips: skin ? skin.quips : ({})
    readonly property var frame: !skin || !skin.frame ? null      // { style: "handheld", dpad, buttons, vents }
                               : !variant ? skin.frame
                               : Object.assign({}, skin.frame, variant.frame,
                                               skin.frame.button && variant.frame.buttonColor
                                               ? { button: { text: skin.frame.button.text, color: variant.frame.buttonColor } } : {})
    readonly property var faces: skin ? skin.faces : ({})          // { idle, happy, stressed }: image URLs
    readonly property var roamers: skin ? skin.roamers : []        // see weather/SpriteRoamers.qml
    readonly property var ground: !skin || !skin.ground ? null      // the roamers' ground line
                                : variant ? Object.assign({}, skin.ground, variant.ground) : skin.ground
    // A skin's clock lines ({ nominal, stress }) and the storm's falling hazards (image URLs).
    readonly property var clockQuips: skin ? skin.clockQuips : ({})
    readonly property var hazards: skin ? skin.hazards : []
    // Text a skin renames: rx, tx, lan, wan, lanTag, wanTag ("" keeps the Guide's).
    readonly property var labels: skin ? skin.labels : ({})
    readonly property bool chevrons: !!skin && skin.netGlyph === "chevron"

    readonly property string mono: "monospace"
    readonly property string sans: skin && skin.font ? skin.font : dark ? "monospace" : Qt.application.font.family
    // Corner radii as a plain Rectangle can take them (a stadium is as round as
    // stadiumMax, which a short Rectangle clamps to a capsule), shared 1:1 by
    // every widget so cards placed side by side line up; 4px margins.
    readonly property real outerRadius: cardShape === "rounded" ? cornerRadius : cardShape === "stadium" ? stadiumMax : 0
    readonly property real pillRadius: pillShape === "rounded" ? pillCornerRadius : pillShape === "stadium" ? stadiumMax : 0
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
    // a hard offset copy, no blur: 2px 2px charcoal on the light pages
    readonly property bool flatShadow: shadowType === "flat-2d" && (shadowX !== 0 || shadowY !== 0)
    readonly property bool scanlines: dark && !minimal
    readonly property real scanlineOpacity: frame && frame.scanlines !== null && frame.scanlines !== undefined ? frame.scanlines : 0.15
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
