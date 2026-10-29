import QtQuick
import "solar.js" as Solar
import "skins.js" as Skins

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
    // The active community skin's look, as skins.js parses it, or null
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
    property bool alertMotion: true     // enablePulsingAnimations: alerts breathe, blink and strobe
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
    // alert levels (AlertManager): fixed, so a skin's palette never hides a warning
    readonly property color warnColor: dark ? "#FFB000" : "#E8890C"     // warning: amber
    readonly property color critColor: dark ? "#FF2A4B" : "#D91B33"     // critical: crimson
    // the CRT terminal and glitch skins jitter a critical figure by a pixel
    readonly property bool alertJitter: (dark && !skinned) || (!!frame && frame.glitch === true)
    // Fill by how healthy a level is: good, middling, bad
    readonly property color high:   sc("accentGood", dark ? phosphor : teal)
    readonly property color mid:    dark ? amber : mustard
    readonly property color low:    dark ? red : coral

    // ---- skin-only roles; without a skin each is the Guide's own look ----
    readonly property color inkSoft:   sc("textSecondary", tint(0.6))     // subtitles
    // Text drawn straight on `bg`: the skin's textOnBackground, else ink or
    // inkSoft while they read against it (WCAG contrast >= 4.5), else white or
    // black, whichever reads better. Unskinned these are ink and inkSoft.
    function luminance(c) {
        var f = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b)
    }
    function contrast(a, b) {
        var x = luminance(a), y = luminance(b)
        return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05)
    }
    function readableOn(ground, wanted) {
        if (contrast(wanted, ground) >= 4.5) return wanted
        var white = Qt.color("#FFFFFF"), black = Qt.color("#000000")
        return contrast(white, ground) >= contrast(black, ground) ? white : black
    }
    readonly property color onBackground: !skinned ? ink : skinColors.textOnBackground || readableOn(bg, ink)
    readonly property color onBackgroundDim: !skinned ? inkSoft
                                           : skinColors.textOnBackground ? Qt.rgba(onBackground.r, onBackground.g, onBackground.b, 0.75)
                                           : contrast(inkSoft, bg) >= 4.5 ? inkSoft : Qt.rgba(onBackground.r, onBackground.g, onBackground.b, 0.75)
    readonly property color commentary: sc("commentary", accent)          // the sections' one-line verdicts
    readonly property color cardHover: sc("cardBackgroundHover", bg)       // a frame under the pointer
    readonly property color border:    sc("border", dark ? tint(0.55) : ink)
    readonly property color borderActive: sc("borderActive", border)       // the hovered card, the open section
    // a glow's colour on the terminal is a soft phosphor, not solid ink
    readonly property color shadow:    sc("shadowColor", !skin && dark ? tint(0.4) : ink)

    // ---- geometry: the shape of cards, pills, gauges and buttons ----
    // A skin's `geometry` block (skins.js parseGeometry), else what its
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
    // features.cartoonOutlines: thick ink outlines and flat offset shadows on everything
    readonly property bool cartoon: !!skin && skin.features.cartoonOutlines === true
    readonly property real borderWidth: Math.max(cartoon ? 3 : 0, gv("borderWidth", skin && skin.borderWidth !== null ? skin.borderWidth : 2))
    // L corner marks on the outer cards; "tech-brackets" borders put them on pills too
    readonly property bool cornerBrackets: skin ? feature("cornerBrackets", gv("hasCornerBrackets", !!(frame && frame.brackets))) : true
    readonly property color bracketColor: frame && frame.brackets ? frame.brackets : !skin ? (dark ? amber : ink) : border
    readonly property bool legacyShadow: !!skin && (skin.shadowOffset[0] || skin.shadowOffset[1]) && shadow.a > 0
    readonly property string shadowType: cartoon ? "flat-2d" : geo.hasDropShadow === false ? "none"
        : gv("shadowType", !skin ? (dark ? "glow" : "flat-2d")
                         : legacyShadow ? (skin.shadowBlur > 0 ? "soft" : "flat-2d") : "none")
    readonly property real shadowX: shadowType === "glow" || shadowType === "none" ? 0
        : (geo.shadowOffset || [])[0] ?? (skin && skin.shadowOffset[0] !== null ? skin.shadowOffset[0] : cartoon ? 3 : 2)
    readonly property real shadowY: shadowType === "glow" || shadowType === "none" ? 0
        : (geo.shadowOffset || [])[1] ?? (skin && skin.shadowOffset[1] !== null ? skin.shadowOffset[1] : cartoon ? 3 : 2)
    // px; an older skin's blur was a 0..1 fraction of 24px
    readonly property real shadowBlur: gv("shadowBlur", skin && skin.shadowBlur !== null ? skin.shadowBlur * 24 : shadowType === "glow" ? 6 : 0)

    // A ThemeShapeContainer's shape, radius and cut by role: "card" (outer
    // frames), "pill" (pills, buttons and badges) or "gauge" (a continuous
    // gauge's track and fill; a segmented one draws square blocks).
    function shapeOf(role) { return role === "pill" ? pillShape : role === "gauge" ? ({ segmented: "sharp", flat: "sharp" })[gaugeShape] || gaugeShape : cardShape }
    function radiusOf(role) { return role === "pill" ? pillCornerRadius : role === "gauge" ? 2 : cornerRadius }
    function chamferOf(role) { return role === "card" ? chamferCut : pillChamferCut }
    readonly property real chamfer:    cardShape === "chamfer" ? chamferCut : 0      // a frame's 45° cut corners
    // which corners a chamfer cuts (geometry.chamferCorners): top-right and bottom-left unless the skin says
    readonly property var chamferCorners: geo.chamferCorners && geo.chamferCorners.length ? geo.chamferCorners : ["tr", "bl"]
    // blocks in a segmented bar (geometry.segments); 0: the bar decides
    readonly property int gaugeSegments: geo.segments ? geo.segments : 0
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
    readonly property string aiQuip: skin ? skin.aiQuip : ""     // the AI section's line, "" for the Guide's own
    readonly property var hazards: skin ? skin.hazards : []
    // Text a skin renames: rx, tx, lan, wan, lanTag, wanTag ("" keeps the Guide's).
    readonly property var labels: skin ? skin.labels : ({})
    readonly property bool chevrons: !!skin && skin.netGlyph === "chevron"

    // A skin's font list (skins.js fontList), resolved against what is
    // installed plus the font files the skin ships; `mono` (tables and
    // figures) is the skin's monoFontFamily, else the same list.
    property int fontsLoaded: 0           // bumps as the skin's font files load, to re-resolve
    readonly property string mono: !skin ? "monospace"
        : (fontsLoaded, Skins.resolveFont(skin.monoFonts.length ? skin.monoFonts : skin.fonts, Qt.fontFamilies(), "monospace"))
    readonly property string sans: !skin ? (dark ? "monospace" : Qt.application.font.family)
        : (fontsLoaded, Skins.resolveFont(skin.fonts, Qt.fontFamilies(), "sans-serif"))
    property Instantiator fontFiles: Instantiator {
        model: theme.skin ? theme.skin.fontFiles : []
        delegate: FontLoader {
            required property string modelData
            source: modelData
            onStatusChanged: if (status === FontLoader.Ready) theme.fontsLoaded++
        }
    }

    // ---- effects (ThemeEffectsLayer.qml) ----
    // A skin turns each on in its `features` block and gets none it leaves
    // out (an older skin's frame.scanlines / frame.brackets still count);
    // the Guide's terminal has them all, its film pages none.
    function feature(key, legacy) { var v = skin.features[key]; return v === null || v === undefined ? legacy : v }
    readonly property var fx: !skin ? {
        crtScanlines: dark && !minimal, phosphorDecay: dark && !minimal, cornerBrackets: dark && !minimal,
        glassBlur: false, grid: !minimal, barrel: false, texture: ""
    } : {
        crtScanlines: !minimal && feature("crtScanlines", !!frame && frame.scanlines > 0),
        phosphorDecay: !minimal && feature("phosphorDecay", false),
        cornerBrackets: !minimal && cornerBrackets,
        glassBlur: feature("glassBlur", false),
        grid: !minimal && feature("grid", false),
        barrel: !minimal && feature("barrel", false),
        texture: skin.features.texture || ""
    }
    // ---- the operating system a skin imitates (skins.js 2.1.0) ----
    // chrome: the window's title bar and frame (GuideWindow, WindowChrome);
    // sections: card panels or Win32 group bands (GroupBand); controls: the
    // meter and graph idioms (DynamicMetricGauge, TaskGrid); icons: the
    // skin's own SVG per metric. A variant's colours lie over the skin's.
    // Unskinned, or for a skin that names none, each is the Guide's own.
    function osColor(part, key, fallback) {
        var v = variant && variant[part] ? variant[part][key] : undefined
        var s = skin && skin[part] ? skin[part].colors[key] : undefined
        return v || s || fallback
    }
    readonly property var chromeSpec: skin && skin.chrome && skin.chrome.style && skin.chrome.style !== "plain" ? skin.chrome : null
    readonly property string chromeStyle: chromeSpec ? chromeSpec.style : ""
    // the widget dressed as one window of that OS (never in the minimal display mode)
    // a cartoon lab mainframe around the whole widget (frame.style "console", ConsoleFrame)
    readonly property bool consoleFrame: !!frame && frame.style === "console"
    // ...or cobbled garage plating (frame.style "scrap", ScrapFrame)
    readonly property bool scrapFrame: !!frame && frame.style === "scrap"
    // ...or a pastel candy box (frame.style "candy", CandyFrame)
    readonly property bool candyFrame: !!frame && frame.style === "candy"
    readonly property bool windowed: (chromeStyle !== "" || consoleFrame || scrapFrame || candyFrame) && !minimal
    readonly property string sectionStyle: skin && skin.sections ? skin.sections.style : "card"
    readonly property bool groupBands: sectionStyle === "groupband" && !minimal
    readonly property bool gadgets: sectionStyle === "gadget" && !minimal
    readonly property bool screws: !!skin && !!skin.sections && skin.sections.screws === true && !minimal
    // sections.style "flagtab": an accent flag with a 45° edge per section header (FlagTab)
    readonly property bool flagTabs: sectionStyle === "flagtab" && !minimal
    readonly property string flagMark: flagTabs && skin.sections.flagMark || ""
    readonly property color flagFill: osColor("sections", "bandColor", accent)
    readonly property color flagInk: osColor("sections", "bandText", "#FFFFFF")
    // sections.numbered: "1 — WEATHER", the section's place before its title, in any section style;
    // sections.uppercase false keeps the title's own case
    readonly property bool sectionsNumbered: !!skin && !!skin.sections && skin.sections.numbered === true && !minimal
    readonly property bool sectionsUppercase: !skin || !skin.sections || skin.sections.uppercase !== false
    function sectionLabel(title, number) {
        var t = sectionsUppercase ? title.toUpperCase() : title
        return sectionsNumbered && number > 0 ? number + " \u2014 " + t : t
    }
    // sections.lights "traffic": red, amber and green dots before a section's title
    readonly property bool trafficLights: !!skin && !!skin.sections && skin.sections.lights === "traffic" && !minimal
    // sections.toggle: the fold [ + ] / [ - ] as an angled pill, a glass button or an inked box
    readonly property string toggleStyle: skin && skin.sections && skin.sections.toggle ? skin.sections.toggle
                                        : flagTabs ? "angled" : ""
    // style.footer: a mark, a label and a tracked motto along the widget's foot
    readonly property var footer: skin && skin.footer && !minimal ? skin.footer : null
    readonly property real gadgetGloss: skin && skin.sections && skin.sections.gloss !== null && skin.sections.gloss !== undefined
                                        ? skin.sections.gloss : 0.45
    // sections.gloss on a card style: the gadget's curved sheen over that much of each card's top
    readonly property real cardGloss: !gadgets && !minimal && skin && skin.sections && skin.sections.gloss > 0 ? skin.sections.gloss : 0
    readonly property var controls: skin && skin.controls ? skin.controls : ({ meter: "", meterLabel: false, graph: "line", graphFill: true, cursor: false })
    readonly property string meterStyle: controls.meter || ""
    readonly property string graphStyle: controls.graph || "line"
    readonly property bool taskGraphs: graphStyle === "taskmgr"
    readonly property var icons: Object.assign({}, skin && skin.icons ? skin.icons : {}, variant && variant.icons ? variant.icons : {})   // a variant's over the skin's
    // a meter's own fill by what it measures (cpu, gpu, memory, swap, disk, battery):
    // the variant's controls.meterColors over the skin's; transparent for none
    function meterColor(key) {
        if (!skin || !key) return "transparent"
        var v = variant && variant.meterColors && variant.meterColors[key] ? variant.meterColors[key]
              : skin.controls && skin.controls.meterColors ? skin.controls.meterColors[key] : ""
        return v ? v : "transparent"
    }
    function icon(key) { return icons[key] || "" }
    // a hero illustration for a card's free corner (cpu, gpu, memory, network, disk, weather)
    readonly property var artwork: skin && skin.art ? skin.art : ({})
    function art(key) { return variant && variant.art && variant.art[key] || artwork[key] || "" }   // a variant's own first
    // a card's own surface (sections.tints: cpu, gpu, memory, network, disk, weather), or transparent
    function sectionTint(key) {
        return variant && variant.tints && variant.tints[key]
            || skin && skin.sections && skin.sections.tints && skin.sections.tints[key] || "transparent"
    }
    // the characters with speech bubbles for a card (narrative.vignettes, at: cpu gpu memory weather footer)
    function vignettesAt(at) { return skin && skin.vignettes ? skin.vignettes.filter(v => v.at === at) : [] }
    readonly property bool slimeDrips: !!skin && skin.features.slimeDrips === true && !minimal
    readonly property color slimeColor: frame && frame.slime ? frame.slime : "#7CFC3A"
    // a terminal's blinking block after the commentary lines
    readonly property bool cursor: !!controls.cursor && !minimal
    property bool cursorOn: true
    property Timer cursorBlink: Timer {
        interval: 530; repeat: true
        running: theme.cursor && theme.live
        onTriggered: theme.cursorOn = !theme.cursorOn
        onRunningChanged: if (!running) theme.cursorOn = true
    }
    function withCursor(s) { return cursor ? s + (cursorOn ? " \u2588" : "  ") : s }

    // Lore: the Guide's own words, else the skin's (narrative.lexicon), else plain ones.
    function lex(key, h2g2, neutral) { return !skin ? h2g2 : skin.lexicon[key] || neutral }
    // A section's one-line verdict under a skin: its quip for the level
    // (nominal, moderate, highLoad, critical, night), else plain words.
    function skinLine(level, neutral) { return skin && skin.quips[level] || neutral }
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
    readonly property bool scanlines: fx.crtScanlines
    readonly property real scanlineOpacity: frame && frame.scanlines !== null && frame.scanlines !== undefined ? frame.scanlines : 0.15
    // A skin's chassis is its own ornament: no coordinate grid or reticles on it.
    readonly property bool grid: fx.grid && !frame
    readonly property bool reticles: !minimal && (skin ? fx.cornerBrackets : !frame)

    function tint(a) { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    // An icon's stroke: the Guide's thin CRT line after dark, its bolder print
    // line by day; a skin's weight follows its border (heavy outlines, bold icons).
    function stroke(darkW, lightW) { return skinned ? (borderWidth >= 1.5 ? lightW : darkW) : dark ? darkW : lightW }
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
