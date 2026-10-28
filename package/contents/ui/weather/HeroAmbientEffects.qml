import QtQuick

// Retro CRT vector-graphics ambient weather for the hero card, after the Guide
// animations of the 1981 BBC "Hitchhiker's Guide to the Galaxy": thin glowing
// wireframe lines, crosshairs, oscilloscope traces and dotted trajectories on
// the flat near-black card, behind the text. One Canvas draws everything and a
// ~22 fps Timer repaints it only while `running`, so a hidden or paused card
// costs nothing. Positions are seeded once; nothing re-randomises per frame
// and the per-frame geometry lives in reused objects, so a frame allocates
// nothing but the occasional ripple or trail dot.
// Colours come from `palette`; with palette.light the ink lands on cream, so
// every stroke alpha is boosted by 1.4 and the thunder flash softens.
//
//   clear    "+" crosshair star coordinates blinking at their own phases, two
//            wireframe orbital rings turning in 3D around an amber marker and,
//            every 8..15 s, a satellite dot crossing the card on a shallow arc
//            behind a fading dotted trail. Night adds a wireframe crescent moon
//            in the upper right and brighter stars.
//   partly   two drifting cloud outlines plus a dashed amber sun peeking in at
//            the top left.
//   cloudy   three unshaded wireframe cloud outlines drifting left to right.
//   fog      four rows of horizontal dashes sliding and flickering.
//   rain     short cyan tick vectors falling, slanted by the wind, onto a
//            wireframe baseline with perpendicular ticks; each landing rings a
//            small expanding ellipse.
//   snow     small wireframe asterisks and diamonds drifting down with a sway.
//   thunder  rain, plus every 6..13 s a jagged forked vector bolt, a CRT screen
//            flash (amber then red) and an "[IMPROBABILITY SURGE]" telemetry
//            readout in the top left corner; `lightning()` fires with the flash.
//   wind     (>= 20 km/h, on top of any condition) flowing oscilloscope sine
//            traces whose speed follows the wind.
//   rain and thunder also carry an easter egg: every 60 s (first after ~20 s)
//            a tiny wireframe sperm whale and a bowl of petunias drift down in
//            the far background, behind the rain. A skin's `hazards` (one or
//            two images) tumble down in their place, every 35 s.
Item {
    id: fx

    property string condition: "cloudy"   // clear / partly / cloudy / fog / rain / snow / thunder
    property bool isNight: false
    property real windSpeed: 0            // km/h
    property bool running: true
    property real cornerRadius: 10
    property var hazards: []              // image URLs that replace the whale and the petunias

    // 0..1 strength of the wind, saturating at 50 km/h. Drives the rain tilt,
    // the trace speed and the sideways drift of everything that falls. Wind
    // blows left to right everywhere in the card (+x).
    readonly property real windFactor: Math.min(1.0, windSpeed / 50)
    readonly property bool windy: windSpeed >= 20
    signal lightning()

    visible: running
    clip: true

    // Colours for the vectors; the card passes its theme palette.
    override property var palette: ({ outline: "#00FF66", accent: "#FFB000", cool: "#00E5FF", danger: "#FF3333", light: false })
    // Dark ink on cream needs a little more weight than phosphor on black.
    readonly property real alphaBoost: palette.light ? 1.4 : 1
    onPaletteChanged: if (running && cv.available) cv.requestPaint()

    // Animation clock in seconds of running time; a pause does not advance it,
    // so nothing bursts to catch up when the card comes back.
    property real t: 0
    property real lastMs: 0

    // Scene state, seeded once in seed(). Fractions of the card size unless
    // noted, so a resize keeps every item in place.
    property var stars: []
    property var rings: []
    property var sat: ({})
    property var clouds: []
    property var fogRows: []
    property var drops: []
    property var ripples: []
    property var flakes: []
    property var traces: []
    property var bolt: ({})
    property var whale: ({})
    // Reused per-frame scratch objects (rain geometry, satellite position).
    readonly property var geom: ({ ang: 0, ux: 0, uy: 1, travel: 0, drift: 0, pLand: 1, rate: 1, len: 9 })
    readonly property var satP: ({ x: 0, y: 0 })

    function rnd(a, b) { return a + Math.random() * (b - a) }
    function mod(a, n) { return ((a % n) + n) % n }

    Component.onCompleted: seed()
    onConditionChanged: resetTransients()

    Canvas {
        id: cv
        anchors.fill: parent
        // Painted on the Canvas render thread, off the GUI thread. (Qt 6
        // ignores the FramebufferObject target and uses an Image texture.)
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Threaded
        onPaint: fx.draw(getContext("2d"))
    }

    // A skin's hazards on the whale's path: the first tumbling forward, the
    // second (smaller) spinning the other way a little behind it. They follow
    // the animation clock `t`, so they stop with it.
    Repeater {
        model: fx.hazards.length && (fx.condition === "rain" || fx.condition === "thunder") ? fx.hazards.slice(0, 2) : []
        Image {
            required property string modelData
            required property int index
            // reads the clock first: `whale` changes in place and notifies nothing
            readonly property real p: { var t = fx.t; return fx.whale.active ? (t - fx.whale.t0) / 7 : -1 }
            visible: p >= 0 && p <= 1
            source: modelData
            width: index ? 24 : 36; height: width
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            x: fx.whale.x0 * fx.width + p * fx.windFactor * 50 + index * 34 - width / 2
            y: -height + p * (fx.height + height * 2) - index * 16
            rotation: (fx.t - fx.whale.t0) * (index ? -150 : 95)
            opacity: fx.palette.light ? 0.75 : 0.85
        }
    }

    Timer {
        interval: 45
        repeat: true
        running: fx.running && fx.visible && cv.available && fx.width > 0 && fx.height > 0
        onRunningChanged: fx.lastMs = 0
        onTriggered: { fx.tick(); cv.requestPaint() }
    }

    function seed() {
        var i
        stars = []
        for (i = 0; i < 12; i++)
            stars.push({ x: rnd(0.03, 0.97), y: rnd(0.06, 0.92), r: 1.5 + (i % 3) * 0.5,
                         sp: rnd(0.7, 1.7), ph: rnd(0, 6.283), col: i % 5 === 4 ? "accent" : "outline" })   // palette keys
        rings = [ { rot: 0.45, rotA: 0.18, rotF: 0.21, tiltF: 0.37, tiltP: 0.0, a: 0.17 },
                  { rot: -0.65, rotA: 0.12, rotF: 0.17, tiltF: 0.29, tiltP: 2.2, a: 0.13 } ]
        sat = { active: false, next: rnd(4, 9), t0: 0, dur: 6, y0: 0.3, sag: 0.1, dir: 1, trail: [], lastDot: 0 }
        clouds = [ { y: 0.24, s: 1.0, bumps: [7, 12, 9], speed: 7, ph: 0.05 },
                   { y: 0.58, s: 0.8, bumps: [6, 9, 11, 7], speed: 9, ph: 0.5 },
                   { y: 0.84, s: 1.2, bumps: [8, 11, 8], speed: 5.5, ph: 0.78 } ]
        fogRows = [ { y: 0.18, speed: 9, dash: 16, gap: 10, f: 1.3, ph: 0.0 },
                    { y: 0.40, speed: -6, dash: 12, gap: 9, f: 1.7, ph: 1.9 },
                    { y: 0.62, speed: 7, dash: 18, gap: 12, f: 1.1, ph: 3.7 },
                    { y: 0.84, speed: -8, dash: 14, gap: 8, f: 1.5, ph: 5.1 } ]
        drops = []
        for (i = 0; i < 18; i++)
            drops.push({ x0: rnd(0, 1), sp: rnd(0.9, 1.3), ph: rnd(0, 1), landed: false })
        ripples = []
        flakes = []
        for (i = 0; i < 16; i++)
            flakes.push({ x: rnd(0.02, 0.98), sp: rnd(0.11, 0.2), ph: rnd(0, 1), swA: rnd(4, 9),
                          swF: rnd(0.5, 1.1), swP: rnd(0, 6.283), r: 1.5 + (i % 3) * 0.5,
                          star: i % 2 === 0, col: i % 3 === 0 ? "cool" : "outline" })
        traces = [ { y: 0.25, amp: 5, k: 70, ph: 0.0, shF: 2.1 },
                   { y: 0.52, amp: 7, k: 95, ph: 2.0, shF: 1.6 },
                   { y: 0.78, amp: 4, k: 60, ph: 4.1, shF: 2.6 } ]
        bolt = { next: rnd(3, 8), t0: -10, pts: [], forks: [] }
        whale = { next: 20, active: false, t0: 0, x0: 0.5 }
    }

    // A condition switch drops the one-shot items so nothing from the old
    // scene lingers over the new one.
    function resetTransients() {
        ripples = []
        if (bolt.pts) bolt.t0 = -10
        if (whale) whale.active = false
        if (sat.trail) { sat.active = false; sat.trail.length = 0 }
        if (running && cv.available) cv.requestPaint()
    }

    // ---- per-frame state (only the one-shot items need it; the rest is a pure function of t) ----
    function tick() {
        var now = Date.now()
        var dt = lastMs > 0 ? Math.min(0.1, (now - lastMs) / 1000) : 0.045
        lastMs = now
        t += dt
        var w = cv.width, h = cv.height
        if (condition === "clear") tickSatellite()
        else if (condition === "rain" || condition === "thunder") { tickRain(w, h); tickWhale() }
        if (condition === "thunder") tickThunder(w, h)
    }

    // Satellite position at progress p, written into the shared satP object.
    function satPos(p) {
        var s = sat, o = satP
        o.x = s.dir > 0 ? -0.03 + p * 1.06 : 1.03 - p * 1.06
        o.y = s.y0 + s.sag * Math.sin(p * Math.PI)
        return o
    }

    function tickSatellite() {
        var s = sat
        if (!s.active && t >= s.next) {
            s.active = true; s.t0 = t; s.dur = rnd(5, 7)
            s.y0 = rnd(0.15, 0.55); s.sag = rnd(-0.12, 0.12)
            s.dir = Math.random() < 0.5 ? 1 : -1
            s.lastDot = -1
        }
        if (s.active) {
            var p = (t - s.t0) / s.dur
            if (p >= 1) {
                s.active = false; s.next = t + rnd(8, 15)
            } else if (t - s.lastDot >= 0.1) {
                var pos = satPos(p)
                s.trail.push({ x: pos.x, y: pos.y, t0: t })
                s.lastDot = t
            }
        }
        while (s.trail.length && t - s.trail[0].t0 > 2.5) s.trail.shift()
    }

    // Rain geometry shared by tick and draw, written into the shared geom object.
    function rainGeom(w, h) {
        var g = geom
        var ang = windFactor * 38 * Math.PI / 180
        var travel = h + 20
        g.ang = ang; g.ux = Math.sin(ang); g.uy = Math.cos(ang); g.travel = travel
        g.drift = travel * Math.tan(ang); g.pLand = (h - 6 + 14) / travel
        g.rate = 1 + windFactor * 0.6; g.len = 9 + windFactor * 5
        return g
    }

    function tickRain(w, h) {
        var g = rainGeom(w, h)
        for (var i = 0; i < drops.length; i++) {
            var d = drops[i]
            var p = mod(t * d.sp * g.rate + d.ph, 1)
            if (p >= g.pLand) {
                if (!d.landed) {
                    d.landed = true
                    var xl = d.x0 * (w + g.drift) - g.drift + g.pLand * g.drift
                    if (xl >= 0 && xl <= w) ripples.push({ x: xl, t0: t })
                }
            } else {
                d.landed = false
            }
        }
        while (ripples.length && t - ripples[0].t0 > 0.4) ripples.shift()
    }

    function tickWhale() {
        var k = whale
        if (!k.active && t >= k.next) { k.active = true; k.t0 = t; k.x0 = rnd(0.2, 0.7); k.next = t + (hazards.length ? 35 : 60) }
        if (k.active && t - k.t0 > 7) k.active = false
    }

    function tickThunder(w, h) {
        var b = bolt
        if (t >= b.next) {
            makeBolt(w, h)
            b.t0 = t
            b.next = t + rnd(6, 13)
            fx.lightning()
        }
    }

    // A jagged polyline from the top edge to ~70% height with one or two forks.
    function makeBolt(w, h) {
        var n = 5 + Math.floor(rnd(0, 4))          // 5..8 segments
        var x = rnd(0.25, 0.75) * w, y = 0
        var pts = [{ x: x, y: y }]
        for (var i = 1; i <= n; i++) {
            x += (i % 2 ? 1 : -1) * rnd(0.03, 0.08) * w + rnd(-0.02, 0.02) * w
            y = (i / n) * 0.7 * h + (i < n ? rnd(-0.03, 0.03) * h : 0)
            pts.push({ x: x, y: y })
        }
        var forks = []
        var nf = Math.random() < 0.5 ? 1 : 2
        for (var f = 0; f < nf; f++) {
            var k = 1 + Math.floor(rnd(0, n - 2))
            var side = f % 2 ? -1 : 1
            var fp = [pts[k]]
            var fx0 = pts[k].x, fy0 = pts[k].y
            var m = 2 + Math.floor(rnd(0, 2))
            for (var j = 1; j <= m; j++) {
                fx0 += side * rnd(0.03, 0.06) * w
                fy0 += rnd(0.06, 0.12) * h
                fp.push({ x: fx0, y: fy0 })
            }
            forks.push(fp)
        }
        bolt.pts = pts
        bolt.forks = forks
    }

    // ---- drawing ----
    // Stroke colour, width and alpha; the alpha is scaled for light palettes.
    function setStroke(ctx, col, width, alpha) {
        ctx.strokeStyle = col
        ctx.lineWidth = width
        ctx.globalAlpha = Math.min(1, alpha * alphaBoost)
    }
    function setAlpha(ctx, alpha) { ctx.globalAlpha = Math.min(1, alpha * alphaBoost) }

    function cross(ctx, x, y, r) {
        ctx.moveTo(x - r, y); ctx.lineTo(x + r, y)
        ctx.moveTo(x, y - r); ctx.lineTo(x, y + r)
    }

    function ellipsePath(ctx, cx, cy, rx, ry, rot) {
        ctx.save()
        ctx.translate(cx, cy)
        ctx.rotate(rot)
        ctx.scale(1, ry / rx)
        ctx.beginPath()
        ctx.arc(0, 0, rx, 0, Math.PI * 2, false)
        ctx.restore()
    }

    function polyline(ctx, pts) {
        ctx.moveTo(pts[0].x, pts[0].y)
        for (var i = 1; i < pts.length; i++) ctx.lineTo(pts[i].x, pts[i].y)
    }

    // Dashes along a horizontal row, `offset` px of slide. With base > 0 each
    // dash flickers at its own alpha around `base`, seeded by its index and `row`.
    function dashedRow(ctx, y, w, dash, gap, offset, base, row) {
        var period = dash + gap
        var s = -mod(offset, period)
        for (var i = 0; s < w; s += period, i++) {
            var a = Math.max(0, s), b = Math.min(w, s + dash)
            if (b <= a) continue
            if (base > 0) {
                var k = Math.floor((s + offset) / period)
                setAlpha(ctx, base * (0.6 + 0.4 * (0.5 + 0.5 * Math.sin(t * 1.9 + k * 2.3 + row * 5.0))))
            }
            ctx.beginPath(); ctx.moveTo(a, y); ctx.lineTo(b, y); ctx.stroke()
        }
    }

    function dashedCircle(ctx, cx, cy, r, dashAng, gapAng, offset) {
        var period = dashAng + gapAng
        ctx.beginPath()
        for (var a = offset; a < offset + Math.PI * 2; a += period) {
            ctx.moveTo(cx + r * Math.cos(a), cy + r * Math.sin(a))
            ctx.arc(cx, cy, r, a, a + dashAng, false)
        }
        ctx.stroke()
    }

    function roundRectPath(ctx, x, y, w, h, r) {
        r = Math.min(r, w / 2, h / 2)
        ctx.beginPath()
        ctx.moveTo(x + r, y)
        ctx.lineTo(x + w - r, y); ctx.arc(x + w - r, y + r, r, -Math.PI / 2, 0, false)
        ctx.lineTo(x + w, y + h - r); ctx.arc(x + w - r, y + h - r, r, 0, Math.PI / 2, false)
        ctx.lineTo(x + r, y + h); ctx.arc(x + r, y + h - r, r, Math.PI / 2, Math.PI, false)
        ctx.lineTo(x, y + r); ctx.arc(x + r, y + r, r, Math.PI, Math.PI * 1.5, false)
        ctx.closePath()
    }

    function draw(ctx) {
        var w = cv.width, h = cv.height
        ctx.reset()
        ctx.clearRect(0, 0, w, h)
        if (w <= 0 || h <= 0) return
        if (cornerRadius > 0) { roundRectPath(ctx, 0, 0, w, h, cornerRadius); ctx.clip() }
        ctx.lineCap = "butt"
        ctx.lineJoin = "round"
        var c = condition
        if (c === "rain" || c === "thunder") { drawWhale(ctx, w, h); drawRain(ctx, w, h) }
        else if (c === "clear") drawClear(ctx, w, h)
        else if (c === "partly" || c === "cloudy") drawClouds(ctx, w, h)
        else if (c === "fog") drawFog(ctx, w, h)
        else if (c === "snow") drawSnow(ctx, w, h)
        if (windy) drawWind(ctx, w, h)
        if (c === "thunder") drawThunder(ctx, w, h)
        ctx.globalAlpha = 1
    }

    // ---- clear: star coordinates, orbital rings, satellite pass, moon at night ----
    function drawClear(ctx, w, h) {
        var night = isNight, i, P = palette
        for (i = 0; i < stars.length; i++) {
            var s = stars[i]
            var blink = Math.pow(Math.max(0, Math.sin(t * s.sp + s.ph)), 3)
            setStroke(ctx, P[s.col], 1, (night ? 0.08 : 0.06) + (night ? 0.24 : 0.18) * blink)
            ctx.beginPath(); cross(ctx, s.x * w, s.y * h, s.r); ctx.stroke()
        }

        var cx = w * 0.66, cy = h * 0.6, R = Math.min(h * 0.32, w * 0.15)
        for (i = 0; i < rings.length; i++) {
            var rg = rings[i]
            var ry = 0.72 * Math.sin(t * rg.tiltF + rg.tiltP)      // minor axis breathes through edge-on, never a full circle
            if (Math.abs(ry) < 0.05) ry = ry < 0 ? -0.05 : 0.05
            ellipsePath(ctx, cx, cy, R, R * ry, rg.rot + rg.rotA * Math.sin(t * rg.rotF))
            setStroke(ctx, P.outline, 1, rg.a)
            ctx.stroke()
        }
        setStroke(ctx, P.accent, 1, 0.26)                           // the body the rings orbit
        ctx.beginPath(); ctx.arc(cx, cy, 2.5, 0, Math.PI * 2, false); ctx.stroke()

        var st = sat
        ctx.fillStyle = P.accent
        for (i = 0; i < st.trail.length; i++) {
            var d = st.trail[i]
            setAlpha(ctx, 0.28 * Math.max(0, 1 - (t - d.t0) / 2.5))
            ctx.fillRect(d.x * w - 0.75, d.y * h - 0.75, 1.5, 1.5)
        }
        if (st.active) {
            var pos = satPos((t - st.t0) / st.dur)
            var x = pos.x * w, y = pos.y * h
            setAlpha(ctx, 0.3)
            ctx.fillRect(x - 1, y - 1, 2, 2)
            setStroke(ctx, P.accent, 1, 0.22)                       // open crosshair around the dot
            ctx.beginPath()
            ctx.moveTo(x - 5.5, y); ctx.lineTo(x - 2.5, y); ctx.moveTo(x + 2.5, y); ctx.lineTo(x + 5.5, y)
            ctx.moveTo(x, y - 5.5); ctx.lineTo(x, y - 2.5); ctx.moveTo(x, y + 2.5); ctx.lineTo(x, y + 5.5)
            ctx.stroke()
        }

        if (night) drawMoon(ctx, w, h)
    }

    // Crescent outline: the limb of one circle and the inner arc of a second
    // circle offset towards the horns, joined at their intersections.
    function drawMoon(ctx, w, h) {
        var r = Math.min(16, h * 0.14)
        var d = r * 0.45, r2 = r * 0.95
        var ix = (d * d + r * r - r2 * r2) / (2 * d)
        var iy = Math.sqrt(Math.max(0, r * r - ix * ix))
        var a1 = Math.atan2(iy, ix), b1 = Math.atan2(iy, ix - d)
        ctx.save()
        ctx.translate(w * 0.86, h * 0.28)
        ctx.rotate(-0.7)
        ctx.beginPath()
        ctx.arc(0, 0, r, a1, Math.PI * 2 - a1, false)
        ctx.arc(d, 0, r2, Math.PI * 2 - b1, b1, true)
        ctx.closePath()
        ctx.restore()
        setStroke(ctx, palette.outline, 1.2, 0.24)
        ctx.stroke()
    }

    // ---- partly / cloudy: wireframe cloud outlines, dashed sun ----
    function cloudPath(ctx, x, y, bumps, s) {
        var cx = x
        ctx.beginPath()
        ctx.moveTo(x, y + 2 * s)
        ctx.lineTo(x, y)
        for (var i = 0; i < bumps.length; i++) {
            var r = bumps[i] * s
            ctx.arc(cx + r, y, r, Math.PI, 0, false)                // over the top of each bump
            cx += 2 * r
        }
        ctx.lineTo(cx, y + 2 * s)
        ctx.closePath()
    }

    function drawClouds(ctx, w, h) {
        if (condition === "partly") {
            setStroke(ctx, palette.accent, 1.2, 0.22)
            dashedCircle(ctx, w * 0.07, h * 0.05, h * 0.30, 0.18, 0.12, t * 0.15)
        }
        var n = condition === "partly" ? 2 : 3
        setStroke(ctx, palette.outline, 1.5, 0.18)
        for (var i = 0; i < n; i++) {
            var c = clouds[i]
            var cw = 0
            for (var j = 0; j < c.bumps.length; j++) cw += 2 * c.bumps[j] * c.s
            var span = w + cw
            var x = mod(t * c.speed * (1 + windFactor) + c.ph * span, span) - cw
            cloudPath(ctx, x, h * c.y, c.bumps, c.s)
            ctx.stroke()
        }
    }

    // ---- fog: sliding, flickering scan bands ----
    function drawFog(ctx, w, h) {
        setStroke(ctx, palette.outline, 1, 0.14)
        for (var i = 0; i < fogRows.length; i++) {
            var r = fogRows[i]
            var base = 0.12 + 0.05 * Math.sin(t * r.f + r.ph)
            dashedRow(ctx, Math.round(h * r.y) + 0.5, w, r.dash, r.gap, t * r.speed, base, i)
        }
    }

    // ---- rain: falling tick vectors, baseline grid, landing ripples ----
    function drawRain(ctx, w, h) {
        var g = rainGeom(w, h), i, P = palette
        var yb = h - 6

        setStroke(ctx, P.outline, 1, 0.18)                          // baseline with perpendicular ticks
        ctx.beginPath()
        ctx.moveTo(0, yb + 0.5); ctx.lineTo(w, yb + 0.5)
        for (var x = 12; x < w; x += 24) { ctx.moveTo(x + 0.5, yb + 0.5); ctx.lineTo(x + 0.5, yb - 3) }
        ctx.stroke()

        setStroke(ctx, P.cool, 1.2, 0.26)
        ctx.beginPath()
        for (i = 0; i < drops.length; i++) {
            var d = drops[i]
            var p = mod(t * d.sp * g.rate + d.ph, 1)
            if (p > g.pLand) continue
            var dx = d.x0 * (w + g.drift) - g.drift + p * g.drift
            var dy = -14 + p * g.travel
            ctx.moveTo(dx, dy)
            ctx.lineTo(dx - g.ux * g.len, dy - g.uy * g.len)
        }
        ctx.stroke()

        for (i = 0; i < ripples.length; i++) {
            var rp = ripples[i]
            var q = (t - rp.t0) / 0.4
            if (q >= 1) continue
            var rx = 2 + 9 * q
            ellipsePath(ctx, rp.x, yb, rx, rx * 0.3, 0)
            setStroke(ctx, P.cool, 1, 0.3 * (1 - q))
            ctx.stroke()
        }
    }

    // ---- rain easter egg: the whale and the bowl of petunias ----
    function whalePath(ctx) {
        ctx.beginPath()
        ctx.moveTo(-11, 0)
        ctx.quadraticCurveTo(-11, -4.5, -6, -4.5)                   // blunt forehead
        ctx.quadraticCurveTo(0, -4.5, 6, -1.5)                      // back tapering to the tail
        ctx.lineTo(8, -0.5)
        ctx.lineTo(10.5, -3.5); ctx.lineTo(11, -2.5); ctx.lineTo(9.5, 0)   // upper fluke
        ctx.lineTo(11, 2.5); ctx.lineTo(10.5, 3.5); ctx.lineTo(8, 0.5)     // lower fluke
        ctx.quadraticCurveTo(0, 3.5, -6, 3.5)                       // belly
        ctx.quadraticCurveTo(-11, 3.5, -11, 0)
        ctx.closePath()
        ctx.moveTo(-11, 1.5); ctx.lineTo(-7, 1.5)                   // mouth
        ctx.moveTo(-4, 3); ctx.lineTo(-2.5, 5.5); ctx.lineTo(-0.5, 3.2)   // flipper
    }

    function petuniaPath(ctx) {
        ctx.beginPath()
        ctx.moveTo(-4, 0); ctx.lineTo(4, 0); ctx.lineTo(2.5, 4); ctx.lineTo(-2.5, 4); ctx.closePath()   // bowl
        ctx.moveTo(-2, 0); ctx.lineTo(-2.5, -3)                     // stems
        ctx.moveTo(0, 0); ctx.lineTo(0, -4)
        ctx.moveTo(2, 0); ctx.lineTo(2.5, -3)
        ctx.moveTo(-1.3, -3.5); ctx.arc(-2.5, -3.5, 1.2, 0, Math.PI * 2, false)   // flowers
        ctx.moveTo(1.2, -4.5); ctx.arc(0, -4.5, 1.2, 0, Math.PI * 2, false)
        ctx.moveTo(3.7, -3.5); ctx.arc(2.5, -3.5, 1.2, 0, Math.PI * 2, false)
    }

    function drawWhale(ctx, w, h) {
        var k = whale
        if (!k.active || hazards.length) return
        var p = (t - k.t0) / 7
        var x = k.x0 * w + p * windFactor * 50 + 3 * Math.sin(t * 0.8)
        var y = -14 + p * (h + 28)
        setStroke(ctx, palette.outline, 1, 0.16)
        ctx.save()
        ctx.translate(x, y)
        ctx.rotate(0.35 + 0.08 * Math.sin(t * 1.3))
        whalePath(ctx)
        ctx.restore()
        ctx.stroke()
        ctx.save()
        ctx.translate(x + 22, y + 7 + 2 * Math.sin(t * 1.1 + 1))
        ctx.rotate(-0.2)
        petuniaPath(ctx)
        ctx.restore()
        ctx.stroke()
    }

    // ---- snow: asterisks and diamonds ----
    function drawSnow(ctx, w, h) {
        var P = palette
        for (var i = 0; i < flakes.length; i++) {
            var f = flakes[i]
            var p = mod(t * f.sp + f.ph, 1)
            var y = -6 + p * (h + 12)
            var x = mod(f.x * w + Math.sin(t * f.swF + f.swP) * f.swA + t * windFactor * 14, w)
            var r = f.r
            setStroke(ctx, P[f.col], 1, 0.14 + (r - 1.5) * 0.1)
            ctx.beginPath()
            if (f.star) {
                for (var k = 0; k < 3; k++) {
                    var a = k * Math.PI / 3
                    ctx.moveTo(x - r * Math.cos(a), y - r * Math.sin(a))
                    ctx.lineTo(x + r * Math.cos(a), y + r * Math.sin(a))
                }
            } else {
                ctx.moveTo(x, y - r); ctx.lineTo(x + r, y); ctx.lineTo(x, y + r); ctx.lineTo(x - r, y); ctx.closePath()
            }
            ctx.stroke()
        }
    }

    // ---- wind: oscilloscope traces scrolling left to right ----
    function drawWind(ctx, w, h) {
        var rate = 2 + windFactor * 4
        for (var i = 0; i < traces.length; i++) {
            var tr = traces[i]
            setStroke(ctx, palette.outline, 1, 0.13 + 0.05 * Math.sin(t * tr.shF + tr.ph))
            var y0 = h * tr.y
            ctx.beginPath()
            for (var x = 0; x <= w + 4; x += 4) {
                var y = y0 + tr.amp * Math.sin(x / tr.k - t * rate + tr.ph)
                if (x === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
            }
            ctx.stroke()
        }
    }

    // ---- thunder: vector bolt, CRT flash, telemetry readout ----
    function drawThunder(ctx, w, h) {
        var b = bolt, P = palette
        var e = t - b.t0
        if (e < 0 || e > 1.2) return
        if (e < 0.3 && b.pts.length > 1) {
            var a = 1 - e / 0.3
            setStroke(ctx, P.accent, 1.5, 0.9 * a)
            ctx.beginPath(); polyline(ctx, b.pts)
            for (var i = 0; i < b.forks.length; i++) polyline(ctx, b.forks[i])
            ctx.stroke()
            setStroke(ctx, P.danger, 0.6, 0.8 * a)                  // thin hot core
            ctx.stroke()
        }
        if (e < 0.35) {                                             // screen flash: accent snap, danger afterglow
            var light = P.light === true                            // on cream the flash is gentler
            ctx.fillStyle = P.accent
            ctx.globalAlpha = (light ? 0.10 : 0.14) * Math.max(0, 1 - e / 0.12)
            ctx.fillRect(0, 0, w, h)
            ctx.fillStyle = P.danger
            ctx.globalAlpha = (light ? 0.05 : 0.06) * (1 - e / 0.35)
            ctx.fillRect(0, 0, w, h)
        }
        ctx.fillStyle = P.accent
        ctx.globalAlpha = 0.7 * (e < 1.0 ? 1 : (1.2 - e) / 0.2)
        ctx.font = "9px monospace"
        ctx.fillText(i18n("[IMPROBABILITY SURGE]"), 8, 13)
    }
}
