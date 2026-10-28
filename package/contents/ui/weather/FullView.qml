import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "code/weather.js" as Weather
import "../common"

// Expanded view, Sub-Etha edition: a CRT terminal card (phosphor green on
// near-black, monospace, blueprint grid, scanlines, corner reticles) that
// keeps Umbra Weather's layout. In a panel popup it is a content-sized card
// with a 48px header (condition icon, pin, location, actions), a hero card
// and a row of seven daily cards. On the desktop (desktopMode) it fills the applet,
// drops the window controls and resizes fluidly: below 420px wide it shows 4
// days, and the hero gains its solar cards and then its hourly strip only when
// the height can hold them. Every row keeps its minimum height, so the hero
// and the 7-day row are always sequential, never squeezed into each other.
// Shrunk below 340x260 the card switches to the miniature view: the hero alone,
// with the icon, temperature, condition and feels-like scaled to the footprint.
Rectangle {
    id: view

    property var weather: null
    property string errorText: ""
    property int currentFeelsLike: 0        // rounded, in the configured unit (see main.qml)
    property string locationName: ""
    property string iconStyle: "wireframe"
    property string themeStyle: "movieLight"   // movieLight (2005 film Guide) / terminalDark (1981 CRT) / improbability (neon wireframe)
    // The Guide's SubEthaTheme while a community skin is active, else null: its
    // colours, font, radius and line weight then replace the three Guide themes,
    // and its roamers (if any) stand in for Arthur and Marvin.
    property QtObject skin: null
    property bool active: false
    property bool pinned: false
    property bool forecastCollapsed: false
    property bool desktopMode: false
    property bool translucent: true
    property bool ambientAnimations: true   // subtle weather animation behind the hero text
    property bool showCharacter: true       // Arthur and Marvin on the hourly strip (needs ambientAnimations)
    property bool showBadge: true           // the Guide shows one badge in its own header instead
    // false: the owner draws the card behind the view (the Guide's
    // ThemeShapeContainer, in the skin's shape), so the view keeps no fill or
    // border of its own; textureInset then keeps the grid and raster clear of
    // the owner's corners.
    property bool backdrop: true
    property real textureInset: radius * 0.3
    property bool glow: true                // phosphor bloom on labels and the badge (GPU layers; previews can turn it off)
    // The Weather Underground sets come in a black and a white edition: the
    // light theme shows the black one, the dark themes the white one.
    readonly property string cardIconStyle: light
        ? (iconStyle === "white" ? "black" : iconStyle === "solid-white" ? "solid-black" : iconStyle)
        : (iconStyle === "black" ? "white" : iconStyle === "solid-black" ? "solid-white" : iconStyle)

    signal refreshRequested()
    signal closeRequested()
    signal configureRequested()
    signal pinRequested()
    signal minimizeRequested()
    signal locationChosen(string name, real latitude, real longitude)

    // Desktop: clicking the hero flips the card over to a details side.
    property bool flipped: false
    property real flipAngle: flipped ? 180 : 0
    Behavior on flipAngle { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }
    transform: Rotation {
        origin.x: view.width / 2
        origin.y: view.height / 2
        axis { x: 0; y: 1; z: 0 }
        angle: view.flipAngle
    }

    // Detail values for the selected day (today uses the live observation).
    readonly property var cur: weather ? weather.current : null
    function detailValue(key, compact) {
        if (!weather || !sel) return ""
        switch (key) {
        case "feels":    return selToday ? Math.round(cur.feelsLike) + "°" : i18n("%1° / %2°", Math.round(sel.max), Math.round(sel.min))
        case "humidity": return selToday ? Math.round(cur.humidity) + "%" : ""
        case "wind":     return selToday ? Math.round(cur.wind) + " " + weather.windUnit + (compact ? "" : " " + Weather.compass(cur.windDir))
                                         : Math.round(sel.wind) + " " + weather.windUnit
        case "pressure": return selToday ? Math.round(cur.pressure) + " hPa" : ""
        case "uv":       return sel.uv === undefined || sel.uv === null ? "" : Math.round(sel.uv) + ""
        case "rain":     return sel.rain === undefined || sel.rain === null ? "" : Math.round(sel.rain) + "%"
        case "precip":   return sel.precipSum === undefined || sel.precipSum === null ? "" : (Math.round(sel.precipSum * 10) / 10) + " " + weather.precipUnit
        case "cloud":    return selToday ? Math.round(cur.cloudCover) + "%" : ""
        }
        return ""
    }
    readonly property string updatedText: weather ? i18n("Updated %1", Qt.formatTime(weather.fetchedAt, "HH:mm")) : ""
    readonly property var detailKeys: [
        { key: "feels",    label: i18n("Feels like"),  shortLabel: i18n("Feels"), dayLabel: i18n("High / Low"), shortDayLabel: i18n("Hi / Lo"), accent: view.cool },
        { key: "humidity", label: i18n("Humidity"),    accent: view.cyan },
        { key: "wind",     label: i18n("Wind"),        dayLabel: i18n("Wind max"),   accent: view.text },
        { key: "pressure", label: i18n("Pressure"),    accent: view.cyan },
        { key: "uv",       label: i18n("UV index"),    shortLabel: i18n("UV"), accent: view.amber },
        { key: "rain",     label: i18n("Rain chance"), shortLabel: i18n("Rain"), accent: view.cyan },
        { key: "precip",   label: i18n("Precipitation"), accent: view.cyan },
        { key: "cloud",    label: i18n("Cloud cover"), accent: view.text }
    ]

    // Tinted card with a small glyph by the label and a faint large glyph
    // behind the value. Used by the popup strip and the desktop back side.
    component DetailTile: Rectangle {
        id: tile
        property var detail
        property real valueSize: 13
        property real watermark: 0.9      // watermark glyph size, as a fraction of the tile height
        property bool compact: false      // narrow popup tiles: short labels, no label glyph
        function labelText() {
            if (!detail) return ""
            if (!view.selToday && detail.dayLabel) return compact && detail.shortDayLabel ? detail.shortDayLabel : detail.dayLabel
            if (compact && detail.key === "wind" && view.cur) return detail.label + " " + Weather.compass(view.cur.windDir)
            return compact && detail.shortLabel ? detail.shortLabel : detail.label
        }
        readonly property color accent: detail ? detail.accent : "#FFFFFF"
        readonly property string value: detail ? view.detailValue(detail.key, compact) : ""
        visible: value !== ""
        radius: view.skin ? Math.min(14, view.skin.outerRadius) : view.light ? 14 : 0
        color: view.light ? view.surface : Qt.rgba(accent.r, accent.g, accent.b, 0.06)
        border.width: view.thinW
        border.color: view.light ? view.outline : Qt.rgba(accent.r, accent.g, accent.b, 0.45)
        implicitHeight: 46

        FlatShadow {}
        Item {   // clips the watermark, so the shadow outside the tile stays visible
            anchors.fill: parent
            clip: true
            DetailGlyph {   // watermark
                anchors.right: parent.right
                anchors.rightMargin: -tile.height * 0.12
                anchors.verticalCenter: parent.verticalCenter
                width: tile.height * tile.watermark; height: width
                kind: tile.detail ? tile.detail.key : "feels"
                color: tile.accent
                opacity: view.light ? 0.22 : 0.16
            }
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 6
            spacing: 1
            Item { Layout.fillHeight: true }
            RowLayout {
                spacing: 4
                Layout.fillWidth: true
                DetailGlyph {
                    visible: !tile.compact
                    Layout.preferredWidth: 13; Layout.preferredHeight: 13
                    kind: tile.detail ? tile.detail.key : "feels"
                    color: tile.accent
                }
                ShadowLabel {
                    text: tile.labelText()
                    color: view.light ? view.secondary : tile.accent
                    font.pixelSize: 10
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: tile.compact ? 0.2 : 0.4
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
            ShadowLabel {
                text: tile.value
                color: view.primary
                font.pixelSize: tile.valueSize
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Item { Layout.fillHeight: true }
        }
    }

    // inline location search, opened by clicking the location text
    property bool searching: false
    onActiveChanged: if (!active) { searching = false; flipped = false }
    function openSearch() { searching = true; Qt.callLater(function () { locationSearch.begin() }) }

    // selected forecast day (0 = today) drives the hero card
    property int selectedIndex: 0
    property int pendingIndex: 0

    readonly property bool narrow: desktopMode && width < 420
    // Miniature view: a single hero card once the desktop widget is resized to
    // a small footprint. The popup is content-sized and never qualifies.
    readonly property bool isMiniMode: desktopMode && (width < 340 || height < 260)
    // The desktop card has three tiers: miniature (hero only), mid (hero and
    // the weekly row, hourly strip collapsed) and full (everything).
    readonly property bool isMidMode: desktopMode && !isMiniMode && !showTrack
    readonly property bool isFullMode: desktopMode && !isMiniMode && showTrack
    readonly property bool showSolarCards: !isMiniMode && width >= 400
    readonly property int miniMinWidth: 200
    readonly property int miniMinHeight: 130
    onIsMiniModeChanged: {
        if (isMiniMode) { flipped = false; searching = false; selectedIndex = 0; pendingIndex = 0 }
        else entrance++   // replay the pill entrances of the rows that come back
    }

    // Breakpoint transitions. Sections never snap in and out: each one follows
    // a 0..1 progress that drives its layout size and opacity.
    property real miniProgress: isMiniMode ? 1.0 : 0.0          // regular rows -> miniature tile
    Behavior on miniProgress { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    property real hourlyVisibility: showTrack ? 1.0 : 0.0
    Behavior on hourlyVisibility { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    property real weeklyVisibility: isMiniMode ? 0.0 : 1.0
    Behavior on weeklyVisibility { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    property real solarVisibility: showSolar ? 1.0 : 0.0
    Behavior on solarVisibility { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    // Hero height floor, eased between the tiers and the miniature tile but
    // never above what fits beside the (collapsing) 7-day row.
    property real heroMinHeight: isMiniMode ? 56 : Math.ceil(heroNeed)
    Behavior on heroMinHeight { enabled: view.desktopMode; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    readonly property real heroRoom: height - chrome - gridMin * weeklyVisibility
    readonly property real heroFloor: desktopMode ? Math.max(56, Math.min(heroMinHeight, heroRoom)) : heroMinHeight

    // Vertical budget (desktop). Each hero tier needs this much height; the
    // 7-day row may shrink from gridPref to gridMin before a tier is dropped.
    readonly property int gridPref: desktopMode ? 105 : 110
    readonly property int gridMin: desktopMode ? 84 : 110
    readonly property real hpad: desktopMode ? 8 : 16
    readonly property real chrome: pad * 2 + column.spacing
    // popup-only details strip under the metrics
    readonly property real detailsExtra: detailsStrip.visible ? heroContent.spacing + detailsStrip.Layout.topMargin + detailsStrip.implicitHeight : 0
    readonly property real heroCompact: hpad * 2 + titleLabel.implicitHeight + heroContent.spacing + metricsRow.implicitHeight + detailsExtra
    readonly property real heroSolar: detailsExtra + hpad * 2 + titleLabel.implicitHeight + heroContent.spacing
                                    + Math.max(metricsRow.implicitHeight, solarColumn.implicitHeight)
    readonly property real heroTrack: Math.max(210, heroSolar + heroContent.spacing + hourlyWell.implicitHeight)
    readonly property bool showSolar: !desktopMode || (showSolarCards && height >= heroSolar + gridMin + chrome)
    readonly property bool showTrack: desktopMode && !isMiniMode && heroSlots.length > 0 && height >= heroTrack + gridMin + chrome
    readonly property real heroNeed: showTrack ? heroTrack : showSolar ? heroSolar : heroCompact
    readonly property var days: weather ? weather.daily.slice(0, narrow ? 4 : 7) : []
    readonly property var sel: weather && selectedIndex < weather.daily.length ? weather.daily[selectedIndex] : null
    property date tick: new Date()
    // wall-clock time at the location (see Weather.localNow)
    readonly property date now: Weather.localNow(weather, tick)
    // Hero background: today follows the live solar phase and current
    // conditions; another selected day uses its own condition in daylight.
    readonly property string solarPhase: weather ? Weather.solarPhase(weather.daily[0], now) : "day"
    readonly property string heroCondition: !sel ? "cloudy" : selToday ? weather.current.condition : sel.condition
    readonly property bool selToday: selectedIndex === 0
    readonly property var heroSlots: !weather || !sel ? []
        : selToday ? Weather.upcomingSlots(weather, 6, 3, tick)      // follows the clock, so the strip advances between refreshes
                   : Weather.daySlots(weather, sel.date, [6, 9, 12, 15, 18, 21])

    // ---- theme ----
    // movieLight:    the 2005 film's Encyclopedia pages: cream paper, charcoal
    //                outlines with a flat offset shadow, coral / mustard / teal.
    // terminalDark:  the 1981 BBC Sub-Etha terminal: phosphor green on CRT black.
    // improbability: neon magenta and cyan wireframe on deep violet.
    // Under a skin "light" is the solid, flat card style, and the CRT
    // treatment (wireframe lines, raster, bloom, reticles) is only what the
    // skin's features turn on; nothing follows the Guide's day and night.
    readonly property bool crt: skin ? skin.fx.crtScanlines || skin.fx.phosphorDecay : themeStyle !== "movieLight"
    readonly property bool light: skin ? !crt : themeStyle === "movieLight"
    readonly property bool neon: themeStyle === "improbability"
    readonly property color bg:       skin ? skin.bg : light ? "#F5F2EB" : neon ? "#0A0612" : "#040806"
    readonly property color surface:  skin ? skin.card : light ? "#EDE8DC" : neon ? "#14091F" : "#071008"
    readonly property color text:     skin ? skin.ink : light ? "#1B2028" : neon ? "#FF2BD6" : "#00FF66"
    readonly property color outline:  skin ? skin.border : text
    readonly property color accent:   skin ? skin.accent : light ? "#FF6B4A" : neon ? "#00E5FF" : "#FFB000"   // sun, highs, badge, selection
    readonly property color mustard:  skin ? skin.mustard : light ? "#FFBE1A" : neon ? "#FFE65C" : "#FFB000"   // solar arcs, Arthur's towel
    readonly property color cool:     skin ? skin.cool : light ? "#26A69A" : neon ? "#00E5FF" : "#00E5FF"   // rain, feels-like
    readonly property color navy:     skin ? skin.ink : light ? "#2C3E50" : neon ? "#7A3CFF" : "#00FF66"   // Marvin accents
    readonly property color danger:   skin ? skin.alert : light ? "#E53935" : neon ? "#FF2BD6" : "#FF3333"
    readonly property color onAccent: skin ? (accent.hslLightness > 0.6 ? skin.charcoal : "#FFFFFF")
                                    : light ? "#FFFFFF" : bg                              // text on an accent-filled pill
    function onAccentA(a) { return Qt.rgba(onAccent.r, onAccent.g, onAccent.b, a) }
    readonly property string fontFamily: skin ? skin.sans : light ? Qt.application.font.family : "monospace"
    readonly property real pill: skin ? skin.pillRadius : light ? 20 : 0            // hourly strip, day cards, solar cards
    readonly property real cardRadius: skin ? skin.outerRadius : light ? 16 : 0      // hero card and tiles
    readonly property real lineW: skin ? skin.borderWidth : light ? 2 : 1.5          // outlines
    readonly property real thinW: skin ? Math.max(1, Math.min(2, skin.borderWidth)) : light ? 2 : 1
    readonly property bool scanlines: skin ? skin.fx.crtScanlines : !light
    readonly property bool flatShadow: skin ? skin.flatShadow : light   // 2px 2px offset solid shadow, no blur
    // MultiEffect phosphor glow, the Guide's terminal only (a skin's phosphor is its ThemeEffectsLayer)
    readonly property bool bloom: glow && !skin && !light
    readonly property bool reticles: skin ? skin.fx.cornerBrackets : !light
    readonly property bool gridShown: skin ? skin.fx.grid : true
    function lex(key, h2g2, neutral) { return skin ? skin.lex(key, h2g2, neutral) : h2g2 }
    // "GUIDE ENTRY: LONDON" for the Guide; under a skin its own label (lexicon
    // entryLabel) before the place, or the place alone.
    function entryOf(h2g2) {
        if (!skin) return h2g2
        var label = skin.lex("entryLabel", "", "")
        return (label ? label + ": " : "") + locationName.toUpperCase()
    }
    function tint(a) { return Qt.rgba(outline.r, outline.g, outline.b, a) }
    readonly property var iconPalette: ({ outline: outline, sun: light ? accent : mustard, precip: cool,
                                          bolt: mustard, boltCore: danger, bg: bg, solid: light })
    function tintAccent(a) { return Qt.rgba(accent.r, accent.g, accent.b, a) }
    // Names used throughout the card
    readonly property color primary: text
    readonly property color secondary: tint(light ? 0.74 : 0.62)
    readonly property color dim: tint(light ? 0.5 : 0.42)
    readonly property color low: tint(light ? 0.6 : 0.5)
    readonly property color wire: light ? outline : tint(0.5)        // card borders
    readonly property color wireDim: light ? outline : tint(0.28)
    readonly property color amber: accent
    readonly property color cyan: cool
    readonly property color warning: danger
    // Guide commentary for the hero's weather
    readonly property bool heroNight: selToday && weather ? !weather.current.isDay : false
    readonly property real heroWind: !weather || !sel ? 0 : selToday ? weather.current.wind : (sel.wind || 0)
    readonly property string guideText: !weather ? ""
        : skin ? Weather.skinEntry(skin, heroCondition, heroNight, heroWind)
        : Weather.guideEntry(heroCondition, heroNight, heroWind)
    readonly property real pad: desktopMode ? 8 : Kirigami.Units.largeSpacing

    function fmtTime(d) {
        return Qt.formatTime(d, "HH:mm")
    }
    function dayTitle(d, isToday) {
        var s = i18nc("short weekday, day of month, short month name", "%1 %2 %3",
                      Qt.locale().dayName(d.getDay(), Locale.ShortFormat), d.getDate(),
                      Qt.locale().monthName(d.getMonth(), Locale.ShortFormat))
        return isToday ? i18n("Today · %1", s) : s
    }
    function selectDay(i) {
        if (i === selectedIndex || heroSwap.running) return
        pendingIndex = i
        heroSwap.restart()
    }
    onWeatherChanged: {
        if (!weather || selectedIndex >= weather.daily.length) selectedIndex = 0
        if (weather && hadWeather) figure.triggerRoam()                 // fresh data: the pair wanders off to a new spot
        hadWeather = !!weather
    }
    property bool hadWeather: false

    // The pair also strolls whenever today's strip drops its first slot.
    // Day selection does not count: the value only changes between two
    // live slots of today.
    readonly property real firstSlotTime: selToday && heroSlots.length > 0 ? heroSlots[0].time.getTime() : 0
    property real lastSlotTime: 0
    onFirstSlotTimeChanged: {
        if (firstSlotTime > 0 && lastSlotTime > 0 && firstSlotTime !== lastSlotTime) figure.triggerRoam()
        lastSlotTime = firstSlotTime
    }

    Timer {   // keeps the solar phase current while the view is showing
        interval: 60 * 1000
        running: view.active
        repeat: true
        triggeredOnStart: true
        onTriggered: view.tick = new Date()
    }

    // Day swap, movie style: the hero contents (title, icon, temperature,
    // condition, solar cards and hourly strip) slide out to the right as one
    // pill, the data switches, then they slide back in from the left with a
    // small scale pop. No opacity cross-fade.
    property real heroSlideX: 0
    property real heroPop: 1
    SequentialAnimation {
        id: heroSwap
        ParallelAnimation {
            NumberAnimation { target: view; property: "heroSlideX"; to: 32; duration: 130; easing.type: Easing.InCubic }
            NumberAnimation { target: view; property: "heroPop"; to: 0.94; duration: 130; easing.type: Easing.InCubic }
        }
        ScriptAction { script: { view.selectedIndex = view.pendingIndex; view.heroSlideX = -40; view.heroPop = 0.85 } }
        ParallelAnimation {
            NumberAnimation { target: view; property: "heroSlideX"; to: 0; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
            NumberAnimation { target: view; property: "heroPop"; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
        }
    }
    // Entrance replay for the staggered pills (day cards, hourly slots) when a
    // section (re)appears after a tier change.
    property int entrance: 0
    onShowTrackChanged: if (showTrack) entrance++

    // Popup: content-sized. Desktop: filled by the applet, resizable via the handle.
    implicitWidth: desktopMode ? 480 : 460
    implicitHeight: desktopMode ? 260 : column.implicitHeight + pad * 2
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.minimumWidth: desktopMode ? miniMinWidth : implicitWidth
    Layout.minimumHeight: desktopMode ? miniMinHeight : implicitHeight

    radius: skin ? skin.outerRadius : 16   // the suite's outer-frame token (SubEthaTheme.outerRadius)
    color: !backdrop ? "transparent" : !desktopMode ? Qt.rgba(bg.r, bg.g, bg.b, light ? 0.97 : 0.94)
         : translucent ? Qt.rgba(bg.r, bg.g, bg.b, light ? 0.93 : 0.9) : bg
    border.width: backdrop ? lineW : 0
    border.color: wire

    // Blueprint grid: 24px squares in the theme's line colour, a tiled SVG
    // texture (one 24x24 tile uploaded once) instead of a Canvas repainted on
    // every resize.
    // Under a skin, its own grid in its ink (SkinGrid), never the Guide's art.
    component BlueprintGrid: Item {
        property real alpha: 0.05
        visible: view.gridShown
        Image {
            anchors.fill: parent
            visible: !view.skin
            source: visible ? Qt.resolvedUrl("images/grid-" + view.themeStyle + ".svg") : ""
            sourceSize: Qt.size(24, 24)
            fillMode: Image.Tile
            smooth: false
            asynchronous: true
            opacity: view.light ? parent.alpha * 1.4 : parent.alpha
        }
        SkinGrid {
            anchors.fill: parent
            visible: !!view.skin
            color: view.skin ? view.skin.ink : "transparent"
            opacity: parent.alpha * 1.6
        }
    }
    // Scanlines: a 1px dark line every 2px over the whole card, like a CRT
    // raster. A 4x2 tiled texture; the light theme has no raster.
    component Scanlines: Image {
        visible: view.scanlines && !view.skin   // a skin's raster is its ThemeEffectsLayer
        source: Qt.resolvedUrl("images/scanlines.svg")
        sourceSize: Qt.size(4, 2)
        fillMode: Image.Tile
        smooth: false
        asynchronous: true
        opacity: 0.15
    }
    // Flat offset shadow of the movie's paper cut-outs: a solid outline-coloured
    // copy 2px right and 2px down, no blur. Drop it into any Rectangle.
    component FlatShadow: Rectangle {
        visible: view.flatShadow
        z: -1
        anchors.fill: parent
        anchors.leftMargin: 2
        anchors.topMargin: 2
        anchors.rightMargin: -2
        anchors.bottomMargin: -2
        radius: parent.radius
        color: view.outline
    }
    // The movie's sliding pills: on creation (and when a section re-enters
    // after a tier change) the target slides in from 40px left with a
    // 0.85 -> 1.0 pop, staggered 40ms per index. Attach to a layout child;
    // it animates a Translate / Scale transform so the layout keeps control
    // of x and y.
    component PillEntrance: Item {
        id: pe
        property Item target
        property int index: 0
        visible: false
        readonly property Translate slide: Translate { x: 0 }
        readonly property Scale pop: Scale { xScale: 1; yScale: 1; origin.x: pe.target ? pe.target.width / 2 : 0; origin.y: pe.target ? pe.target.height / 2 : 0 }
        Component.onCompleted: {
            if (!target) return
            var t = target.transform
            var list = []
            for (var i = 0; i < t.length; i++) list.push(t[i])
            list.push(slide); list.push(pop)
            target.transform = list
            play.restart()
        }
        Connections { target: view; function onEntranceChanged() { play.restart() } }
        SequentialAnimation {
            id: play
            PauseAnimation { duration: pe.index * 40 }
            ScriptAction { script: { pe.slide.x = -40; pe.pop.xScale = 0.85; pe.pop.yScale = 0.85 } }
            ParallelAnimation {
                NumberAnimation { target: pe.slide; property: "x"; to: 0; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
                NumberAnimation { target: pe.pop; property: "xScale"; to: 1; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
                NumberAnimation { target: pe.pop; property: "yScale"; to: 1; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
            }
        }
    }
    // L-shaped targeting reticles, 8x8 at 1.5px, in the four corners of an item
    // (dark themes only).
    component Reticles: Canvas {
        property color color: view.skin ? view.skin.bracketColor : view.amber
        property real size: 8
        property real inset: 3
        visible: view.reticles
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Threaded
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = color
            ctx.lineWidth = 1.5
            ctx.lineCap = "square"
            var i = inset, s = size, w = width, h = height
            ctx.beginPath()
            ctx.moveTo(i, i + s); ctx.lineTo(i, i); ctx.lineTo(i + s, i)
            ctx.moveTo(w - i - s, i); ctx.lineTo(w - i, i); ctx.lineTo(w - i, i + s)
            ctx.moveTo(w - i, h - i - s); ctx.lineTo(w - i, h - i); ctx.lineTo(w - i - s, h - i)
            ctx.moveTo(i + s, h - i); ctx.lineTo(i, h - i); ctx.lineTo(i, h - i - s)
            ctx.stroke()
        }
    }

    // Label with a phosphor bloom on the desktop, where the wallpaper shows through.
    component ShadowLabel: PlasmaComponents3.Label {
        font.family: view.fontFamily
        id: sl
        padding: view.desktopMode ? 3 : 0
        layer.enabled: view.desktopMode && view.bloom
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: sl.color
            shadowOpacity: 0.45
            shadowBlur: 0.5
            blurMax: 8
            shadowVerticalOffset: 0
        }
    }

    // Flat icon button: 6px hover highlight, white mask icon.
    component HeaderButton: QQC2.AbstractButton {
        id: hb
        property string iconName
        property string tip
        implicitWidth: 28
        implicitHeight: 28
        hoverEnabled: true
        Accessible.name: tip
        background: Rectangle {
            radius: view.skin ? Math.min(14, view.skin.pillRadius) : view.light ? 14 : 0
            color: hb.checked ? view.tint(0.12)
                 : (hb.hovered || hb.down) ? view.tint(0.07) : "transparent"
            border.width: hb.checked || hb.hovered ? view.thinW : 0
            border.color: view.wireDim
        }
        contentItem: Item {
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 16; height: 16
                source: hb.iconName
                isMask: true
                color: hb.checked ? view.amber : view.primary
                opacity: hb.checked || hb.hovered ? 1 : 0.8
            }
        }
        PlasmaComponents3.ToolTip.text: tip
        PlasmaComponents3.ToolTip.visible: hovered && tip !== ""
        PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
    }

    // Sunrise / sunset mini card inside the hero.
    component SolarCard: Rectangle {
        id: sc
        property string label
        property date time
        property bool sunset: false
        implicitWidth: 136
        implicitHeight: 44
        Layout.minimumHeight: implicitHeight
        radius: view.pill
        color: view.light ? view.surface : view.tint(0.04)
        border.width: view.thinW
        border.color: view.wireDim

        FlatShadow {}
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: view.light ? 14 : 10
            anchors.rightMargin: 8
            spacing: 6
            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true
                PlasmaComponents3.Label {
                    font.family: view.fontFamily
                    text: sc.label
                    color: view.secondary
                    font.pixelSize: 11
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.5
                }
                PlasmaComponents3.Label {
                    font.family: view.fontFamily
                    text: view.fmtTime(sc.time)
                    color: view.primary
                    font.pixelSize: 13
                    font.bold: true
                    font.features: { "tnum": 1 }
                }
            }
            SunArc {
                sunset: sc.sunset
                sunColor: sc.sunset ? (view.light ? view.accent : view.warning) : view.mustard
                strokeColor: view.light ? view.tint(0.35) : view.wireDim
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    BlueprintGrid { anchors.fill: parent; anchors.margins: view.textureInset; z: 0; alpha: 0.035 }

    Rectangle {   // the hero card's flat shadow (a sibling: the hero clips its own children)
        visible: view.flatShadow && hero.visible && view.flipAngle < 90
        z: 0
        x: column.x + hero.x + 2
        y: column.y + hero.y + 2
        width: hero.width
        height: hero.height
        radius: hero.radius
        color: view.outline
    }

    LocationSearch {
        id: locationSearch
        visible: view.searching
        ink: view.text
        accentCool: view.cool
        danger: view.danger
        bg: view.bg
        light: view.light
        fontFamily: view.fontFamily
        parent: view.desktopMode ? heroTitleSlot : headerTitleSlot
        anchors.fill: parent
        onChosen: (name, latitude, longitude) => { view.searching = false; view.locationChosen(name, latitude, longitude) }
        onDismissed: view.searching = false
    }

    // Back side of the desktop card: a grid of detail tiles. Pre-rotated 180°
    // so it reads correctly once the whole card has turned over.
    Item {
        id: backPanel
        visible: view.flipAngle >= 90
        anchors.fill: parent
        anchors.margins: view.pad
        transform: Rotation {
            origin.x: backPanel.width / 2
            origin.y: backPanel.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: 180
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: view.flipped = false
        }
        ColumnLayout {
            anchors.fill: parent
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                ShadowLabel {
                    text: (view.locationName !== "" ? view.entryOf(i18n("GUIDE ENTRY: %1", view.locationName.toUpperCase())) + " · " : "") + i18n("Details")
                    color: view.secondary
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.8
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                ShadowLabel {
                    text: view.updatedText
                    color: view.dim
                    font.pixelSize: 11
                    font.features: { "tnum": 1 }
                }
            }
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: view.narrow ? 2 : 4
                rowSpacing: 6
                columnSpacing: 6
                Repeater {
                    model: view.detailKeys
                    DetailTile {
                        required property var modelData
                        detail: modelData
                        valueSize: 15
                        watermark: 0.95
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 44
                    }
                }
            }
            ShadowLabel {
                text: view.selToday && view.cur ? view.cur.text + " · " + i18n("Click to flip back") : i18n("Click to flip back")
                color: view.dim
                font.pixelSize: 10
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // Silhouette pair roaming the desktop card. It is an overlay above every
    // section, so no collapsing row clips it: in the full tier its feet rest on
    // the hourly strip's top edge, in the mid and miniature tiers on the hero
    // card's bottom border. The position follows the strip as it collapses,
    // so switching tiers never makes the pair jump. It starts in the gap
    // between the temperature text and the solar cards.
    // A skin's sprite walkers take the same track and ground line.
    readonly property bool skinRoamers: !!skin && skin.roamers.length > 0
    SpriteRoamers {
        z: 10
        visible: view.skinRoamers && view.showCharacter && view.ambientAnimations
        roamers: view.skin ? view.skin.roamers : []
        groundStyle: view.skin ? view.skin.ground : null
        hovered: heroMouse.containsMouse
        // a load spike, or the pointer, sets off the line's havoc; storms and spikes redden its ground
        havoc: heroMouse.containsMouse || (!!view.skin && view.skin.mood === "stressed")
        alert: (!!view.skin && view.skin.mood === "stressed") || view.heroCondition === "thunder"
               || (!!view.weather && view.weather.current.wind >= 40)
        noteColor: view.text
        readonly property real heroX: column.x + hero.x
        readonly property real heroY: column.y + hero.y
        readonly property real edgeY: heroY + hero.height - 1 - ground
        readonly property real stripY: heroY + hero.hpad + hourlyWell.y - ground
        opacity: view.desktopMode && hero.visible && view.flipAngle < 90 ? (view.isMiniMode ? 0.5 : 1) : 0
        y: edgeY + (stripY - edgeY) * view.hourlyVisibility
        minTrackX: heroX + 16
        maxTrackX: Math.max(heroX + 20, heroX + hero.width - width - 16)
        homeX: heroX + (hero.width - width) / 2
        running: view.active && visible && opacity > 0
    }

    WeatherCharacter {
        id: figure
        z: 10
        readonly property real restOpacity: view.light ? (view.isMiniMode ? 0.4 : 0.85) : (view.isMiniMode ? 0.35 : 0.55)   // fainter over the miniature tile's text
        style: view.light ? "solid" : "wire"
        color: view.text
        accent: view.mustard
        headColor: view.light ? "#FFFFFF" : view.text
        navy: view.navy
        fontFamily: view.fontFamily
        readonly property real heroX: column.x + hero.x
        readonly property real heroY: column.y + hero.y
        readonly property real edgeY: heroY + hero.height - 1 - ground                               // feet on the hero's bottom border
        readonly property real stripY: heroY + hero.hpad + hourlyWell.y - ground    // feet on the strip's top edge
        visible: view.showCharacter && view.ambientAnimations && !view.skin   // the Guide's own pair; a skin brings its roamers or none
        // only the desktop card shows the pair, and only its front side
        opacity: view.desktopMode && hero.visible && view.flipAngle < 90 ? restOpacity : 0
        y: edgeY + (stripY - edgeY) * view.hourlyVisibility
        minTrackX: heroX + 16
        maxTrackX: Math.max(heroX + 20, heroX + hero.width - width - 16)
        homeX: view.isFullMode ? heroX + hero.hpad + metricsRow.x + descColumn.x + descColumn.width / 2 - width / 2
             : heroX + (hero.width - width) / 2
        condition: ambient.condition
        isNight: ambient.isNight
        windSpeed: ambient.windSpeed
        // today's live temperature, or the selected day's high
        temperature: !view.weather || !view.sel ? 15 : view.selToday ? view.weather.current.temp : view.sel.max
        running: ambient.running && visible && opacity > 0
        Connections {
            target: ambient
            function onLightning() { figure.duck() }
        }
    }

    ColumnLayout {
        id: column
        visible: view.flipAngle < 90
        anchors.fill: parent
        anchors.margins: view.pad
        spacing: 8

        // ---- header (panel popup only) ----
        RowLayout {
            visible: !view.desktopMode
            z: 5
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            Layout.minimumHeight: 48
            spacing: 4

            WeatherIcon {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: 2
                condition: view.weather ? view.weather.current.condition : "cloudy"
                code: view.weather ? view.weather.current.code : -1
                isDay: view.weather ? view.weather.current.isDay : true
                iconStyle: view.cardIconStyle
                palette: view.iconPalette
                running: view.active
            }
            HeaderButton {
                iconName: "window-pin"
                tip: view.pinned ? i18n("Unpin") : i18n("Keep open")
                checkable: true
                checked: view.pinned
                onClicked: view.pinRequested()
            }
            Item {
                id: headerTitleSlot
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.preferredHeight: 28
                z: 5
                PlasmaComponents3.Label {
                    font.family: view.fontFamily
                    anchors.fill: parent
                    visible: !view.searching
                    text: view.locationName !== "" ? view.entryOf(i18n("GUIDE ENTRY: %1", view.locationName.toUpperCase())) : ""
                    color: view.primary
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.6
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.openSearch()
                        PlasmaComponents3.ToolTip.text: i18n("Change location")
                        PlasmaComponents3.ToolTip.visible: containsMouse
                        PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                        hoverEnabled: true
                    }
                }
            }
            HeaderButton {
                iconName: "view-refresh"
                tip: i18n("Refresh")
                onClicked: view.refreshRequested()
            }
            HeaderButton {
                iconName: "configure"
                tip: i18n("Settings")
                onClicked: view.configureRequested()
            }
            HeaderButton {
                iconName: view.forecastCollapsed ? "window-restore" : "window-minimize"
                tip: view.forecastCollapsed ? i18n("Show forecast") : i18n("Minimize")
                onClicked: view.minimizeRequested()
            }
            HeaderButton {
                iconName: "window-close"
                tip: i18n("Close")
                onClicked: view.closeRequested()
            }
        }

        ShadowLabel {
            visible: !view.weather
            text: view.errorText !== "" ? view.errorText : i18n("Loading…")
            color: view.secondary
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: view.desktopMode
            Layout.margins: view.desktopMode ? 0 : Kirigami.Units.gridUnit * 2
            verticalAlignment: Text.AlignVCenter
        }

        // ---- hero card ----
        Rectangle {
            id: hero
            visible: !!view.weather
            z: 3
            Layout.fillWidth: true
            Layout.fillHeight: view.desktopMode
            Layout.preferredHeight: view.heroFloor
            Layout.minimumHeight: view.heroFloor
            radius: view.cardRadius
            clip: true
            color: view.light ? view.surface : view.tint(0.025)
            border.width: view.lineW
            border.color: view.wire

            readonly property real hpad: view.hpad

            BlueprintGrid { anchors.fill: parent; z: 0 }

            HeroAmbientEffects {   // behind everything else in the card
                id: ambient
                anchors.fill: parent
                z: 0
                cornerRadius: hero.radius
                palette: ({ outline: view.outline, accent: view.accent, cool: view.cool, danger: view.danger, light: view.light })
                hazards: view.skin ? view.skin.hazards : []
                lore: !view.skin          // the whale, the petunias and the improbability flash are the Guide's
                fontFamily: view.fontFamily
                running: view.ambientAnimations && view.active && hero.visible && !view.flipped
                condition: view.heroCondition
                isNight: view.selToday && view.weather ? !view.weather.current.isDay : false
                windSpeed: !view.weather || !view.sel ? 0 : view.selToday ? view.weather.current.wind : (view.sel.wind || 0)
            }

            MouseArea {   // desktop: hover reveals refresh, click flips to the details side
                id: heroMouse
                anchors.fill: parent
                hoverEnabled: view.desktopMode
                acceptedButtons: view.desktopMode && !view.isMiniMode ? Qt.LeftButton : Qt.NoButton
                cursorShape: acceptedButtons !== Qt.NoButton ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: view.flipped = true
            }

            ColumnLayout {
                id: heroContent
                anchors.fill: parent
                anchors.margins: hero.hpad
                spacing: 4
                transform: [
                    Translate { x: view.heroSlideX },
                    Scale { origin.x: heroContent.width / 2; origin.y: heroContent.height / 2; xScale: view.heroPop; yScale: view.heroPop }
                ]

                // top row: "London · Today · Wed 21 Oct" (location only on the desktop)
                Item {
                    id: heroTitleSlot
                    visible: view.searching
                    z: 5
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    Layout.minimumHeight: 28
                    Layout.rightMargin: view.desktopMode ? panicBadge.width + 36 : panicBadge.width + 6
                }
                ShadowLabel {
                    id: titleLabel
                    visible: !view.searching && view.miniProgress < 1
                    opacity: 1 - view.miniProgress
                    Layout.minimumHeight: implicitHeight
                    MouseArea {
                        anchors.fill: parent
                        enabled: view.desktopMode
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: view.openSearch()
                    }
                    text: (view.desktopMode && view.locationName !== "" ? view.entryOf(i18n("GUIDE ENTRY: %1 [SECTOR ZZ9]", view.locationName.toUpperCase())) + " · " : "")
                        + (view.sel ? view.dayTitle(view.sel.date, view.selToday) : "")
                    color: view.secondary
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: view.desktopMode ? 0.8 : 0.5
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.rightMargin: view.desktopMode ? panicBadge.width + 36 : panicBadge.width + 6   // room for the badge and the hover refresh button
                }

                // middle row: metrics on the left, solar cards on the right
                RowLayout {
                    id: metricsRow
                    visible: view.miniProgress < 1
                    opacity: 1 - view.miniProgress
                    spacing: 12
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: implicitHeight

                    // primary icon for the day the hero shows (today = current observation)
                    WeatherIcon {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        Layout.alignment: Qt.AlignVCenter
                        condition: !view.sel ? "cloudy" : view.selToday ? view.weather.current.condition : view.sel.condition
                        code: !view.sel ? -1 : view.selToday ? view.weather.current.code : view.sel.code
                        isDay: !view.sel || !view.selToday ? true : view.weather.current.isDay
                        iconStyle: view.cardIconStyle
                        palette: view.iconPalette
                        running: view.active
                    }
                    ShadowLabel {
                        text: view.sel ? Math.round(view.selToday ? view.weather.current.temp : view.sel.max) + "°" : ""
                        color: view.primary
                        font.pixelSize: 38
                        font.bold: true
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: -4
                    }
                    ColumnLayout {
                        id: descColumn
                        spacing: 0
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        ShadowLabel {
                            text: view.sel ? (view.selToday ? view.weather.current.text : view.sel.text) : ""
                            color: view.primary
                            font.pixelSize: view.desktopMode ? 16 : 14
                            font.weight: view.desktopMode ? Font.DemiBold : Font.Medium
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        ShadowLabel {
                            text: view.sel ? i18n("H: %1°  L: %2°", Math.round(view.sel.max), Math.round(view.sel.min)) : ""
                            color: view.secondary
                            font.pixelSize: 12
                        }
                        ShadowLabel {   // Guide commentary
                            text: view.guideText
                            color: view.amber
                            font.pixelSize: 9
                            font.letterSpacing: 0.4
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                        }
                    }

                    ColumnLayout {
                        id: solarColumn
                        visible: view.solarVisibility > 0
                        opacity: view.solarVisibility
                        clip: view.solarVisibility < 1
                        spacing: 6
                        Layout.alignment: Qt.AlignVCenter
                        // never squeezed below the cards' width (the description column shrinks instead)
                        Layout.minimumWidth: implicitWidth * view.solarVisibility
                        Layout.preferredWidth: implicitWidth * view.solarVisibility
                        Layout.maximumWidth: implicitWidth * view.solarVisibility
                        SolarCard {
                            label: i18n("Sunrise")
                            time: view.sel ? view.sel.sunrise : new Date()
                        }
                        SolarCard {
                            label: i18n("Sunset")
                            time: view.sel ? view.sel.sunset : new Date()
                            sunset: true
                        }
                    }
                }

                // bottom row: hourly progression of the selected day (desktop, when there is room)
                // popup: today's details (or the selected day's) as a strip of tiles
                ColumnLayout {
                    id: detailsStrip
                    visible: !view.desktopMode && !!view.weather
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    spacing: 3
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: view.detailKeys.filter(function (d) { return ["feels", "humidity", "wind", "uv", "rain"].indexOf(d.key) >= 0 })
                            DetailTile {
                                required property var modelData
                                detail: modelData
                                compact: true
                                Layout.fillWidth: true
                                Layout.preferredHeight: 46
                            }
                        }
                    }
                    PlasmaComponents3.Label {
                        font.family: view.fontFamily
                        text: view.updatedText
                        color: view.dim
                        font.pixelSize: 10
                        font.features: { "tnum": 1 }
                        Layout.alignment: Qt.AlignRight
                    }
                }

                Rectangle {
                    id: hourlyWell
                    visible: view.hourlyVisibility > 0
                    opacity: view.hourlyVisibility
                    Layout.fillWidth: true
                    Layout.minimumHeight: implicitHeight * view.hourlyVisibility
                    Layout.preferredHeight: implicitHeight * view.hourlyVisibility
                    Layout.maximumHeight: implicitHeight * view.hourlyVisibility
                    implicitHeight: track.implicitHeight + 12
                    radius: view.pill
                    color: view.light ? view.bg : Qt.rgba(0, 0, 0, 0.3)
                    border.width: view.thinW
                    border.color: view.wireDim
                    // the strip slides in from the left as a pill while it is revealed
                    transform: [
                        Translate { x: -40 * (1 - view.hourlyVisibility) },
                        Scale { origin.x: 0; origin.y: hourlyWell.height / 2; xScale: 0.85 + 0.15 * view.hourlyVisibility; yScale: xScale }
                    ]

                    FlatShadow {}
                    Item {   // clips the strip while it collapses
                        anchors.fill: parent
                        clip: true
                        RowLayout {
                            id: track
                            x: view.light ? 10 : 6; y: 6
                            width: parent.width - 2 * x
                            spacing: 0
                            Repeater {
                                model: view.heroSlots
                                ColumnLayout {
                                    id: hs
                                    required property var modelData
                                    required property int index
                                    spacing: 1
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    PillEntrance { target: hs; index: hs.index }
                                    PlasmaComponents3.Label {
                                        font.family: view.fontFamily
                                        text: Qt.formatTime(hs.modelData.time, "HH:mm")
                                        color: view.secondary
                                        font.pixelSize: 10
                                        font.features: { "tnum": 1 }
                                        horizontalAlignment: Text.AlignHCenter
                                        Layout.fillWidth: true
                                    }
                                    WeatherIcon {
                                        Layout.preferredWidth: 18
                                        Layout.preferredHeight: 18
                                        Layout.alignment: Qt.AlignHCenter
                                        condition: hs.modelData.condition
                                        code: hs.modelData.code
                                        iconStyle: view.cardIconStyle
                                        palette: view.iconPalette
                                        isDay: hs.modelData.isDay
                                    }
                                    PlasmaComponents3.Label {
                                        font.family: view.fontFamily
                                        text: Math.round(hs.modelData.temp) + "°"
                                        color: view.primary
                                        font.pixelSize: 11
                                        horizontalAlignment: Text.AlignHCenter
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Miniature view: icon beside the temperature, condition and
            // feels-like, crossfaded over the regular rows. Lines are added
            // as the card grows taller.
            RowLayout {
                id: miniContent
                visible: view.miniProgress > 0
                opacity: view.miniProgress
                z: 2
                anchors.fill: parent
                anchors.margins: hero.hpad
                spacing: 8
                readonly property real iconSize: Math.max(28, Math.min(64, hero.height * 0.55, hero.width * 0.3))
                readonly property real tempSize: Math.max(22, Math.min(40, hero.height * 0.28))
                readonly property bool showFeels: hero.height >= 96
                readonly property bool showLocation: hero.height >= 124 && view.locationName !== ""

                WeatherIcon {
                    Layout.preferredWidth: miniContent.iconSize
                    Layout.preferredHeight: miniContent.iconSize
                    Layout.alignment: Qt.AlignVCenter
                    condition: view.cur ? view.cur.condition : "cloudy"
                    code: view.cur ? view.cur.code : -1
                    isDay: view.cur ? view.cur.isDay : true
                    iconStyle: view.cardIconStyle
                    palette: view.iconPalette
                    running: view.active
                }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    ShadowLabel {   // location, click to change
                        visible: miniContent.showLocation && !view.searching
                        text: view.entryOf(i18n("GUIDE ENTRY: %1", view.locationName.toUpperCase()))
                        color: view.secondary
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 0.6
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.rightMargin: 28   // room for the hover refresh button
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.openSearch()
                        }
                    }
                    ShadowLabel {
                        text: view.cur ? Math.round(view.cur.temp) + "°" : "--°"
                        color: view.primary
                        font.pixelSize: miniContent.tempSize
                        font.bold: true
                        Layout.leftMargin: -2
                    }
                    ShadowLabel {
                        text: view.cur ? view.cur.text : ""
                        color: view.primary
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    ShadowLabel {
                        visible: miniContent.showFeels
                        text: i18n("Feels like %1°", view.currentFeelsLike)
                        color: view.secondary
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    ShadowLabel {   // Guide commentary
                        visible: hero.height >= 150
                        text: view.guideText
                        color: view.amber
                        font.pixelSize: 8
                        font.letterSpacing: 0.3
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            Reticles { anchors.fill: parent; z: 4 }

            Rectangle {   // "DON'T PANIC" badge, upper right, with a glowing amber border
                id: panicBadge
                z: 6
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 6
                visible: view.showBadge && hero.width >= 230 && !view.searching
                width: visible ? panicText.implicitWidth + 14 : 0
                height: view.light ? 18 : 16
                radius: view.skin ? Math.min(height / 2, view.skin.pillRadius) : 9
                color: view.skin ? view.skin.badge : view.light ? view.accent : view.tintAccent(0.08)
                border.width: view.skin ? view.thinW : view.light ? 2 : 1
                border.color: view.skin ? view.skin.border : view.light ? view.outline : view.amber
                FlatShadow {}
                layer.enabled: view.bloom
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: view.amber
                    shadowOpacity: 0.7
                    shadowBlur: 0.8
                    blurMax: 12
                    shadowVerticalOffset: 0
                }
                PlasmaComponents3.Label {
                    font.family: view.fontFamily
                    id: panicText
                    anchors.centerIn: parent
                    text: view.skin ? view.skin.badgeText : i18n("DON'T PANIC")
                    color: view.skin ? view.skin.badgeInk : view.light ? view.onAccent : view.amber
                    font.pixelSize: 8
                    font.bold: true
                    font.letterSpacing: 1.1
                }
                SequentialAnimation on opacity {   // a slow phosphor breath
                    running: view.active && view.ambientAnimations && (!view.skin || view.skin.fx.phosphorDecay)
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.72; duration: 1800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 1800; easing.type: Easing.InOutSine }
                }
            }

            HeaderButton {   // discreet refresh, left of the badge, shown while hovering the hero
                visible: view.desktopMode
                z: 6
                anchors.top: parent.top
                anchors.right: panicBadge.left
                anchors.topMargin: 0
                anchors.rightMargin: 2
                iconName: "view-refresh"
                tip: i18n("Refresh")
                opacity: heroMouse.containsMouse || hovered ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                onClicked: view.refreshRequested()
            }
        }

        // ---- forecast grid: 7 days, or 4 when the desktop widget is narrow ----
        RowLayout {
            id: grid
            visible: !!view.weather && !view.forecastCollapsed && view.weeklyVisibility > 0
            opacity: view.weeklyVisibility
            clip: view.weeklyVisibility < 1
            Layout.fillWidth: true
            Layout.preferredHeight: view.gridPref * view.weeklyVisibility
            Layout.minimumHeight: view.gridMin * view.weeklyVisibility
            Layout.maximumHeight: view.weeklyVisibility < 1 ? view.gridPref * view.weeklyVisibility : Number.POSITIVE_INFINITY
            spacing: 6

            Repeater {
                model: view.days

                Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool selected: index === view.selectedIndex

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    Layout.minimumWidth: 52

                    // the selected pill lifts 6px and fills with the accent colour
                    transform: Translate { id: lift; y: cell.selected ? -6 : 0; Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutBack } } }

                    Rectangle {   // soft glow around the selected card (dark themes)
                        visible: !view.light && !view.skin
                        anchors.fill: card
                        anchors.margins: -2
                        radius: card.radius + 2
                        color: "transparent"
                        border.width: 2
                        border.color: view.amber
                        opacity: cell.selected ? 0.22 : 0
                        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    }
                    Rectangle {
                        id: card
                        readonly property color fill: cell.selected ? (view.light ? view.accent : view.tintAccent(0.14))
                                                    : (view.light ? view.surface : view.tint(0.03))
                        readonly property color stroke: view.light ? view.outline : cell.selected ? view.amber : view.wireDim
                        readonly property real strokeWidth: view.light ? 2 : cell.selected ? 1.5 : 1
                        anchors.fill: parent
                        radius: view.pill
                        // a skin draws the card in its own pill shape (shell, below)
                        color: view.skin ? "transparent" : fill
                        border.width: view.skin ? 0 : strokeWidth
                        border.color: stroke
                        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                        Behavior on border.color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                        Behavior on border.width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                        FlatShadow { visible: view.flatShadow && !view.skin }
                        PillEntrance { target: card; index: cell.index }

                        ThemeShapeContainer {
                            id: shell
                            z: -1
                            visible: !!view.skin
                            anchors.fill: parent
                            theme: view.skin
                            role: "pill"
                            fillColor: view.skin && cellMouse.containsMouse && !cell.selected ? view.skin.cardHover : card.fill
                            strokeColor: card.stroke
                            strokeWidth: Math.max(card.strokeWidth, view.skin ? view.skin.borderWidth : 0)
                            cornerBrackets: cell.selected && borderStyle === "tech-brackets"
                            bracketColor: view.amber
                            bracketSize: 7
                            bracketInset: 3
                            Behavior on fillColor { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: card.height >= 100 ? 6 : 4

                            PlasmaComponents3.Label {

                                font.family: view.fontFamily
                                text: Qt.locale().dayName(cell.modelData.date.getDay(), Locale.ShortFormat)
                                color: cell.selected ? (view.light ? view.onAccent : view.amber) : view.secondary
                                font.capitalization: Font.AllUppercase
                                font.pixelSize: 12
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                            WeatherIcon {
                                Layout.preferredWidth: card.height >= 100 ? 32 : 28
                                Layout.preferredHeight: Layout.preferredWidth
                                Layout.alignment: Qt.AlignHCenter
                                condition: cell.modelData.condition
                                code: cell.modelData.code
                                iconStyle: view.cardIconStyle
                                palette: view.iconPalette
                            }
                            RowLayout {
                                spacing: 0
                                Layout.alignment: Qt.AlignHCenter
                                PlasmaComponents3.Label {
                                    font.family: view.fontFamily
                                    text: Math.round(cell.modelData.max) + "°"
                                    color: cell.selected && view.light ? view.onAccent : view.primary
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                }
                                PlasmaComponents3.Label {
                                    font.family: view.fontFamily
                                    text: " / "
                                    color: cell.selected && view.light ? (view.skin ? view.onAccentA(0.7) : Qt.rgba(1, 1, 1, 0.7)) : view.low
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                }
                                PlasmaComponents3.Label {
                                    font.family: view.fontFamily
                                    text: Math.round(cell.modelData.min) + "°"
                                    color: cell.selected && view.light ? (view.skin ? view.onAccentA(0.7) : Qt.rgba(1, 1, 1, 0.7)) : view.low
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                }
                            }
                        }

                        Rectangle {   // hover brightness (a skin's shell changes its fill instead)
                            visible: !view.skin
                            anchors.fill: parent
                            radius: card.radius
                            color: view.skin ? view.tint(0.06) : view.light ? Qt.rgba(1, 1, 1, 0.35) : view.tint(0.04)
                            opacity: cellMouse.containsMouse ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }
                        MouseArea {
                            id: cellMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.selectDay(cell.index)
                        }
                    }
                }
            }
        }
    }

    Scanlines {   // CRT raster over everything, both sides of the card
        anchors.fill: parent
        anchors.margins: view.textureInset   // clear of the rounded or cut corners
        z: 30
    }
    ThemeEffectsLayer {   // a skin's raster, phosphor decay and glass sheen (its reticles are the hero's)
        visible: !!view.skin
        anchors.fill: parent
        anchors.margins: view.textureInset
        z: 30
        theme: view.skin
        brackets: false
        radius: view.radius
        running: view.active
    }
}
