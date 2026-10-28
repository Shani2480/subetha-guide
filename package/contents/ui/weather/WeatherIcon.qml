import QtQuick
import QtQuick.Shapes
import "code/weather.js" as Weather

// Weather icon in one of four styles:
//  - "glass3d":  volumetric frosted-glass / neon-glow art painted on a Canvas
//                (gradient-lit cloud, glowing cyan rain, glossy moon, golden sun,
//                twilight storm cloud) over a soft backing light.
//  - "handdrawn": flat vector art from QML primitives with particle animation.
//  - "wireframe": Sub-Etha CRT vector outlines in the theme palette (phosphor
//                green, amber and cyan by default) painted on a Canvas, like the
//                1981 BBC Guide animations; `palette.solid` gives a filled print look.
//  - an SVG folder name (white, black, solid-white, solid-black).
// Set `running` to play the animation; when false the icon rests in a static pose.
Item {
    id: icon

    property string condition: "clear"   // clear, partly, cloudy, fog, rain, snow, thunder
    property bool isDay: true
    property bool running: false
    // WMO code (optional, picks a more precise SVG) and style:
    // "glass3d", "handdrawn", "wireframe" or an icon folder in contents/icons (white, black, solid-white, solid-black)
    property int code: -1
    property string iconStyle: "handdrawn"
    // Colours for the wireframe style; the card passes its theme palette.
    // `solid` switches to the print-graphic variant (filled cloud, sun and
    // moon, slightly heavier precipitation) for light themes.
    override property var palette: ({ outline: "#00FF66", sun: "#FFB000", precip: "#00E5FF", bolt: "#FFB000", boltCore: "#FF3333", bg: "#040806", solid: false })
    onPaletteChanged: wireArt.requestPaint()

    readonly property bool handDrawn: iconStyle === "handdrawn"
    readonly property bool glass: iconStyle === "glass3d"
    readonly property bool wire: iconStyle === "wireframe"
    readonly property string svgName: Weather.wuIcon(code, isDay, condition)
    // The whole image is never rotated: a spinning sun would also spin the
    // cloud beside it, and a stopped spin left later icons frozen sideways.
    readonly property string svgMotion: svgName.indexOf("tstorms") >= 0 ? "flash"
        : /^(nt_)?(sunny|clear|mostlysunny)$/.test(svgName) ? "glow"
        : /rain|sleet|snow|flurries/.test(svgName) ? "fall" : "drift"
    property real motionX: 0
    property real motionY: 0
    property real motionFlash: 1

    readonly property real s: Math.min(width, height)
    // Boxes under 30px (panel / system tray cells) get the glass art enlarged
    // so the glyph, not its breathing room, fills the space.
    readonly property bool dense: s < 30
    readonly property real denseScale: 1.25
    readonly property bool thunder: condition === "thunder"
    readonly property bool precip: condition === "rain" || condition === "snow" || condition === "thunder"
    // Clouds are light pills (#ECEFF1); the storm cloud gets an indigo-to-purple gradient.
    readonly property color cloudTop: thunder ? "#3949AB" : (condition === "fog" ? "#CFD8DC" : "#ECEFF1")
    readonly property color cloudBottom: thunder ? "#8E24AA" : cloudTop

    implicitWidth: 32
    implicitHeight: 32

    // A particle that falls (rain/snow) and fades; rests visible at restY when not running.
    component Particle: Rectangle {
        id: p
        property real baseX
        property real restY
        property real fromY
        property real toY
        property real sway: 0
        property int delay: 0
        property int duration: 900
        property bool active: icon.running

        x: baseX
        y: restY
        onActiveChanged: if (!active) { x = baseX; y = restY; opacity = 1 }

        SequentialAnimation {
            running: p.active
            loops: Animation.Infinite
            PauseAnimation { duration: p.delay }
            ParallelAnimation {
                NumberAnimation { target: p; property: "y"; from: p.fromY; to: p.toY; duration: p.duration }
                NumberAnimation {
                    target: p; property: "x"
                    from: p.baseX - p.sway; to: p.baseX + p.sway
                    duration: p.duration; easing.type: Easing.InOutSine
                }
                SequentialAnimation {
                    NumberAnimation { target: p; property: "opacity"; from: 0; to: 1; duration: p.duration * 0.2 }
                    NumberAnimation { target: p; property: "opacity"; to: 0; duration: p.duration * 0.8 }
                }
            }
        }
    }

    // --- Sun (day, clear/partly) ---
    Item {
        id: sun
        visible: icon.handDrawn && (icon.condition === "clear" || icon.condition === "partly") && icon.isDay
        readonly property bool full: icon.condition === "clear"
        width: icon.s * (full ? 0.8 : 0.56)
        height: width
        x: full ? (icon.width - width) / 2 : icon.s * 0.04
        y: full ? (icon.height - height) / 2 : icon.s * 0.04

        Item {
            anchors.fill: parent
            RotationAnimator on rotation {
                from: 0; to: 360; duration: 14000
                loops: Animation.Infinite
                running: icon.running && sun.visible
            }
            Repeater {
                model: 8
                Rectangle {
                    width: sun.width * 0.09
                    height: sun.width * 0.2
                    radius: width / 2
                    color: "#FFB300"
                    x: (sun.width - width) / 2
                    y: 0
                    transform: Rotation {
                        origin.x: width / 2
                        origin.y: sun.height / 2
                        angle: index * 45
                    }
                }
            }
        }
        Rectangle {   // glow halo
            anchors.centerIn: parent
            width: parent.width * 0.78
            height: width
            radius: width / 2
            color: "#FFB300"
            opacity: 0.28
            scale: sunDisc.scale
        }
        Rectangle {
            id: sunDisc
            anchors.centerIn: parent
            width: parent.width * 0.52
            height: width
            radius: width / 2
            color: "#FFB300"
            SequentialAnimation on scale {
                running: icon.running && sun.visible
                loops: Animation.Infinite
                NumberAnimation { to: 1.1; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
            }
        }
    }

    // --- Moon (night, clear/partly) ---
    Canvas {
        id: moon
        visible: icon.handDrawn && (icon.condition === "clear" || icon.condition === "partly") && !icon.isDay
        readonly property bool full: icon.condition === "clear"
        // moon box inside the icon
        readonly property real ms: icon.s * (full ? 0.72 : 0.5)
        readonly property real mx: full ? (icon.width - ms) / 2 : icon.s * 0.06
        readonly property real my: full ? (icon.height - ms) / 2 : icon.s * 0.06
        anchors.fill: parent
        // Every Canvas here paints on the Canvas render thread instead of the
        // GUI thread. (Qt 6 ignores the FramebufferObject target and uses an
        // Image texture; the hint is kept for Qt 5-style builds.)
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Threaded
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onFullChanged: requestPaint()

        function star(ctx, cx, cy, r) {
            ctx.beginPath()
            for (var i = 0; i < 8; i++) {
                var a = i * Math.PI / 4
                var rr = (i % 2 === 0) ? r : r * 0.35
                var px = cx + Math.cos(a) * rr
                var py = cy + Math.sin(a) * rr
                if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py)
            }
            ctx.closePath()
            ctx.fill()
        }
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.globalCompositeOperation = "source-over"
            ctx.fillStyle = "#CE93D8"
            ctx.beginPath()
            ctx.arc(mx + ms / 2, my + ms / 2, ms * 0.46, 0, Math.PI * 2)
            ctx.fill()
            ctx.globalCompositeOperation = "destination-out"
            ctx.beginPath()
            ctx.arc(mx + ms * 0.68, my + ms * 0.38, ms * 0.38, 0, Math.PI * 2)
            ctx.fill()
            ctx.globalCompositeOperation = "source-over"
            ctx.fillStyle = "#FFFFFF"
            star(ctx, mx + ms * 0.80, my + ms * 0.24, ms * 0.11)
            star(ctx, mx + ms * 0.98, my + ms * 0.50, ms * 0.07)
        }
        SequentialAnimation on opacity {
            running: icon.running && moon.visible
            loops: Animation.Infinite
            NumberAnimation { to: 0.65; duration: 1400; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
        }
    }

    // --- Cloud (everything except clear) ---
    Item {
        id: cloud
        visible: icon.handDrawn && icon.condition !== "clear"
        width: icon.s * (icon.precip ? 0.8 : (icon.condition === "partly" ? 0.72 : 0.84))
        height: width * 0.62
        x: icon.condition === "partly" ? icon.s * 0.28
           : icon.precip ? icon.s * 0.1 : (icon.width - width) / 2
        y: icon.condition === "partly" ? icon.s * 0.34
           : icon.precip ? icon.s * 0.1
           : icon.condition === "fog" ? icon.s * 0.16 : (icon.height - height) / 2

        property real dx: 0
        transform: Translate { x: cloud.dx }
        SequentialAnimation on dx {
            running: icon.running && cloud.visible
            loops: Animation.Infinite
            NumberAnimation { to: icon.s * 0.04; duration: 2200; easing.type: Easing.InOutSine }
            NumberAnimation { to: -icon.s * 0.04; duration: 2200; easing.type: Easing.InOutSine }
        }

        Canvas {
            id: cloudArt
            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject
            renderStrategy: Canvas.Threaded
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections {
                target: icon
                function onCloudTopChanged() { cloudArt.requestPaint() }
                function onCloudBottomChanged() { cloudArt.requestPaint() }
            }
            onPaint: {
                var ctx = getContext("2d")
                var w = width, h = height
                ctx.clearRect(0, 0, w, h)
                var fill
                if (Qt.colorEqual(icon.cloudTop, icon.cloudBottom)) {
                    fill = icon.cloudTop
                } else {
                    fill = ctx.createLinearGradient(0, 0, 0, h)
                    fill.addColorStop(0, icon.cloudTop)
                    fill.addColorStop(1, icon.cloudBottom)
                }
                ctx.fillStyle = fill
                // base pill
                var y0 = h * 0.4, bh = h * 0.6, r = bh / 2
                ctx.beginPath()
                ctx.moveTo(r, y0)
                ctx.lineTo(w - r, y0)
                ctx.arc(w - r, y0 + r, r, -Math.PI / 2, Math.PI / 2)
                ctx.lineTo(r, y0 + bh)
                ctx.arc(r, y0 + r, r, Math.PI / 2, Math.PI * 1.5)
                ctx.closePath()
                ctx.fill()
                // two cumulus bumps
                ctx.beginPath()
                ctx.arc(w * 0.14 + w * 0.225, h * 0.14 + w * 0.225, w * 0.225, 0, Math.PI * 2)
                ctx.fill()
                ctx.beginPath()
                ctx.arc(w * 0.4 + w * 0.25, w * 0.25, w * 0.25, 0, Math.PI * 2)
                ctx.fill()
            }
        }
    }

    // --- Fog lines ---
    Repeater {
        model: icon.handDrawn && icon.condition === "fog" ? 3 : 0
        Rectangle {
            x: icon.s * (0.18 + 0.08 * (index % 2))
            y: icon.s * (0.62 + 0.12 * index)
            width: icon.s * 0.6
            height: icon.s * 0.06
            radius: height / 2
            color: "#B0BEC5"
            SequentialAnimation on opacity {
                running: icon.running
                loops: Animation.Infinite
                PauseAnimation { duration: index * 250 }
                NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
            }
        }
    }

    // --- Rain (slanted neon streaks) ---
    Repeater {
        model: !icon.handDrawn ? 0 : icon.condition === "rain" ? 3 : icon.thunder ? 2 : 0
        Particle {
            baseX: icon.thunder ? icon.s * (0.2 + 0.56 * index) : icon.s * (0.28 + 0.2 * index)
            restY: icon.s * (0.7 + 0.04 * (index % 2))
            fromY: icon.s * 0.6
            toY: icon.s * 0.95
            delay: index * 220
            duration: 750
            width: icon.s * 0.06
            height: icon.s * 0.16
            radius: width / 2
            rotation: 20
            color: "#4FC3F7"
        }
    }

    // --- Snow ---
    Repeater {
        model: icon.handDrawn && icon.condition === "snow" ? 3 : 0
        Particle {
            baseX: icon.s * (0.28 + 0.2 * index)
            restY: icon.s * (0.72 + 0.05 * (index % 2))
            fromY: icon.s * 0.6
            toY: icon.s * 0.93
            sway: icon.s * 0.04
            delay: index * 450
            duration: 1800
            width: icon.s * 0.09
            height: width
            radius: width / 2
            color: "#ffffff"
            border.color: "#b3d4f0"
            border.width: 1
        }
    }

    // --- Lightning ---
    Canvas {
        id: bolt
        visible: icon.handDrawn && icon.condition === "thunder"
        x: icon.s * 0.38; y: icon.s * 0.5
        width: icon.s * 0.26; height: icon.s * 0.46
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Threaded
        onWidthChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = "#ffd54f"
            ctx.beginPath()
            ctx.moveTo(width * 0.65, 0)
            ctx.lineTo(0, height * 0.58)
            ctx.lineTo(width * 0.45, height * 0.58)
            ctx.lineTo(width * 0.25, height)
            ctx.lineTo(width, height * 0.38)
            ctx.lineTo(width * 0.55, height * 0.38)
            ctx.closePath()
            ctx.fill()
        }
        SequentialAnimation on opacity {
            id: flash
            running: icon.running && bolt.visible
            loops: Animation.Infinite
            PauseAnimation { duration: 1100 }
            NumberAnimation { to: 0.15; duration: 60 }
            NumberAnimation { to: 1.0; duration: 60 }
            NumberAnimation { to: 0.2; duration: 60 }
            NumberAnimation { to: 1.0; duration: 120 }
            onRunningChanged: if (!running) bolt.opacity = 1
        }
    }

    // =====================================================================
    // glass3d: layered, lit artwork on a Canvas + backing light + float
    // =====================================================================
    readonly property color glowColor: condition === "thunder" ? "#7E57C2"
        : condition === "rain" ? "#4FC3F7"
        : condition === "snow" ? "#90CAF9"
        : condition === "fog" ? "#90A4AE"
        : isDay ? "#FFB300" : "#CE93D8"
    property real floatY: 0

    // Backing light: soft radial glow that breathes while the icon is active.
    Shape {
        id: backLight
        visible: icon.glass
        anchors.centerIn: parent
        width: icon.s * 1.3
        height: width
        preferredRendererType: Shape.CurveRenderer
        opacity: 0.14
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: backLight.width / 2; centerY: backLight.height / 2
                focalX: centerX; focalY: centerY
                centerRadius: backLight.width / 2
                GradientStop { position: 0.0; color: icon.glowColor }
                GradientStop { position: 0.55; color: Qt.rgba(icon.glowColor.r, icon.glowColor.g, icon.glowColor.b, 0.35) }
                GradientStop { position: 1.0; color: "transparent" }
            }
            PathAngleArc {
                centerX: backLight.width / 2; centerY: backLight.height / 2
                radiusX: backLight.width / 2; radiusY: backLight.height / 2
                sweepAngle: 360
            }
        }
        SequentialAnimation on opacity {
            running: icon.running && icon.glass
            loops: Animation.Infinite
            NumberAnimation { to: 0.38; duration: 2000; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.14; duration: 2000; easing.type: Easing.InOutSine }
            onRunningChanged: if (!running) backLight.opacity = 0.14
        }
    }

    // Idle float: 2px vertical drift while active.
    SequentialAnimation on floatY {
        running: icon.running && icon.glass
        loops: Animation.Infinite
        NumberAnimation { to: -2; duration: 2000; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 2000; easing.type: Easing.InOutSine }
        onRunningChanged: if (!running) icon.floatY = 0
    }

    Canvas {
        id: glassArt
        visible: icon.glass
        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Threaded
        transform: Translate { y: icon.floatY }
        // Canvas allocates its texture at the window's device pixel ratio, so
        // the art stays crisp at 18, 32 and 48px on HiDPI screens.
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: icon
            function onConditionChanged() { glassArt.requestPaint() }
            function onIsDayChanged() { glassArt.requestPaint() }
            function onGlassChanged() { glassArt.requestPaint() }
        }

        function cloudBox(s) {
            var c = icon.condition
            var w = s * (icon.precip ? 0.8 : (c === "partly" ? 0.72 : 0.84))
            var h = w * 0.62
            var x = c === "partly" ? s * 0.28 : icon.precip ? s * 0.1 : (s - w) / 2
            var y = c === "partly" ? s * 0.34 : icon.precip ? s * 0.1 : c === "fog" ? s * 0.16 : (s - h) / 2
            return { x: x, y: y, w: w, h: h }
        }
        // One clockwise path: base pill + two cumulus bumps (nonzero fill = union).
        function cloudPath(ctx, b) {
            var y0 = b.y + b.h * 0.4, bh = b.h * 0.6, r = bh / 2
            ctx.beginPath()
            ctx.moveTo(b.x + r, y0)
            ctx.lineTo(b.x + b.w - r, y0)
            ctx.arc(b.x + b.w - r, y0 + r, r, -Math.PI / 2, Math.PI / 2, false)
            ctx.lineTo(b.x + r, y0 + bh)
            ctx.arc(b.x + r, y0 + r, r, Math.PI / 2, Math.PI * 1.5, false)
            ctx.closePath()
            ctx.moveTo(b.x + b.w * 0.14 + b.w * 0.45, b.y + b.h * 0.14 + b.w * 0.225)
            ctx.arc(b.x + b.w * 0.14 + b.w * 0.225, b.y + b.h * 0.14 + b.w * 0.225, b.w * 0.225, 0, Math.PI * 2, false)
            ctx.closePath()
            ctx.moveTo(b.x + b.w * 0.4 + b.w * 0.5, b.y + b.w * 0.25)
            ctx.arc(b.x + b.w * 0.4 + b.w * 0.25, b.y + b.w * 0.25, b.w * 0.25, 0, Math.PI * 2, false)
            ctx.closePath()
        }
        function noShadow(ctx) { ctx.shadowBlur = 0; ctx.shadowColor = "transparent" }
        function star(ctx, cx, cy, r) {
            ctx.beginPath()
            for (var i = 0; i < 8; i++) {
                var a = i * Math.PI / 4
                var rr = (i % 2 === 0) ? r : r * 0.35
                var px = cx + Math.cos(a) * rr, py = cy + Math.sin(a) * rr
                if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py)
            }
            ctx.closePath()
            ctx.fill()
        }

        function drawSun(ctx, s, full) {
            var cx = full ? s / 2 : s * 0.3, cy = full ? s / 2 : s * 0.28
            var r = full ? s * 0.3 : s * 0.2
            // amber halo, kept inside the icon bounds so it fades out instead of being clipped
            var hr = Math.min(r * 2.1, cx, cy, s - cx, s - cy)
            var halo = ctx.createRadialGradient(cx, cy, r * 0.7, cx, cy, hr)
            halo.addColorStop(0, "rgba(255,179,0,0.55)")
            halo.addColorStop(0.55, "rgba(255,179,0,0.18)")
            halo.addColorStop(1, "rgba(255,179,0,0)")
            ctx.fillStyle = halo
            ctx.beginPath(); ctx.arc(cx, cy, hr, 0, Math.PI * 2); ctx.fill()
            // golden orb, lit from the top-left
            var orb = ctx.createRadialGradient(cx - r * 0.35, cy - r * 0.35, r * 0.05, cx, cy, r)
            orb.addColorStop(0, "#FFF8E1")
            orb.addColorStop(0.35, "#FFD54F")
            orb.addColorStop(0.8, "#FFB300")
            orb.addColorStop(1, "#F57C00")
            ctx.shadowColor = "rgba(255,179,0,0.9)"; ctx.shadowBlur = s * 0.1
            ctx.fillStyle = orb
            ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.fill()
            noShadow(ctx)
        }
        function drawMoon(ctx, s, full) {
            var ms = s * (full ? 0.72 : 0.5)
            var mx = full ? (s - ms) / 2 : s * 0.06, my = full ? (s - ms) / 2 : s * 0.06
            var g = ctx.createLinearGradient(mx, my, mx + ms, my + ms)
            g.addColorStop(0, "#F3E5F5")
            g.addColorStop(0.35, "#CE93D8")
            g.addColorStop(1, "#8E24AA")
            ctx.shadowColor = "rgba(206,147,216,0.85)"; ctx.shadowBlur = s * 0.12
            ctx.fillStyle = g
            ctx.beginPath(); ctx.arc(mx + ms / 2, my + ms / 2, ms * 0.46, 0, Math.PI * 2); ctx.fill()
            noShadow(ctx)
            ctx.globalCompositeOperation = "destination-out"
            ctx.beginPath(); ctx.arc(mx + ms * 0.68, my + ms * 0.38, ms * 0.38, 0, Math.PI * 2); ctx.fill()
            ctx.globalCompositeOperation = "source-over"
            // glowing accent stars
            ctx.fillStyle = "#FFFFFF"
            ctx.shadowColor = "rgba(255,255,255,0.95)"; ctx.shadowBlur = s * 0.07
            star(ctx, mx + ms * 0.80, my + ms * 0.24, ms * 0.11)
            star(ctx, mx + ms * 0.98, my + ms * 0.50, ms * 0.07)
            noShadow(ctx)
        }
        function drawCloud(ctx, s) {
            var b = cloudBox(s)
            var thunder = icon.condition === "thunder", fog = icon.condition === "fog"
            var g = ctx.createLinearGradient(0, b.y, 0, b.y + b.h)
            if (thunder) {
                g.addColorStop(0, "#9FA8DA"); g.addColorStop(0.45, "#5E35B1"); g.addColorStop(1, "#2A1B5E")
                ctx.shadowColor = "rgba(149,117,205,0.9)"
            } else {
                g.addColorStop(0, "#FFFFFF"); g.addColorStop(0.5, "#EAF1F8"); g.addColorStop(1, fog ? "#AEBBC9" : "#9DB4D3")
                ctx.shadowColor = "rgba(144,202,249,0.8)"
            }
            ctx.shadowBlur = s * 0.12
            ctx.fillStyle = g
            cloudPath(ctx, b)
            ctx.fill()
            noShadow(ctx)
            // frosted highlight on the upper-left mass
            ctx.save()
            cloudPath(ctx, b)
            ctx.clip()
            var hl = ctx.createRadialGradient(b.x + b.w * 0.32, b.y + b.h * 0.3, 0, b.x + b.w * 0.32, b.y + b.h * 0.3, b.w * 0.5)
            hl.addColorStop(0, thunder ? "rgba(255,255,255,0.35)" : "rgba(255,255,255,0.95)")
            hl.addColorStop(1, "rgba(255,255,255,0)")
            ctx.fillStyle = hl
            ctx.fillRect(b.x, b.y, b.w, b.h)
            // cool rim light along the bottom edge
            var rim = ctx.createLinearGradient(0, b.y + b.h * 0.7, 0, b.y + b.h)
            rim.addColorStop(0, "rgba(79,195,247,0)")
            rim.addColorStop(1, thunder ? "rgba(126,87,194,0.6)" : "rgba(79,195,247,0.35)")
            ctx.fillStyle = rim
            ctx.fillRect(b.x, b.y + b.h * 0.7, b.w, b.h * 0.3)
            ctx.restore()
        }
        function neonLine(ctx, x1, y1, x2, y2, w, color, glow) {
            ctx.lineCap = "round"
            ctx.shadowColor = glow; ctx.shadowBlur = s * 0.1
            ctx.strokeStyle = color; ctx.lineWidth = w
            ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke()
            noShadow(ctx)
            ctx.strokeStyle = "rgba(255,255,255,0.85)"; ctx.lineWidth = w * 0.35
            ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke()
        }
        function drawRain(ctx, s, xs) {
            var dx = s * 0.055   // slant
            for (var i = 0; i < xs.length; i++) {
                var x = s * xs[i], y = s * (0.66 + 0.04 * (i % 2))
                neonLine(ctx, x + dx, y, x - dx, y + s * 0.2, s * 0.065, "#4FC3F7", "rgba(79,195,247,0.95)")
            }
        }
        function drawSnow(ctx, s) {
            for (var i = 0; i < 3; i++) {
                var x = s * (0.28 + 0.2 * i), y = s * (0.76 + 0.05 * (i % 2))
                ctx.shadowColor = "rgba(179,229,252,0.95)"; ctx.shadowBlur = s * 0.08
                ctx.fillStyle = "#FFFFFF"
                ctx.beginPath(); ctx.arc(x, y, s * 0.05, 0, Math.PI * 2); ctx.fill()
            }
            noShadow(ctx)
        }
        function drawFog(ctx, s) {
            for (var i = 0; i < 3; i++) {
                var x = s * (0.18 + 0.08 * (i % 2)), y = s * (0.66 + 0.12 * i)
                var g = ctx.createLinearGradient(x, 0, x + s * 0.6, 0)
                g.addColorStop(0, "#FFFFFF"); g.addColorStop(1, "#AEBBC9")
                ctx.lineCap = "round"; ctx.lineWidth = s * 0.06
                ctx.shadowColor = "rgba(144,202,249,0.7)"; ctx.shadowBlur = s * 0.08
                ctx.strokeStyle = g
                ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x + s * 0.6, y); ctx.stroke()
            }
            noShadow(ctx)
        }
        function drawBolt(ctx, s) {
            var x = s * 0.38, y = s * 0.5, w = s * 0.26, h = s * 0.46
            var g = ctx.createLinearGradient(0, y, 0, y + h)
            g.addColorStop(0, "#FFFFFF"); g.addColorStop(0.45, "#FFF176"); g.addColorStop(1, "#FFD600")
            ctx.shadowColor = "rgba(255,235,59,0.95)"; ctx.shadowBlur = s * 0.14
            ctx.fillStyle = g
            ctx.beginPath()
            ctx.moveTo(x + w * 0.65, y)
            ctx.lineTo(x, y + h * 0.58)
            ctx.lineTo(x + w * 0.45, y + h * 0.58)
            ctx.lineTo(x + w * 0.25, y + h)
            ctx.lineTo(x + w, y + h * 0.38)
            ctx.lineTo(x + w * 0.55, y + h * 0.38)
            ctx.closePath()
            ctx.fill()
            ctx.fill()   // second pass deepens the glow
            noShadow(ctx)
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.save()
            ctx.setTransform(1, 0, 0, 1, 0, 0)
            ctx.globalCompositeOperation = "source-over"
            ctx.fillRule = Qt.WindingFill   // Qt's Canvas defaults to odd-even; the cloud path relies on nonzero union
            ctx.clearRect(0, 0, width, height)
            if (!icon.glass) { ctx.restore(); return }
            var s = icon.s
            ctx.translate((width - s) / 2, (height - s) / 2)
            if (icon.dense) {   // small boxes: scale the art up around the centre so it fills the cell
                ctx.translate(s / 2, s / 2); ctx.scale(icon.denseScale, icon.denseScale); ctx.translate(-s / 2, -s / 2)
            }
            var c = icon.condition
            if (c === "clear" || c === "partly") {
                if (icon.isDay) drawSun(ctx, s, c === "clear"); else drawMoon(ctx, s, c === "clear")
            }
            if (c !== "clear") drawCloud(ctx, s)
            if (c === "fog") drawFog(ctx, s)
            if (c === "rain") drawRain(ctx, s, [0.28, 0.48, 0.68])
            if (c === "snow") drawSnow(ctx, s)
            if (c === "thunder") { drawRain(ctx, s, [0.2, 0.78]); drawBolt(ctx, s) }
            ctx.restore()
        }
    }

    // =====================================================================
    // wireframe: Sub-Etha CRT vector art on a Canvas. Clean unshaded outlines
    // in the theme's outline / sun / precip colours, thin strokes, no fills
    // except tiny dots; a ~22 fps clock drives the motion while `running`.
    // With palette.solid the same geometry becomes a print graphic: white
    // cloud, filled sun and moon, slightly heavier rain and snow.
    // =====================================================================
    Canvas {
        id: wireArt
        visible: icon.wire
        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Threaded
        property real t: 0          // animation clock, seconds
        readonly property bool solid: icon.palette.solid === true
        // Static tables, hoisted so a frame allocates nothing.
        readonly property var rainXs: [0.28, 0.48, 0.68]
        readonly property var thunderXs: [0.2, 0.78]
        readonly property var rainAlpha: [1, 1, 0.75, 0.4]
        readonly property var moonStars: [[0.80, 0.24, 0.11, 0], [0.98, 0.42, 0.075, 2.1]]
        readonly property var boltDense: [[0.72, 0], [0.25, 0.45], [0.65, 0.43], [0.28, 1]]
        readonly property var boltFull: [[0.72, 0], [0.36, 0.32], [0.66, 0.32], [0.28, 0.68], [0.56, 0.66], [0.3, 1]]
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: icon
            function onConditionChanged() { wireArt.requestPaint() }
            function onIsDayChanged() { wireArt.requestPaint() }
            function onWireChanged() { wireArt.requestPaint() }
            function onRunningChanged() { wireArt.requestPaint() }   // rest pose when stopped
        }
        Timer {
            interval: 45; repeat: true
            running: icon.wire && icon.running && wireArt.visible
            onTriggered: { wireArt.t += 0.045; wireArt.requestPaint() }
        }

        // ~1.5px at 32, 2.2px at 48; boxes under 30px get a fixed 1.3px so the lines stay legible
        function lw() { return icon.dense ? 1.3 : Math.max(1, icon.s * 0.045) }
        // precipitation strokes: a touch heavier in the solid print variant
        function plw() { return solid ? lw() * 1.3 : lw() }
        function circ(cx, cy, r) { return { cx: cx, cy: cy, r: r } }
        function inside(c, x, y) { var dx = x - c.cx, dy = y - c.cy; return dx * dx + dy * dy < c.r * c.r - 1e-6 }
        // Both intersection points of two overlapping circles.
        function isect(a, b) {
            var dx = b.cx - a.cx, dy = b.cy - a.cy, d = Math.sqrt(dx * dx + dy * dy)
            var l = (a.r * a.r - b.r * b.r + d * d) / (2 * d)
            var h = Math.sqrt(Math.max(0, a.r * a.r - l * l))
            var px = a.cx + l * dx / d, py = a.cy + l * dy / d
            return [{ x: px + h * dy / d, y: py - h * dx / d }, { x: px - h * dy / d, y: py + h * dx / d }]
        }
        function farther(pts, x, y) {
            var d0 = Math.pow(pts[0].x - x, 2) + Math.pow(pts[0].y - y, 2)
            var d1 = Math.pow(pts[1].x - x, 2) + Math.pow(pts[1].y - y, 2)
            return d0 >= d1 ? pts[0] : pts[1]
        }
        // Arc of circle c from point p to point q, taking whichever of the two
        // directions has its midpoint accepted by keep(x, y).
        function arcPick(ctx, c, p, q, keep) {
            var a0 = Math.atan2(p.y - c.cy, p.x - c.cx), a1 = Math.atan2(q.y - c.cy, q.x - c.cx)
            var cw = a1
            while (cw < a0) cw += Math.PI * 2
            var mid = (a0 + cw) / 2
            if (keep(c.cx + Math.cos(mid) * c.r, c.cy + Math.sin(mid) * c.r))
                ctx.arc(c.cx, c.cy, c.r, a0, cw, false)
            else {
                var ccw = a1
                while (ccw > a0) ccw -= Math.PI * 2
                ctx.arc(c.cx, c.cy, c.r, a0, ccw, true)
            }
        }
        function line(ctx, x1, y1, x2, y2) { ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke() }

        // Same bounding box as the other styles, plus a slow drift while running.
        function cloudBox(s) {
            var b = glassArt.cloudBox(s)
            if (icon.running) b.x += Math.sin(t * Math.PI * 2 / 4.4) * s * 0.025
            return b
        }
        // The pill and two cumulus circles that make up the cloud silhouette.
        function cloudCircles(b) {
            var r = b.h * 0.3, cy = b.y + b.h * 0.7
            return {
                L: circ(b.x + r, cy, r), R: circ(b.x + b.w - r, cy, r),
                B1: circ(b.x + b.w * 0.365, b.y + b.h * 0.14 + b.w * 0.225, b.w * 0.225),
                B2: circ(b.x + b.w * 0.65, b.y + b.w * 0.25, b.w * 0.25),
                rect: { x0: b.x + r, x1: b.x + b.w - r, y0: b.y + b.h * 0.4, y1: b.y + b.h }
            }
        }
        // The outline of the union: base line, right pill arc, two bumps, left pill arc.
        // `open` leaves the base out (fog replaces it with a dashed line).
        function cloudOutline(ctx, b, open) {
            var k = cloudCircles(b)
            var cx = b.x + b.w / 2, cy = b.y + b.h * 0.6
            var p1 = farther(isect(k.R, k.B2), cx, cy)
            var p2 = farther(isect(k.B2, k.B1), cx, cy)
            var p3 = farther(isect(k.B1, k.L), cx, cy)
            var bl = { x: k.L.cx, y: b.y + b.h }, br = { x: k.R.cx, y: b.y + b.h }
            function hidden(x, y, except) {   // point lies inside another part of the silhouette
                if (x > k.rect.x0 && x < k.rect.x1 && y > k.rect.y0 && y < k.rect.y1) return true
                var parts = [k.L, k.R, k.B1, k.B2]
                for (var i = 0; i < parts.length; i++)
                    if (parts[i] !== except && inside(parts[i], x, y)) return true
                return false
            }
            ctx.beginPath()
            if (open) ctx.moveTo(br.x, br.y); else { ctx.moveTo(bl.x, bl.y); ctx.lineTo(br.x, br.y) }
            arcPick(ctx, k.R, br, p1, function (x, y) { return !hidden(x, y, k.R) })
            arcPick(ctx, k.B2, p1, p2, function (x, y) { return !hidden(x, y, k.B2) })
            arcPick(ctx, k.B1, p2, p3, function (x, y) { return !hidden(x, y, k.B1) })
            arcPick(ctx, k.L, p3, bl, function (x, y) { return !hidden(x, y, k.L) })
            if (!open) ctx.closePath()
        }
        function drawCloud(ctx, s) {
            var b = cloudBox(s), fog = icon.condition === "fog"
            // cut the interior out of whatever was drawn behind (sun, moon, stars)
            ctx.globalCompositeOperation = "destination-out"
            cloudOutline(ctx, b, false)
            ctx.fill()
            ctx.globalCompositeOperation = "source-over"
            if (solid) {   // print graphic: white body under the ink outline
                ctx.fillStyle = "#FFFFFF"
                cloudOutline(ctx, b, false)
                ctx.fill()
            }
            ctx.strokeStyle = icon.palette.outline
            ctx.lineWidth = lw()
            cloudOutline(ctx, b, fog)
            ctx.stroke()
        }

        function drawSun(ctx, s, full) {
            var cx = full ? s / 2 : s * 0.3, cy = full ? s / 2 : s * 0.28
            var r = full ? s * 0.19 : s * 0.125
            var pulse = icon.running ? 1 + 0.06 * Math.sin(t * Math.PI * 2 / 1.8) : 1
            var rot = icon.running ? t * Math.PI * 2 / 14 : 0
            ctx.strokeStyle = icon.palette.sun
            ctx.lineWidth = lw()
            ctx.beginPath(); ctx.arc(cx, cy, r * pulse, 0, Math.PI * 2)
            if (solid) { ctx.fillStyle = icon.palette.sun; ctx.fill() }
            ctx.stroke()
            // 8 dashed spikes: two short dashes along each ray (one in tiny boxes)
            var r0 = r * 1.35, r1 = r * 1.65, r2 = r * 1.85, r3 = r * 2.15
            ctx.beginPath()
            for (var i = 0; i < 8; i++) {
                var a = rot + i * Math.PI / 4, ca = Math.cos(a), sa = Math.sin(a)
                if (icon.dense) {
                    ctx.moveTo(cx + ca * r0, cy + sa * r0); ctx.lineTo(cx + ca * r3, cy + sa * r3)
                } else {
                    ctx.moveTo(cx + ca * r0, cy + sa * r0); ctx.lineTo(cx + ca * r1, cy + sa * r1)
                    ctx.moveTo(cx + ca * r2, cy + sa * r2); ctx.lineTo(cx + ca * r3, cy + sa * r3)
                }
            }
            ctx.stroke()
        }
        function drawMoon(ctx, s, full) {
            var ms = s * (full ? 0.72 : 0.5)
            var mx = full ? (s - ms) / 2 : s * 0.06, my = full ? (s - ms) / 2 : s * 0.06
            var C = circ(mx + ms / 2, my + ms / 2, ms * 0.46)
            var K = circ(mx + ms * 0.68, my + ms * 0.38, ms * 0.38)
            var pts = isect(C, K)
            ctx.strokeStyle = icon.palette.outline
            ctx.lineWidth = lw()
            ctx.beginPath()
            ctx.moveTo(pts[0].x, pts[0].y)
            arcPick(ctx, C, pts[0], pts[1], function (x, y) { return !inside(K, x, y) })   // outer limb
            arcPick(ctx, K, pts[1], pts[0], function (x, y) { return inside(C, x, y) })    // inner limb
            ctx.closePath()
            if (solid) { ctx.fillStyle = icon.palette.sun; ctx.fill() }
            ctx.stroke()
            // two tiny crosshair stars that twinkle
            ctx.strokeStyle = icon.palette.sun
            var stars = moonStars
            for (var i = 0; i < stars.length; i++) {
                var sx = mx + ms * stars[i][0], sy = my + ms * stars[i][1]
                var sr = Math.max(1.2, ms * stars[i][2])
                ctx.globalAlpha = icon.running ? 0.45 + 0.55 * (0.5 + 0.5 * Math.sin(t * Math.PI * 2 / 1.3 + stars[i][3])) : 1
                ctx.beginPath()
                ctx.moveTo(sx - sr, sy); ctx.lineTo(sx + sr, sy)
                ctx.moveTo(sx, sy - sr); ctx.lineTo(sx, sy + sr)
                ctx.stroke()
            }
            ctx.globalAlpha = 1
        }
        function drawRain(ctx, s, xs) {
            var dx = s * 0.035, len = s * 0.12
            ctx.strokeStyle = icon.palette.precip
            ctx.lineWidth = plw()
            for (var i = 0; i < xs.length; i++) {
                var x = s * xs[i], y, a = 1
                if (icon.running) {   // "digital" fall: four discrete positions per cycle, staggered
                    var ph = ((t / 0.9) + i * 0.33) % 1
                    var step = Math.floor(ph * 4)
                    y = s * (0.62 + step * 0.06)
                    a = rainAlpha[step]
                } else {
                    y = s * (0.66 + 0.04 * (i % 2))
                }
                ctx.globalAlpha = a
                line(ctx, x + dx, y, x - dx, y + len)
            }
            ctx.globalAlpha = 1
        }
        function drawSnow(ctx, s) {
            var r = Math.max(1.5, s * 0.06)
            ctx.strokeStyle = icon.palette.precip
            ctx.lineWidth = Math.max(1, plw() * 0.8)
            for (var i = 0; i < 3; i++) {
                var x = s * (0.28 + 0.2 * i), y, a = 1
                if (icon.running) {
                    var ph = ((t / 2.4) + i * 0.37) % 1
                    y = s * (0.62 + ph * 0.26)
                    x += Math.sin(ph * Math.PI * 2 + i) * s * 0.03
                    a = ph < 0.15 ? ph / 0.15 : ph > 0.8 ? (1 - ph) / 0.2 : 1
                } else {
                    y = s * (0.76 + 0.05 * (i % 2))
                }
                ctx.globalAlpha = a
                ctx.beginPath()
                for (var k = 0; k < 3; k++) {   // 6-spoke asterisk
                    var an = k * Math.PI / 3
                    ctx.moveTo(x - Math.cos(an) * r, y - Math.sin(an) * r)
                    ctx.lineTo(x + Math.cos(an) * r, y + Math.sin(an) * r)
                }
                ctx.stroke()
            }
            ctx.globalAlpha = 1
        }
        function drawFog(ctx, s) {
            var dash = s * 0.1, gap = s * 0.05
            ctx.strokeStyle = icon.palette.outline
            ctx.lineWidth = lw()
            for (var i = 0; i < 3; i++) {
                var x0 = s * (0.18 + 0.08 * (i % 2)), x1 = x0 + s * 0.6, y = s * (0.68 + 0.1 * i)
                ctx.globalAlpha = icon.running ? 0.7 * (0.55 + 0.45 * Math.sin(t * Math.PI * 2 / 1.8 + i * 2.1)) : 0.7
                ctx.beginPath()
                for (var x = x0; x < x1; x += dash + gap) { ctx.moveTo(x, y); ctx.lineTo(Math.min(x + dash, x1), y) }
                ctx.stroke()
            }
            ctx.globalAlpha = 1
        }
        function drawBolt(ctx, s) {
            var x = s * 0.38, y = s * 0.5, w = s * 0.26, h = s * 0.42
            var pts = icon.dense ? boltDense : boltFull
            var a = 1
            if (icon.running) {   // flicker burst every 1.1 s
                var tc = t % 1.1
                a = tc < 0.06 ? 0.2 : tc < 0.12 ? 1 : tc < 0.18 ? 0.3 : 1
            }
            ctx.globalAlpha = a
            function path() {
                ctx.beginPath()
                for (var i = 0; i < pts.length; i++) {
                    var px = x + w * pts[i][0], py = y + h * pts[i][1]
                    if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py)
                }
            }
            ctx.strokeStyle = icon.palette.bolt; ctx.lineWidth = lw(); path(); ctx.stroke()
            ctx.strokeStyle = icon.palette.boltCore; ctx.lineWidth = Math.max(0.6, lw() * 0.4); path(); ctx.stroke()
            ctx.globalAlpha = 1
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.save()
            ctx.setTransform(1, 0, 0, 1, 0, 0)
            ctx.globalCompositeOperation = "source-over"
            ctx.globalAlpha = 1
            ctx.clearRect(0, 0, width, height)
            if (!icon.wire) { ctx.restore(); return }
            var s = icon.s
            ctx.translate((width - s) / 2, (height - s) / 2)
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            var c = icon.condition
            if (c === "clear" || c === "partly") {
                if (icon.isDay) drawSun(ctx, s, c === "clear"); else drawMoon(ctx, s, c === "clear")
            }
            if (c !== "clear") drawCloud(ctx, s)
            if (c === "fog") drawFog(ctx, s)
            if (c === "rain") drawRain(ctx, s, rainXs)
            if (c === "snow") drawSnow(ctx, s)
            if (c === "thunder") { drawRain(ctx, s, thunderXs); drawBolt(ctx, s) }
            ctx.restore()
        }
    }

    // --- SVG icons (Weather Underground set) with simple motion ---
    onRunningChanged: if (!running) { motionX = 0; motionY = 0; motionFlash = 1; svgArt.scale = 1 }

    Item {
        id: svgArt
        visible: !icon.handDrawn && !icon.glass && !icon.wire
        width: icon.s
        height: icon.s
        anchors.centerIn: parent
        opacity: icon.motionFlash
        transform: Translate { x: icon.motionX; y: icon.motionY }

        Image {
            id: svgImage
            anchors.fill: parent
            source: (icon.handDrawn || icon.glass || icon.wire) ? "" : Qt.resolvedUrl("icons/" + icon.iconStyle + "/" + icon.svgName + ".svg")
            sourceSize: Qt.size(icon.s * 2, icon.s * 2)
            fillMode: Image.PreserveAspectFit
            smooth: true
            rotation: 0            // always upright, see svgMotion
        }

        // drift: gentle sway + bob (clouds, fog)
        SequentialAnimation {
            running: icon.running && icon.svgMotion === "drift" && svgArt.visible
            loops: Animation.Infinite
            ParallelAnimation {
                NumberAnimation { target: icon; property: "motionX"; to: icon.s * 0.05; duration: 1800; easing.type: Easing.InOutSine }
                NumberAnimation { target: icon; property: "motionY"; to: -icon.s * 0.03; duration: 1800; easing.type: Easing.InOutSine }
            }
            ParallelAnimation {
                NumberAnimation { target: icon; property: "motionX"; to: -icon.s * 0.05; duration: 1800; easing.type: Easing.InOutSine }
                NumberAnimation { target: icon; property: "motionY"; to: icon.s * 0.03; duration: 1800; easing.type: Easing.InOutSine }
            }
        }
        // fall: quick downward bobbing (rain, snow)
        SequentialAnimation {
            running: icon.running && icon.svgMotion === "fall" && svgArt.visible
            loops: Animation.Infinite
            NumberAnimation { target: icon; property: "motionY"; to: icon.s * 0.06; duration: 450; easing.type: Easing.InQuad }
            NumberAnimation { target: icon; property: "motionY"; to: -icon.s * 0.02; duration: 650; easing.type: Easing.OutQuad }
        }
        // flash: lightning flicker
        SequentialAnimation {
            running: icon.running && icon.svgMotion === "flash" && svgArt.visible
            loops: Animation.Infinite
            PauseAnimation { duration: 900 }
            NumberAnimation { target: icon; property: "motionFlash"; to: 0.3; duration: 60 }
            NumberAnimation { target: icon; property: "motionFlash"; to: 1.0; duration: 60 }
            NumberAnimation { target: icon; property: "motionFlash"; to: 0.4; duration: 60 }
            NumberAnimation { target: icon; property: "motionFlash"; to: 1.0; duration: 150 }
        }
        // glow: moon / sun pulse
        SequentialAnimation {
            running: icon.running && icon.svgMotion === "glow" && svgArt.visible
            loops: Animation.Infinite
            NumberAnimation { target: svgArt; property: "scale"; to: 1.08; duration: 1000; easing.type: Easing.InOutSine }
            NumberAnimation { target: svgArt; property: "scale"; to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
        }
    }
}
