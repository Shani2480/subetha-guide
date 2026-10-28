import QtQuick

// Arthur Dent and Marvin the Paranoid Android, drawn as wireframe vectors in
// the style of the Guide's own animations: phosphor-green outlines with the
// towel, Marvin's eye and his diagnostic LED in amber. The pair rests on the
// top edge of the hourly strip: the ground line is y = ground (28) and the
// lower 8 px hang over the strip so a seated or lying pose can use it. The
// wind blows left to right, like the ambient effects behind the card, so
// leaning is to the left and anything loose (towel, belt) trails to the right.
//
// Both figures are articulated skeletons posed by a two-bone IK and drawn on
// one canvas, repainted about 30 times a second from a clock while `running`.
// Arthur has a head, neck, hip, two-segment arms and legs; his untied
// dressing gown hangs from the shoulders in two panels with a collar fold,
// the belt dangling. Marvin is a biped: a boxy body, two two-segment legs,
// two long two-segment arms dangling past his hips, and an oversized sphere
// of a head on a neck that pivots, so his mood is one number, `tilt`: 0 is
// upright, 0.75 rad (45°) is the usual slump. Poses blend by mixing solved
// joints (walking <-> resting, idle <-> micro-action, the Guide, hover).
//
// Scenes, in priority order:
//   storm    rain/thunder, wind >= 22: Arthur braced into the gusts, the towel stretched
//            overhead and whipping off downwind; Marvin slumped and unprotected
//   thunder  calm thunderstorm: Arthur under the towel tent; a flash makes him crouch and
//            pull it round his head, Marvin emits a static spark
//   rain     calm rain: Arthur holds the towel over his head like a tent, drops bouncing
//            off it; Marvin stands in the rain, head down 45°, drops pinging off his dome
//   snow     Arthur hugging his gown closed, towel round his neck, shivering, blowing
//            clouds of breath (or sipping tea); snow piles on Marvin's dome and slides off
//   windy    dry wind >= 25: Arthur holds the gown shut with one hand, the towel streaming
//            from the other; Marvin leans into it, head down
//   sunny    clear day: Arthur sits cross-legged on the towel drinking tea; Marvin stands
//            nearby staring at the floor
//   night    clear night: Arthur asleep on his side wrapped in the gown, the rolled towel
//            for a pillow, z's; Marvin rigid in standby, one amber LED blinking
//   calm     cloudy / partly / fog: Arthur stands with the towel over his shoulder, now and
//            then glancing at Marvin; Marvin sighs, his head sinking and lifting
//
// `temperature` adds props: a cup of tea at 10° or below (calm, snow), a
// campfire at 2° or below in dry weather (always in the snow); calm rain a
// puddle. Props scale with `propScale * (1 - walkBlend)`.
//
// Every 14 to 25 s (never at night) the pair wanders a short way along the
// track between `minTrackX` and `maxTrackX`: usually a stroll at 13 px/s,
// Arthur on an articulated gait with the towel over his shoulder, Marvin
// trudging ahead head-down, now and then a fade-out and reappearance.
// Turning round is never a flip: `facingScale` eases through edge-on while
// the pair dips into the step and the heads lead the turn. The host sets
// `homeX` and the track; it must not bind `x`.
//
// Styles: `style` "wire" draws phosphor outlines (the 1981 BBC Guide); "solid"
// draws the 2005 film's cut-outs: Arthur a filled silhouette in `color` with
// pyjama stripes, flapping lapels and a mustard towel (under his arm on the
// move, over both shoulders when he sits), Marvin a compact `navy` body with
// stubby legs, arms past the knees and a massive white sphere (`headColor`)
// with a tiny visor slit, rolling slowly sideways in boredom.
//
// Interactions: hovering makes Marvin look up while Arthur waves; a click
// has Arthur hold up the Guide, a glowing "42" hologram hanging above them
// for two seconds while Marvin slowly shakes his head. Left alone, every 12
// to 22 s Marvin sighs or runs a diagnostic, Arthur checks his towel or
// shakes the snow out of it.
Item {
    id: character

    property string condition: "cloudy"
    property bool isNight: false
    property real windSpeed: 0           // km/h
    property real temperature: 15        // °C of the day shown; chooses the tea and campfire props
    property bool running: true
    property color color: "#00FF66"      // the ink: wireframe lines, or the silhouettes in the solid style
    property color accent: "#FFB000"     // towel, Marvin's eye and LED, the 42
    // "wire": phosphor outlines like the 1981 BBC Guide animations.
    // "solid": the 2005 film's cut-out look: Arthur a filled silhouette in
    // `color` with a mustard towel, Marvin a navy body under a big white dome.
    property string style: "wire"
    property color headColor: "#FFFFFF"  // Marvin's dome (solid style)
    property color navy: "#2C3E50"       // Marvin's body and limbs (solid style)
    property string fontFamily: "monospace"
    onStyleChanged: dirty()
    onHeadColorChanged: dirty()
    onNavyChanged: dirty()

    // Roaming track, in the parent's coordinates, and where to start.
    property bool roaming: true
    property real minTrackX: 0
    property real maxTrackX: 0
    property real homeX: (minTrackX + maxTrackX) / 2
    property bool isWalking: false
    property int facingDirection: 1       // 1 = facing right, -1 = facing left
    property real walkPhase: 0            // 0..2π per stride while walking
    // 0 = fully in the idle pose, 1 = fully walking; eased, so poses blend
    property real walkBlend: isWalking ? 1.0 : 0.0
    Behavior on walkBlend {
        NumberAnimation {
            duration: character.isWalking ? 220 : 380       // quick to stand up into a walk, gentle to settle down
            easing.type: character.isWalking ? Easing.OutQuad : Easing.InOutCubic
        }
    }
    onWalkBlendChanged: dirty()
    readonly property real minHop: 45     // one stroll covers between minHop and maxHop
    readonly property real maxHop: 110

    width: 54
    height: 36
    opacity: 0.32

    readonly property real ground: 28
    readonly property real padX: 12          // canvas headroom, see `art`
    readonly property real padY: 14

    // =====================================================================
    // Scene selection
    // =====================================================================
    readonly property bool wetWeather: condition === "rain" || condition === "thunder"
    readonly property string targetScene: wetWeather && windSpeed >= 22 ? "windyRain"
        : condition === "thunder" ? "thunder"
        : condition === "rain" ? "rain"
        : condition === "snow" ? "snow"
        : windSpeed >= 25 ? "windyDry"
        : condition === "clear" && !isNight ? "sunnyPlay"
        : condition === "clear" && isNight ? "sleep"
        : "calm"
    property string renderedScene: "calm"            // set from targetScene by the transition (or at once when not running)
    property real transitionScaleY: 1.0               // the pair crouching towards the ground line
    property real transitionOffsetY: 0.0
    property real transitionOpacity: 0.32             // relative to the resting 0.32
    property real towelProgress: tentScene(renderedScene) ? 1.0 : 0.0   // 0 = towel bunched in the hands, 1 = stretched into a tent
    property real propScale: 1.0                      // props anchored at the ground
    function tentScene(scene) { return scene === "rain" || scene === "windyRain" || scene === "thunder" }

    // Short pose names used by the drawing code: one per rendered scene.
    readonly property string pose: renderedScene === "windyRain" ? "storm"
        : renderedScene === "windyDry" ? "windy"
        : renderedScene === "sunnyPlay" ? "sunny"
        : renderedScene === "sleep" ? "night"
        : renderedScene
    readonly property bool nightScene: pose === "night"
    readonly property bool dozing: pose === "night"
    readonly property bool wet: pose === "storm" || pose === "rain" || pose === "thunder"
    readonly property bool sheltered: pose === "rain" || pose === "thunder"
    readonly property bool leaning: pose === "storm" || pose === "windy"
    readonly property bool gusty: pose === "storm" || pose === "windy"
    // The scene is drawn facing right and mirrored to face left. In a gale the
    // idle poses lean into the wind (which blows to the right), so they are
    // never mirrored; a walk is, with the lean re-applied in world space.
    readonly property bool mirror: facingDirection < 0 && (isWalking || !gusty)
    // The mirror is never applied in one frame: `facingScale` eases between
    // 1 and -1, so the pair turns on the spot. Through the turn they dip
    // into the step, the heads lead, and the heads and bodies keep a minimum
    // width, so edge-on they read as a rounded back rather than a line.
    property real facingScale: mirror ? -1 : 1
    Behavior on facingScale {
        enabled: character.running
        NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
    }
    onFacingScaleChanged: dirty()

    // Where Arthur stands (centre x of his frame) and where Marvin's box starts.
    // Both slide between their idle spot and their walking spot with the blend.
    readonly property real idlePersonX: leaning ? 14 : 11
    readonly property real idleMarvinX: pose === "sunny" ? 32 : pose === "rain" ? 32 : pose === "thunder" ? 28 : 30
    readonly property real personX: idlePersonX + (12 - idlePersonX) * walkBlend
    readonly property real marvinX: idleMarvinX + (27 - idleMarvinX) * walkBlend

    function dirty() { art.requestPaint() }
    onPoseChanged: dirty()
    onTowelProgressChanged: dirty()
    onPropScaleChanged: dirty()
    onWalkPhaseChanged: dirty()
    onColorChanged: dirty()
    onAccentChanged: dirty()
    onTemperatureChanged: dirty()
    onRunningChanged: if (!running) { walkAnim.stop(); fadeAnim.stop(); fadeOpacity = 1; cancelInteractions(); if (sceneChangeAnimation.running) { sceneChangeAnimation.stop(); applySceneNow() } }

    // =====================================================================
    // Clock: every motion is a function of these
    // =====================================================================
    property real clock: 0               // seconds, pauses with `running`
    property real idlePhase: 0           // clock * π: 2π every 2 s
    property real sceneClock0: 0         // when the rendered scene began
    readonly property real sceneTime: clock - sceneClock0
    property real flashClock: -100       // last lightning flash (thunder startle)
    property double lastTick: 0
    Timer {
        // 30 FPS while the pair walks or interacts, 22 FPS for the idle fidgets
        interval: character.isWalking || character.busy || character.isHovered || sceneChangeAnimation.running ? 33 : 45
        repeat: true
        running: character.running && character.visible
        onTriggered: {
            var now = Date.now()
            if (character.lastTick > 0) character.clock += Math.min(0.1, (now - character.lastTick) / 1000)
            character.lastTick = now
            character.idlePhase = character.clock * Math.PI
            art.requestPaint()
        }
        onRunningChanged: character.lastTick = 0
    }
    function flinch() { flashClock = clock; dirty() }
    function duck() { flinch() }

    // =====================================================================
    // Scene transitions
    // =====================================================================
    onTargetSceneChanged: {
        if (targetScene === renderedScene) return
        if (!running) { applySceneNow(); return }
        if (walkAnim.running) walkAnim.stop()
        if (fadeAnim.running) { fadeAnim.stop(); fadeOpacity = 1 }
        isWalking = false
        cancelInteractions()
        sceneChangeAnimation.restart()
    }
    function applySceneNow() {
        cancelInteractions()
        renderedScene = targetScene
        resetSceneCounters()
        transitionScaleY = 1; transitionOffsetY = 0; transitionOpacity = 0.32
        towelProgress = tentScene(renderedScene) ? 1 : 0
        propScale = 1
    }
    function resetSceneCounters() { sceneClock0 = clock; walkPhase = 0; dirty() }
    SequentialAnimation {
        id: sceneChangeAnimation
        // 1. anticipation: crouch towards the ground, bunch up the towel, props shrink away
        ParallelAnimation {
            NumberAnimation { target: character; property: "transitionScaleY"; to: 0.75; duration: 150; easing.type: Easing.InQuad }
            NumberAnimation { target: character; property: "transitionOffsetY"; to: 3; duration: 150; easing.type: Easing.InQuad }
            NumberAnimation { target: character; property: "transitionOpacity"; to: 0.06; duration: 150; easing.type: Easing.InQuad }
            NumberAnimation { target: character; property: "propScale"; to: 0; duration: 150; easing.type: Easing.InQuad }
            NumberAnimation { target: character; property: "towelProgress"; to: 0; duration: 150; easing.type: Easing.InQuad }
        }
        // 2. swap: draw the new scene while nearly invisible
        ScriptAction {
            script: {
                character.renderedScene = character.targetScene
                character.resetSceneCounters()
                towelOpen.to = character.tentScene(character.renderedScene) ? 1 : 0
                towelOpen.restart()
            }
        }
        // 3. settle: stand up with a little overshoot, props pop up from the ground
        ParallelAnimation {
            NumberAnimation { target: character; property: "transitionScaleY"; to: 1; duration: 240; easing.type: Easing.OutBack }
            NumberAnimation { target: character; property: "transitionOffsetY"; to: 0; duration: 240; easing.type: Easing.OutBack }
            NumberAnimation { target: character; property: "transitionOpacity"; to: 0.32; duration: 240; easing.type: Easing.OutCubic }
            NumberAnimation { target: character; property: "propScale"; from: 0; to: 1; duration: 280; easing.type: Easing.OutBack }
        }
    }
    NumberAnimation {
        id: towelOpen
        target: character; property: "towelProgress"
        duration: 300; easing.type: Easing.OutBack
    }

    // =====================================================================
    // Roaming
    // =====================================================================
    property bool roamed: false
    Binding {
        target: character; property: "x"
        value: character.clampX(character.homeX)
        when: !character.roamed && character.maxTrackX > character.minTrackX
        restoreMode: Binding.RestoreNone
    }
    function clampX(v) { return Math.max(minTrackX, Math.min(maxTrackX, v)) }
    function keepOnTrack() {
        if (!roamed || maxTrackX <= minTrackX) return
        if (walkAnim.running) walkAnim.stop()
        x = clampX(x)
    }
    onMinTrackXChanged: keepOnTrack()
    onMaxTrackXChanged: keepOnTrack()

    Timer {
        id: roamTimer
        running: character.running && character.roaming && !character.nightScene
                 && !character.isWalking && !fadeAnim.running && !sceneChangeAnimation.running
                 && !character.busy && !character.isHovered
        repeat: true
        interval: 14000 + Math.random() * 11000
        onTriggered: { interval = 14000 + Math.random() * 11000; character.roam() }
    }
    // Public: stroll to a fresh spot right now, as a reaction to new weather
    // data or the hourly strip advancing.
    function triggerRoam() {
        if (!visible || !running || !roaming || nightScene) return
        if (isWalking || fadeAnim.running || sceneChangeAnimation.running || busy) return
        roamTimer.interval = 14000 + Math.random() * 11000
        roamTimer.restart()
        roam(undefined, false)
    }
    // Public: walk (never fade) to a given x on the track.
    function startWalkTo(targetX) { roam(targetX, false) }

    function roam(target, fade) {
        if (target === undefined) {
            var canLeft = x - minHop >= minTrackX
            var canRight = x + minHop <= maxTrackX
            if (!canLeft && !canRight) return
            var dir = canLeft && canRight ? (Math.random() < 0.5 ? -1 : 1) : canLeft ? -1 : 1
            target = x + dir * (minHop + Math.random() * (maxHop - minHop))
        }
        if (fade === undefined) fade = Math.random() < 0.2
        target = clampX(target)
        if (target === x) return
        cancelInteractions()
        roamed = true
        facingDirection = target > x ? 1 : -1
        if (fade) {
            fadeAnim.targetX = target
            fadeAnim.restart()
        } else {
            walkAnim.to = target
            walkAnim.duration = Math.max(2500, Math.abs(target - x) * 75)   // a leisurely 13 px/s
            isWalking = true
            walkAnim.restart()
        }
    }
    NumberAnimation {
        id: walkAnim
        target: character; property: "x"
        easing.type: Easing.InOutSine
        onRunningChanged: if (!running) character.isWalking = false
    }
    property real fadeOpacity: 1
    SequentialAnimation {
        id: fadeAnim
        property real targetX: 0
        NumberAnimation { target: character; property: "fadeOpacity"; to: 0; duration: 300; easing.type: Easing.InQuad }
        ScriptAction { script: character.x = fadeAnim.targetX }
        NumberAnimation { target: character; property: "fadeOpacity"; to: 1; duration: 300; easing.type: Easing.OutQuad }
    }
    // one unhurried stride per cycle
    NumberAnimation on walkPhase {
        running: character.running && character.isWalking
        from: 0; to: Math.PI * 2
        duration: 1000
        loops: Animation.Infinite
    }

    // =====================================================================
    // Interactions: hover greeting, the Guide, idle micro-behaviours
    // =====================================================================
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        enabled: character.running
        onClicked: character.playTrick()
    }
    property bool isHovered: mouseArea.containsMouse
    readonly property bool greeting: isHovered && running && pose !== "storm" && !dozing
    property real waveBlend: greeting ? 1 : 0                          // Arthur's arm raised in a wave, Marvin looking up
    Behavior on waveBlend { NumberAnimation { duration: 260; easing.type: Easing.InOutQuad } }
    onWaveBlendChanged: dirty()
    readonly property bool busy: tricking || activeMicroAction !== "none"

    // Click: Arthur reaches into the gown, holds the Guide up, "42" hangs
    // glowing above them for two seconds while Marvin shakes his head.
    readonly property bool tricking: trickAnimation.running
    property real trickProgress: 0
    NumberAnimation {
        id: trickAnimation
        target: character; property: "trickProgress"
        from: 0; to: 1
        duration: 3000
    }
    onTrickProgressChanged: dirty()
    function playTrick() {
        if (!running || isWalking || walkBlend > 0 || tricking || sceneChangeAnimation.running || fadeAnim.running) return
        if (pose === "storm" || dozing) return
        if (microAnim.running) microAnim.stop()
        trickAnimation.restart()
    }

    // Idle micro-actions: every 12 to 22 s of rest, one in-character thing for 2.5 s.
    property string activeMicroAction: "none"                        // "sigh" | "diagnostic" | "towelCheck" | "shakeOff"
    property real microPhase: 0
    NumberAnimation {
        id: microAnim
        target: character; property: "microPhase"
        from: 0; to: 1
        duration: 2500
        onRunningChanged: if (!running) character.activeMicroAction = "none"
    }
    onMicroPhaseChanged: dirty()
    onActiveMicroActionChanged: dirty()
    Timer {
        id: microActionTimer
        running: character.running && !character.isWalking && character.walkBlend === 0 && !character.isHovered
                 && !character.tricking && character.activeMicroAction === "none"
                 && !sceneChangeAnimation.running && !fadeAnim.running
        repeat: true
        interval: 12000 + Math.random() * 10000
        onTriggered: { interval = 12000 + Math.random() * 10000; character.startMicroAction() }
    }
    function microCandidates() {
        var s = renderedScene, out = []
        if (s === "sleep") return out
        out.push("sigh")                                                // Marvin, always
        if (s !== "windyRain") out.push("diagnostic")
        if (s === "calm") out.push("towelCheck")                        // Arthur unfolds and inspects the towel
        if (s === "snow") out.push("shakeOff")                          // Arthur shakes the snow out of it
        return out
    }
    // Public: start a micro-action now; without a name, a random one that fits the scene.
    function startMicroAction(name) {
        if (name === undefined) {
            var c = microCandidates()
            if (c.length === 0) return
            name = c[Math.floor(Math.random() * c.length)]
        }
        activeMicroAction = name
        microAnim.restart()
    }
    function cancelInteractions() {
        if (trickAnimation.running) { trickAnimation.stop(); trickProgress = 0 }
        if (microAnim.running) microAnim.stop()
        activeMicroAction = "none"
    }

    readonly property bool holdingMug: temperature <= 10 && (pose === "calm" || pose === "snow")
    readonly property bool campfire: pose === "snow" || (temperature <= 2 && !wet)

    // =====================================================================
    // The canvas, crouching from the ground line through a scene change
    // =====================================================================
    Item {
        id: scene
        anchors.fill: parent
        opacity: character.fadeOpacity * (character.transitionOpacity / 0.32)
        transform: [
            Scale { origin.y: character.ground; yScale: character.transitionScaleY },
            Translate { y: character.transitionOffsetY }
        ]
        Canvas {   // oversized so the raised towel, the Guide's hologram or a streaming towel is not clipped
            id: art
            x: -character.padX; y: -character.padY
            width: character.width + character.padX * 2
            height: character.height + character.padY
            renderTarget: Canvas.FramebufferObject
            renderStrategy: Canvas.Threaded
            onPaint: character.paintScene(getContext("2d"))
        }
    }

    // =====================================================================
    // Maths
    // =====================================================================
    function clamp01(v) { return Math.max(0, Math.min(1, v)) }
    function smooth(v) { v = clamp01(v); return v * v * (3 - 2 * v) }
    // 1 inside [a, b], eased ramps of width r either side, 0 beyond
    function win(u, a, b, r) {
        if (u < a - r || u > b + r) return 0
        if (u < a) return smooth((u - (a - r)) / r)
        if (u > b) return smooth((b + r - u) / r)
        return 1
    }
    function lerp(a, b, w) { return a + (b - a) * w }
    // numbers, arrays or objects, element-wise; strings and the like snap
    function mix(a, c, w) {
        if (w <= 0) return a
        if (w >= 1) return c
        if (typeof a === "number") return a + (c - a) * w
        if (Array.isArray(a)) { var o = []; for (var i = 0; i < a.length; i++) o.push(mix(a[i], c[i], w)); return o }
        if (typeof a === "object" && a !== null) {
            var r = {}, k
            for (k in a) r[k] = (k in c) ? mix(a[k], c[k], w) : (typeof a[k] === "number" ? a[k] * (1 - w) : a[k])
            for (k in c) if (!(k in a)) r[k] = typeof c[k] === "number" ? c[k] * w : c[k]
            return r
        }
        return w < 0.5 ? a : c
    }
    // Two-bone IK: root (rx, ry) to target (tx, ty) with segments l1 and l2;
    // `bend` (+1 / -1) picks which side the joint goes. Out of reach, the
    // chain straightens towards the target. Returns [jointX, jointY, endX, endY].
    function ik(rx, ry, tx, ty, l1, l2, bend) {
        var dx = tx - rx, dy = ty - ry, d = Math.sqrt(dx * dx + dy * dy)
        if (d < 0.001) { dx = 0; dy = 1; d = 0.001 }
        var ux = dx / d, uy = dy / d
        var reach = l1 + l2 - 0.02
        if (d > reach) { d = reach; tx = rx + ux * d; ty = ry + uy * d }
        d = Math.max(Math.abs(l1 - l2) + 0.02, d)
        var a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
        var h = Math.sqrt(Math.max(0, l1 * l1 - a * a))
        return [rx + ux * a - uy * h * bend, ry + uy * a + ux * h * bend, tx, ty]
    }

    // =====================================================================
    // Drawing
    // =====================================================================
    function paintScene(ctx) {
        ctx.reset()
        ctx.translate(padX, padY)
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        var self = character, G = ground, t = clock, st = sceneTime, ip = idlePhase
        var green = color, amber = accent, white = headColor, navy = self.navy
        var solid = self.style === "solid"
        ctx.strokeStyle = green
        ctx.fillStyle = green
        var fs = facingScale, afs = Math.abs(fs), cx = width / 2
        var turning = afs < 0.95
        var turnDip = turning ? 1.2 * (1 - afs) : 0                   // knees give as they step into the turn
        var lead = turning ? facingDirection * 1.5 * (1 - afs) : 0    // heads lead the turn (world px)
        var b = clamp01(walkBlend), idleW = 1 - b
        var ps = propScale * idleW                                     // prop scale, anchored at the ground
        var dx = personX - 18                                          // Arthur's local frame -> card
        var gust = clamp01(0.5 + 0.5 * Math.sin(ip * 0.8) + 0.3 * Math.sin(ip * 2.3) + 0.3) / 1.3
        var startle = pose === "thunder" ? clamp01((t - flashClock) / 1.8) : 1   // 0 just flashed, 1 settled
        var hunch = pose === "thunder" ? (1 - win(startle, 0.3, 2, 0.2)) : pose === "storm" ? (1 - clamp01((t - flashClock) / 0.25)) : 0
        var spark = pose === "thunder" ? (1 - win(startle, 0.28, 2, 0.06)) : 0   // Marvin's static right after the flash

        // ------------------------------------------------------------------
        // Pen: every point goes through `map` (card coords -> canvas)
        // ------------------------------------------------------------------
        function sceneMap(x, y) { return [cx + (x - cx) * fs, y] }
        var map = sceneMap
        var xs = Math.max(afs, 0.55)                                   // horizontal radius factor for round things: never a line
        var leadX = 0                                                  // world x nudge, used for the heads
        function pen(c) { ctx.strokeStyle = c; ctx.fillStyle = c }
        function L(ax, ay, bx, by, w) {
            var a = map(ax, ay), c = map(bx, by)
            ctx.lineWidth = w
            ctx.beginPath(); ctx.moveTo(a[0] + leadX, a[1]); ctx.lineTo(c[0] + leadX, c[1]); ctx.stroke()
        }
        function Pl(pts, w, alpha, closed) {                           // polyline (optionally closed)
            ctx.lineWidth = w
            if (alpha !== undefined) ctx.globalAlpha = alpha
            ctx.beginPath()
            for (var i = 0; i < pts.length; i++) { var p = map(pts[i][0], pts[i][1]); if (i === 0) ctx.moveTo(p[0] + leadX, p[1]); else ctx.lineTo(p[0] + leadX, p[1]) }
            if (closed) ctx.closePath()
            ctx.stroke()
            if (alpha !== undefined) ctx.globalAlpha = 1
        }
        function Fill(pts, col, alpha) {                               // filled polygon (solid style)
            ctx.fillStyle = col
            if (alpha !== undefined) ctx.globalAlpha = alpha
            ctx.beginPath()
            for (var i = 0; i < pts.length; i++) { var p = map(pts[i][0], pts[i][1]); if (i === 0) ctx.moveTo(p[0] + leadX, p[1]); else ctx.lineTo(p[0] + leadX, p[1]) }
            ctx.closePath()
            ctx.fill()
            if (alpha !== undefined) ctx.globalAlpha = 1
            ctx.fillStyle = ctx.strokeStyle
        }
        function D(x, y, r) {                                          // filled dot, an ellipse under the turn
            var p = map(x, y)
            ctx.beginPath(); ctx.ellipse(p[0] + leadX - r * xs, p[1] - r, r * 2 * xs, r * 2); ctx.fill()
        }
        function Q(ax, ay, qx, qy, bx, by, w) {                        // quadratic bezier stroke
            var a = map(ax, ay), q = map(qx, qy), c = map(bx, by)
            ctx.lineWidth = w
            ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.quadraticCurveTo(q[0], q[1], c[0], c[1]); ctx.stroke()
        }
        function Ring(x, y, rx, ry, w, alpha) {                        // stroked ellipse outline
            var p = map(x, y)
            if (alpha !== undefined) ctx.globalAlpha = alpha
            ctx.lineWidth = w
            ctx.beginPath(); ctx.ellipse(p[0] + leadX - rx * xs, p[1] - ry, rx * 2 * xs, ry * 2); ctx.stroke()
            if (alpha !== undefined) ctx.globalAlpha = 1
        }
        function Arc(x, y, r, a0, a1, w) {                             // stroked arc, angles in rad (canvas convention)
            var p = map(x, y)
            ctx.lineWidth = w
            ctx.beginPath()
            for (var i = 0; i <= 10; i++) {
                var a = a0 + (a1 - a0) * i / 10
                var qx = p[0] + leadX + Math.cos(a) * r * xs, qy = p[1] + Math.sin(a) * r
                if (i === 0) ctx.moveTo(qx, qy); else ctx.lineTo(qx, qy)
            }
            ctx.stroke()
        }
        function Rect(x, y, w, h, lw) { Pl([[x, y], [x + w, y], [x + w, y + h], [x, y + h]], lw, undefined, true) }
        function Txt(s, x, y, size, alpha) {
            var p = map(x, y)
            ctx.globalAlpha = alpha
            ctx.font = "bold " + size + "px " + self.fontFamily
            ctx.textAlign = "center"
            ctx.fillText(s, p[0], p[1])
            ctx.textAlign = "start"
            ctx.globalAlpha = 1
        }
        function Halo(x, y, r, alpha, col) {                           // soft radial glow
            var p = map(x, y)
            var g = ctx.createRadialGradient(p[0], p[1], 0, p[0], p[1], r)
            g.addColorStop(0, Qt.rgba(col.r, col.g, col.b, alpha))
            g.addColorStop(1, Qt.rgba(col.r, col.g, col.b, 0))
            ctx.fillStyle = g
            ctx.beginPath(); ctx.arc(p[0], p[1], r, 0, Math.PI * 2); ctx.fill()
            ctx.fillStyle = ctx.strokeStyle
        }
        // a strip streaming from (nx, ny) in direction dir, waving in a multi-node sine
        function ribbon(nx, ny, len, dir, amp, w, alpha, rate) {
            var pts = [], k, x
            rate = rate === undefined ? 3.5 : rate
            for (x = 0; x <= len; x++) {
                k = x / len
                pts.push([nx + x * dir, ny + 1.5 * k + Math.sin(k * 7 - ip * rate - self.walkPhase) * amp * k])
            }
            Pl(pts, w, alpha)
        }

        // ------------------------------------------------------------------
        // Arthur: skeleton builder (local frame, 36 wide, centred on x = 18)
        // ------------------------------------------------------------------
        var THIGH = 4.8, SHIN = 4.8, UPPER = 4.1, FORE = 4.1
        // o: { hip, neck, head, legs: [{ankle, toe?, bend?} x2], arms: [{hand, bend?, shoulder?} x2], headR?, lying?, gownOpen? }
        function human(o) {
            var hip = [o.hip[0], o.hip[1] + turnDip], neck = [o.neck[0], o.neck[1] + turnDip], head = [o.head[0], o.head[1] + turnDip]
            var legs = [], arms = [], i, r
            for (i = 0; i < 2; i++) {
                var l = o.legs[i]
                r = ik(hip[0], hip[1], l.ankle[0], l.ankle[1], THIGH, SHIN, l.bend === undefined ? -1 : l.bend)
                legs.push([hip[0], hip[1], r[0], r[1], r[2], r[3], l.toe ? l.toe[0] : r[2] + 1.7, l.toe ? l.toe[1] : r[3] + 1])
            }
            var sh = [neck[0], neck[1] + 1]
            for (i = 0; i < 2; i++) {
                var a = o.arms[i], s = a.shoulder || sh
                r = ik(s[0], s[1], a.hand[0], a.hand[1], UPPER, FORE, a.bend === undefined ? 1 : a.bend)
                arms.push([s[0], s[1], r[0], r[1], r[2], r[3]])
            }
            return { head: head, headR: o.headR || 3, neck: neck, hip: hip, legs: legs, arms: arms, lying: o.lying || 0, gownOpen: o.gownOpen === undefined ? 1 : o.gownOpen }
        }
        function standingLegs(fx0, fx1) {
            return [{ ankle: [fx0, G - 1], toe: [fx0 + 1.8, G], bend: -1 }, { ankle: [fx1, G - 1], toe: [fx1 + 1.8, G], bend: -1 }]
        }
        // cross-legged on the ground: shins crossed in front, knees out to the sides
        function crossedLegs() {
            return [{ ankle: [19.6, G - 0.8], toe: [21.2, G - 0.4], bend: 1 }, { ankle: [16.4, G - 0.8], toe: [14.8, G - 0.4], bend: -1 }]
        }
        function braced(hipX, leanRad, neckLen) {                      // hip, neck and head leaning into the wind (to the left)
            var hip = [hipX, 19.3]
            var neck = [hip[0] - Math.sin(leanRad) * neckLen, hip[1] - Math.cos(leanRad) * neckLen]
            var head = [neck[0] - Math.sin(leanRad) * 4.4, neck[1] - Math.cos(leanRad) * 4.4]
            return { hip: hip, neck: neck, head: head }
        }

        // ------------------------------------------------------------------
        // Marvin: skeleton builder (24 x 20 box, ground at y = 20, facing left)
        // ------------------------------------------------------------------
        // The film's Marvin: a massive sphere on a short compact body, stubby
        // legs, arms hanging past the knees. The BBC one is lankier.
        var MUP = solid ? 2.4 : 3.4, MLOW = solid ? 2.3 : 3.2, AUP = 4.6, ALOW = 4.4, NECK = solid ? 5.6 : 5.2
        var MHIPY = solid ? 15.3 : 13.4, MTOPY = solid ? 10.6 : 7.2, MHEADR = solid ? 5.3 : 4.2, MHANDY = solid ? 19.0 : 16.6
        // o: { hip, top, tilt, legs: [{foot, bend?} x2], arms: [{hand, bend?} x2], flip?, dx?, dy?, shake? }
        function marvin(o) {
            var legs = [], arms = [], i, r
            for (i = 0; i < 2; i++) {
                var l = o.legs[i], hx = o.hip[0] + (i === 0 ? -1.3 : 1.3)
                r = ik(hx, o.hip[1], l.foot[0], l.foot[1], MUP, MLOW, l.bend === undefined ? 1 : l.bend)
                legs.push([hx, o.hip[1], r[0], r[1], r[2], r[3]])
            }
            for (i = 0; i < 2; i++) {
                var a = o.arms[i], sx = o.top[0] + (i === 0 ? -3.3 : 3.3), sy = o.top[1] + 0.8
                r = ik(sx, sy, a.hand[0], a.hand[1], AUP, ALOW, a.bend === undefined ? -1 : a.bend)
                arms.push([sx, sy, r[0], r[1], r[2], r[3]])
            }
            var tilt = (o.tilt || 0) + (solid ? 0.07 * Math.sin(ip * 0.3) : 0)   // the film Marvin's bored, slow sideways roll
            var head = [o.top[0] - Math.sin(tilt) * NECK + (o.shake || 0), o.top[1] - Math.cos(tilt) * NECK + turnDip]
            return { hip: o.hip, top: o.top, tilt: tilt, head: head, headR: MHEADR, legs: legs, arms: arms,
                     flip: o.flip === undefined ? 1 : o.flip, dx: o.dx || 0, dy: o.dy || 0, perk: 0 }
        }
        function marvinStand() {
            return { hip: [12, MHIPY], top: [12, MTOPY], tilt: 0.75,
                     legs: [{ foot: [10.4, 20], bend: 1 }, { foot: [13.6, 20], bend: 1 }],
                     arms: [{ hand: [8.2, MHANDY], bend: -1 }, { hand: [15.8, MHANDY + 0.2], bend: -1 }] }
        }
        // trudge: small alternating steps, the body barely bobbing, the head down, the arms swinging a little
        function marvinTrudge(ph) {
            var o = marvinStand(), s = Math.sin(ph)
            o.hip = [12, MHIPY - Math.abs(Math.cos(ph)) * 0.3]
            o.top = [12.2, MTOPY - Math.abs(Math.cos(ph)) * 0.3]
            o.tilt = 0.72
            var stride = solid ? 1.2 : 1.7, step = solid ? 0.8 : 1.1
            o.legs = [{ foot: [12 - s * stride, 20 - Math.max(0, s) * step], bend: 1 }, { foot: [12 + s * stride, 20 - Math.max(0, -s) * step], bend: 1 }]
            o.arms = [{ hand: [8.2 + s * 0.9, MHANDY], bend: -1 }, { hand: [15.8 - s * 0.9, MHANDY + 0.2], bend: -1 }]
            o.flip = -1
            return o
        }
        function leanMarvin(o, l) {                                    // lean the body into the wind (to -x in the box)
            o.top = [o.top[0] - l * 2, o.top[1] + l * 0.3]
            return o
        }

        // ------------------------------------------------------------------
        // Scene poses
        // ------------------------------------------------------------------
        // Arthur: returns { pose, towel, tent, cup, cupHand, stream, shiver, puff, drops }
        function arthurIdle() {
            var r = { towel: "shoulder", tent: null, cup: 0, cupHand: 1, stream: 0, shiver: 0, puff: -1, drops: null }
            var hip, neck, head, legs, arms, o, gownOpen = 1, lying = 0
            switch (pose) {
            case "calm": {
                var sway = Math.sin(t * 1.1) * 0.35
                var glance = win(st % 9, 5, 7, 0.5) * 1.3                 // a look over at Marvin
                hip = [18, 19]; neck = [18.2 + sway, 9.6]; head = [18.5 + sway + glance, 5]
                legs = standingLegs(15.4, 20.4)
                arms = [ { hand: [15.6, 17.4], bend: 1 }, { hand: [20.8, 18.6], bend: 1 } ]   // one hand in the gown pocket
                break
            }
            case "sunny": {
                hip = [18, G - 3.2]; neck = [18.2, G - 12.6]; head = [18.6, G - 16]
                legs = crossedLegs()
                var u6 = st % 6, raise = win(u6, 1.3, 2.8, 0.5)             // the cup comes up to the mouth and back to the lap
                arms = [ { hand: [14.6, G - 5.6], bend: 1 },
                         { hand: mix([21.6, G - 6.4], [20.2, G - 13.2], raise), bend: 1 } ]
                head[0] += raise * 0.4; head[1] += raise * 0.5
                r.cup = 1; r.cupHand = 1
                r.towel = "shoulders"                                   // draped over both shoulders while he sits
                break
            }
            case "night": {
                var br = Math.sin(t * Math.PI * 2 / 3.4) * 0.3            // breathing
                lying = 1
                hip = [15.5, G - 2.4]; neck = [24, G - 2.9 + br]; head = [27.6, G - 3.4 + br]
                legs = [ { ankle: [6.4, G - 1.4], toe: [5, G - 0.6], bend: 1 }, { ankle: [7.4, G - 0.9], toe: [6, G - 0.2], bend: 1 } ]
                arms = [ { hand: [20.4, G - 4.8 + br], bend: 1 }, { hand: [21.2, G - 3.6 + br], bend: -1 } ]   // wrapped in the gown
                r.towel = "pillow"
                break
            }
            case "rain":
            case "thunder": {
                hip = [18, 19 + 2.6 * hunch]; neck = [18.3, 9.8 + 3 * hunch]; head = [18.7, 5.3 + 3.4 * hunch]
                legs = standingLegs(15, 21)
                var spread = (5.6 - 2.4 * hunch) * Math.max(0.15, self.towelProgress)
                var hy = head[1] - 3.2 + 2.6 * hunch
                arms = [ { hand: [neck[0] - spread, hy], bend: -1 }, { hand: [neck[0] + spread, hy], bend: 1 } ]
                var drops = canopyDrops()
                r.towel = "tent"
                r.tent = { peak: 6.5 * self.towelProgress * (1 - 0.5 * hunch), recoil: drops.recoil, stream: 0, shift: 0 }
                r.drops = drops
                break
            }
            case "storm": {
                var lean = 0.26 + 0.2 * gust
                o = braced(17.2, lean, 9.8)
                hip = o.hip; neck = o.neck; head = o.head
                neck[1] += hunch * 1.2; head[1] += hunch * 1.4
                legs = [ { ankle: [13.3, G - 1], toe: [15, G], bend: -1 }, { ankle: [22.6, G - 1], toe: [24.3, G], bend: -1 } ]
                var sp2 = 4.6 * Math.max(0.15, self.towelProgress), hy2 = head[1] - 3 + gust * 0.6
                arms = [ { hand: [neck[0] - sp2 + 1.2 * gust, hy2], bend: -1 }, { hand: [neck[0] + sp2 + 1.8 * gust, hy2 + 0.8 * gust], bend: 1 } ]
                r.towel = "tent"
                r.tent = { peak: 3.5 * self.towelProgress, recoil: 0, stream: 0.6 + 0.6 * gust, shift: 2.5 * gust }
                break
            }
            case "windy": {
                var lean2 = 0.2 + 0.14 * gust
                o = braced(17.5, lean2, 9.8)
                hip = o.hip; neck = o.neck; head = o.head
                legs = [ { ankle: [14, G - 1], toe: [15.7, G], bend: -1 }, { ankle: [21.5, G - 1], toe: [23.2, G], bend: -1 } ]
                arms = [ { hand: [neck[0] + 0.4, neck[1] + 4.4], bend: 1 },               // holding the gown shut
                         { hand: [neck[0] + 5.2, neck[1] + 2.4 - gust], bend: 1 } ]       // the towel out in the wind
                r.towel = "stream"
                r.stream = 0.5 + 0.5 * gust
                gownOpen = 0.3
                break
            }
            case "snow": {
                var cyc = st % 5, idx = Math.floor(st / 5)
                var raise2 = win(cyc, 0.5, 1.4, 0.4)
                var sip = self.holdingMug && idx % 2 === 0
                hip = [18, 19]; neck = [18, 9.5]; head = [18, 5]
                legs = standingLegs(15.3, 20.3)
                var hug0 = [21, 15], hug1 = [15.2, 15.5]
                if (sip) { arms = [ { hand: hug0, bend: 1 }, { hand: mix(hug1, [20.6, 7.4], raise2), bend: 1 } ]; r.cup = 1; r.cupHand = 1 }
                else { arms = [ { hand: mix(hug0, [19.6, 7.6], raise2), bend: 1 }, { hand: mix(hug1, [20.6, 8], raise2), bend: 1 } ]; r.puff = clamp01((cyc - 0.9) / 1.2) }
                r.towel = "scarf"
                r.shiver = win(t % 1.8, 1.25, 1.55, 0.05) * Math.sin(t * 75)
                gownOpen = 0
                break
            }
            default:
                hip = [18, 19]; neck = [18, 9.5]; head = [18, 5]
                legs = standingLegs(15.5, 20.5)
                arms = [ { hand: [17, 18], bend: 1 }, { hand: [19, 18], bend: 1 } ]
            }
            r.pose = human({ hip: hip, neck: neck, head: head, legs: legs, arms: arms, gownOpen: gownOpen, lying: lying })
            return r
        }
        // Rain: drops landing on the towel tent, each with a recoil and a splash
        function canopyDrops() {
            var slots = [ { x: -0.35, off: 0 }, { x: 0.4, off: 0.65 } ], period = 1.4, recoil = 0, list = []
            for (var i = 0; i < slots.length; i++) {
                var u = (st + slots[i].off) % period
                var fall = u / 0.5
                if (fall < 1) list.push({ x: slots[i].x, fall: fall, splash: 0 })
                else {
                    var sp = (u - 0.5) / 0.28
                    recoil += 0.8 * Math.exp(-(u - 0.5) * 11)
                    if (sp < 1) list.push({ x: slots[i].x, fall: 1, splash: sp })
                }
            }
            return { list: list, recoil: Math.min(0.8, recoil) }
        }
        function arthurWalk() {
            var wp = self.walkPhase, s = Math.sin(wp)
            var bob = -Math.abs(s) * 0.6, sway = s * 0.3
            var windLean = self.gusty ? fs : 0                         // leaning into the wind whichever way they go
            var hip = [18 - sway, 19 + bob]
            var neck = [18.6 + sway - 2.2 * windLean, 9.6 + bob]
            var head = [19 - 3.2 * windLean, 5 + bob + Math.sin(wp * 2 - 0.4) * 0.7]
            var legs = []
            for (var i = 0; i < 2; i++) {
                var p = wp + i * Math.PI, ss = Math.sin(p), cc = Math.cos(p)
                var lift = Math.max(0, ss) * 2.8                       // foot clears the ground on the forward swing
                var heel = Math.max(0, -ss) * Math.max(0, cc) * 1.3    // heel rises, rolling onto the toe at push-off
                var fx = 18 + ss * 2.5
                legs.push({ ankle: [fx, G - 1 - lift - heel], toe: [fx + 1.7, G - lift + (lift > 0.2 ? 0.4 : 0)], bend: -1 })
            }
            var arms = [ { hand: [18.3 - s * 2.2, 17.3], bend: 1 }, { hand: [18.3 + s * 2.2, 17.3], bend: 1 } ]
            return human({ hip: hip, neck: neck, head: head, legs: legs, arms: arms, gownOpen: pose === "snow" ? 0 : 1 })
        }

        // Marvin: returns the pose spec for the scene, plus the LED level and the snow cap
        function marvinIdle() {
            var o = marvinStand(), r = { led: 0, cap: 0, capSlide: -1, pings: null }
            switch (pose) {
            case "calm": {                                             // a sigh every 7 s: the head lifts a little, then sinks lower than before
                var u7 = st % 7
                var lift = win(u7, 1.2, 2.2, 0.6), sink = win(u7, 2.8, 4.6, 0.8)
                o.tilt = 0.6 - 0.3 * lift + 0.28 * sink
                o.top = [12, MTOPY + 0.4 * sink]
                break
            }
            case "sunny":                                              // staring at the floor
                o.tilt = 0.85
                break
            case "night": {                                            // standby: rigid, arms straight down, the LED blinking
                o.tilt = 0.08
                o.arms = [{ hand: [8.5, MHANDY - 0.4], bend: -1 }, { hand: [15.5, MHANDY - 0.4], bend: -1 }]
                var u2 = t % 2.2
                r.led = u2 < 0.14 ? 1 : u2 < 0.3 ? 0.35 : 0.08
                break
            }
            case "rain":
                o.tilt = 0.78
                r.pings = domePings()
                break
            case "thunder": {
                var scr = 1 - win(startle, 0.25, 2, 0.2)               // a flinch: shoulders up, head down harder
                o.tilt = 0.7 + 0.25 * scr
                o.top = [12, MTOPY - 0.6 * scr]
                r.led = spark
                break
            }
            case "storm":
                o.tilt = 0.7 + 0.1 * gust
                o = leanMarvin(o, 0.5 + 0.5 * gust)
                break
            case "windy":
                o.tilt = 0.62
                o = leanMarvin(o, 0.3 + 0.4 * gust)
                break
            case "snow": {                                             // snow piles on the dome over 6 s, then slides off
                var u8 = st % 8
                o.tilt = 0.55
                r.cap = u8 < 6 ? u8 / 6 : 0
                r.capSlide = u8 >= 6 && u8 < 6.6 ? (u8 - 6) / 0.6 : -1
                break
            }
            default:
                o.tilt = 0.7
            }
            r.o = o
            return r
        }
        // Rain: drops landing on Marvin's dome, pinging off as two short ticks
        function domePings() {
            var list = [], slots = [0, 0.8], period = 1.6
            for (var i = 0; i < slots.length; i++) {
                var u = (st + slots[i]) % period, fall = u / 0.55
                if (fall < 1) list.push({ fall: fall, splash: 0, side: i === 0 ? -1 : 1 })
                else { var sp = (u - 0.55) / 0.3; if (sp < 1) list.push({ fall: 1, splash: sp, side: i === 0 ? -1 : 1 }) }
            }
            return list
        }

        // ------------------------------------------------------------------
        // Overlays: hover, micro-actions, the Guide
        // ------------------------------------------------------------------
        var tp = self.tricking ? self.trickProgress : -1
        var mp = self.microPhase, ma = self.activeMicroAction
        var micro = ma !== "none" ? win(mp, 0.25, 0.75, 0.25) : 0
        var wave = self.waveBlend

        // Arthur
        var ai = arthurIdle(), ap = ai.pose
        var sh = [ap.neck[0], ap.neck[1] + 1]
        function reArm(i, hand, bend) {
            var r = ik(sh[0], sh[1], hand[0], hand[1], UPPER, FORE, bend === undefined ? 1 : bend)
            return [sh[0], sh[1], r[0], r[1], r[2], r[3]]
        }
        var cupHand = ai.cup > 0 ? ai.cupHand : (self.holdingMug && pose === "calm" ? 1 : -1)
        if (self.holdingMug && pose === "calm") ap.arms[1] = reArm(1, [23.2, sh[1] + 4.6])   // calm: the front hand cradles the cup
        var towelAlpha = 1, frontTowel = 0, shakeTowel = 0, guideUp = 0, holo = 0
        if (wave > 0) {                                                // a friendly wave from the free arm, out past the head
            var wi = pose === "sunny" || pose === "rain" || pose === "thunder" || pose === "windy" ? 0 : 1
            var wa = (wi === 0 ? -1 : 1) * (50 + Math.sin(ip * 4) * 20) * Math.PI / 180
            ap.arms[wi] = mix(ap.arms[wi], reArm(wi, [sh[0] + Math.sin(wa) * 8, sh[1] - Math.cos(wa) * 8], wi === 0 ? -1 : 1), wave)
            if (ai.towel === "tent") towelAlpha = 1 - wave * 0.6      // the tent sags while he waves with one hand
        }
        if (ma === "towelCheck") {                                     // the towel off the shoulder, held out in front and looked at
            frontTowel = micro
            ap.arms[0] = mix(ap.arms[0], reArm(0, [sh[0] - 3.6, sh[1] + 4.6], -1), micro)
            ap.arms[1] = mix(ap.arms[1], reArm(1, [sh[0] + 3.6, sh[1] + 4.6], 1), micro)
            ap.head = [ap.head[0] + 0.6 * micro, ap.head[1] + 1.2 * micro]
        } else if (ma === "shakeOff") {                                // one end of the scarf-towel shaken out
            shakeTowel = micro
            ap.arms[1] = mix(ap.arms[1], reArm(1, [sh[0] + 4.6 + Math.sin(t * 28) * 0.8 * micro, sh[1] + 2.4], 1), micro)
        }
        if (tp >= 0) {                                                 // reach into the gown, hold the Guide up high
            var pk = win(tp, 0.06, 0.14, 0.06), up = win(tp, 0.24, 0.84, 0.1)
            var guideHand = mix([ap.hip[0] + 1.4, ap.hip[1] - 1.2], [sh[0] + 2.4, sh[1] - 8.4], up)
            var gw = Math.max(pk, up) * (1 - win(tp, 0.95, 2, 0.05))
            ap.arms[1] = mix(ap.arms[1], reArm(1, guideHand, 1), gw)
            guideUp = up
            holo = win(tp, 0.32, 0.8, 0.08)
            ap.head[1] -= up * 0.8                                    // looking up at it
            if (ai.towel === "tent") towelAlpha = Math.min(towelAlpha, 1 - up * 0.7)
        }
        var aw = arthurWalk()
        var ab = mix(ap, aw, b)
        var shiver = (ai.shiver || 0) * idleW

        // Marvin
        var mi = marvinIdle(), ms = mi.o
        var led = mi.led
        if (ma === "sigh") {                                           // the head sinks and a weary "..." rises
            ms.tilt += 0.32 * micro
            ms.top = [ms.top[0], ms.top[1] + 0.5 * micro]
        } else if (ma === "diagnostic") {                              // a look up, the LED blinking a pattern
            ms.tilt -= 0.3 * micro
            led = Math.max(led, micro * ((Math.floor(mp * 14) % 3) === 0 ? 1 : 0.15))
        }
        if (tp >= 0) {                                                 // a slow head shake, two full swings
            var sk = win(tp, 0.34, 0.82, 0.1)
            ms.shake = Math.sin((tp - 0.34) / 0.48 * Math.PI * 4) * 1.6 * sk
            ms.tilt = mix(ms.tilt, 0.45, sk)
        }
        ms.tilt = mix(ms.tilt, 0.05, wave)                             // looks up at the viewer when hovered
        var mp0 = marvin(ms)
        mp0.perk = wave
        var mw = marvinTrudge(self.walkPhase)
        var mmix = mix(mp0, marvin(mw), b)

        // ------------------------------------------------------------------
        // Draw: props, Marvin, Arthur, towel, effects
        // ------------------------------------------------------------------
        ctx.globalAlpha = 1
        pen(green)
        if (ps > 0.01) {
            if (self.campfire) campfire(pose === "snow" ? 27 : (self.idlePersonX + 8 + self.idleMarvinX) / 2, ps)
            if (pose === "rain") {                                     // a flat puddle between the two
                Ring(27, G - 1.2, 6 * ps, 1.1 * ps, 0.8, 0.35)
            }
        }

        drawMarvin(mmix, mi, led)
        drawArthur(ab, ai, shiver)

        // effects, in card coordinates
        pen(green)
        if (pose === "night") zees()
        if (pose === "snow" && ai.puff > 0 && ai.puff < 1) {          // a cloud of breath
            var pu = ai.puff
            Ring(ab.head[0] + dx + 3.5 + pu * 1.5, ab.head[1] + 0.5 - pu * 4, 0.5 + 2 * pu, 0.4 + 1.6 * pu, 0.7, 0.5 * (1 - pu) * idleW)
        }
        if (ma === "sigh" && micro > 0) {                              // "..." drifting up from Marvin
            var hp = marvinCard(mmix, mmix.head[0], mmix.head[1] - 5.5)
            Txt("...", hp[0], hp[1] - mp * 3, 5, micro * 0.9)
        }
        if (ma === "shakeOff" && shakeTowel > 0) {                     // snow shaken out of the towel
            for (var fk = 0; fk < 5; fk++) {
                var born = 0.3 + fk * 0.06, age = (mp - born) * 2.2
                if (age > 0 && age < 0.7) {
                    var hx2 = ab.arms[1][4] + dx + 3, hy3 = ab.arms[1][5]
                    ctx.globalAlpha = (1 - age / 0.7) * shakeTowel
                    D(hx2 + 3 + fk * 1.2 + age * 6, hy3 + 1 + age * 14 + fk * 0.4, 0.6)
                    ctx.globalAlpha = 1
                }
            }
        }
        if (holo > 0) {                                                // the Guide's hologram: a glowing "42"
            var gh = [ab.arms[1][4] + dx, ab.arms[1][5]]
            var flick = 0.8 + 0.2 * Math.sin(t * 37) * Math.sin(t * 11)
            var hy4 = gh[1] - 5 - holo * 2
            Halo(gh[0] + 0.5, hy4 - 2, 9, 0.35 * holo * flick, amber)
            pen(amber)
            Txt("42", gh[0] + 0.5, hy4 + 0.5, 6.5 + holo, holo * flick)
            ctx.globalAlpha = holo * 0.7
            Rect(gh[0] - 5, hy4 - 6.5, 11, 8.5, 0.7)                   // the projection frame
            ctx.globalAlpha = holo * 0.5
            L(gh[0] - 1.2, gh[1] - 1.5, gh[0] - 5, hy4 + 2, 0.6); L(gh[0] + 1.2, gh[1] - 1.5, gh[0] + 6, hy4 + 2, 0.6)   // beams
            ctx.globalAlpha = 1
            pen(green)
        }
        ctx.globalAlpha = 1

        // ------------------------------------------------------------------
        // Draw helpers
        // ------------------------------------------------------------------
        function marvinCard(d, x, y) {                                 // Marvin box coords -> card coords (flip, offsets)
            return [self.marvinX + d.dx + 12 + (x - 12) * d.flip, G - 20 + d.dy + y]
        }
        function drawArthur(p, extras, jitter) {
            map = function (x, y) { return sceneMap(x + dx + jitter, y) }
            var neck = p.neck, hip = p.hip, head = p.head, i
            var sw = solid ? 1.45 : 1                                  // silhouettes: limbs become thick trouser legs and sleeves
            pen(green)
            for (i = 0; i < 2; i++) {
                var lg = p.legs[i]
                L(lg[0], lg[1], lg[2], lg[3], 2.0 * sw); L(lg[2], lg[3], lg[4], lg[5], 1.9 * sw); L(lg[4], lg[5], lg[6], lg[7], 1.6 * sw)
                if (solid) {                                           // pyjama stripe down each trouser leg
                    pen(white); ctx.globalAlpha = 0.4
                    L(lg[0], lg[1] + 0.6, lg[2], lg[3], 0.6); L(lg[2], lg[3], lg[4], lg[5] - 0.4, 0.6)
                    ctx.globalAlpha = 1; pen(green)
                }
            }
            // the dressing gown
            if (p.lying > 0.5) {                                       // wrapped round him like a blanket
                var blanket = [[hip[0] - 1.5, hip[1] - 2.8], [neck[0] + 0.5, neck[1] - 2.9], [neck[0] + 0.8, neck[1] + 2.4], [hip[0] - 1.5, hip[1] + 2.6]]
                if (solid) Fill(blanket, green)
                Pl(blanket, 1.3, undefined, true)
                if (solid) { pen(white); ctx.globalAlpha = 0.4 }
                L(hip[0] + 3, hip[1] - 2.8, hip[0] + 3.5, hip[1] + 2.6, 1.1)   // a fold
                ctx.globalAlpha = 1; pen(green)
            } else {
                var gap = 1.2 * p.gownOpen, rip = Math.sin(self.walkPhase * 2) * 0.5 * b
                var hemY = hip[1] + 3.6, flare = 4.4
                // the lapels flap: a slow flutter standing, more on the move and in the wind
                var flap = Math.sin(ip * 2.4 + 0.5) * 0.3 * (0.3 + b) + (self.gusty ? 0.9 * gust : 0)
                // two panels hanging from the shoulders, parted at the front when untied
                var panelL = [[neck[0] - 2.8, neck[1] + 0.9], [hip[0] - flare - rip, hemY], [hip[0] - gap, hemY + 0.3], [neck[0] - 0.2 - gap * 0.4, neck[1] + 2.2]]
                var panelR = [[neck[0] + 2.8, neck[1] + 0.9], [hip[0] + flare + rip, hemY], [hip[0] + gap, hemY + 0.3], [neck[0] + 0.2 + gap * 0.4, neck[1] + 2.2]]
                if (solid) { Fill(panelL, green); Fill(panelR, green) }
                Pl(panelL, 1.3, undefined, true)
                Pl(panelR, 1.3, undefined, true)
                // collar fold: two thicker lapels meeting in a V, their tips lifting with the flap
                if (solid) { pen(white); ctx.globalAlpha = 0.55 }
                L(neck[0] - 2.6, neck[1] + 0.9, neck[0] - 0.3 - flap, neck[1] + 3.6 - flap * 0.6, solid ? 1.0 : 1.8)
                L(neck[0] + 2.6, neck[1] + 0.9, neck[0] + 0.3 + flap, neck[1] + 3.6 - flap * 0.6, solid ? 1.0 : 1.8)
                ctx.globalAlpha = 1; pen(green)
                // the belt, untied and dangling from one hip
                var bw = Math.sin(ip * 2.5 + 1) * 0.6 + (self.gusty ? 1.5 + gust : 0) + b * 1.2
                Q(hip[0] + 2.4, hip[1] + 0.4, hip[0] + 2.8 + bw, hip[1] + 2.6, hip[0] + 2.4 + bw * 1.6, hip[1] + 4.8, 1.0 * sw)
            }
            for (i = 0; i < 2; i++) {
                var ar = p.arms[i]
                L(ar[0], ar[1], ar[2], ar[3], 1.9 * sw); L(ar[2], ar[3], ar[4], ar[5], 1.8 * sw)
            }
            // head, with a few tufts of messy hair
            leadX = lead
            if (solid) D(head[0], head[1], p.headR)
            else Ring(head[0], head[1], p.headR, p.headR, 1.5)
            var hw2 = solid ? 1.7 : 1.2, mess = Math.sin(ip * 3.1) * 0.25
            if (p.lying > 0.5) {
                L(head[0] + 1.6, head[1] - 2.6, head[0] + 2.6, head[1] - 4.2, hw2); L(head[0] + 2.9, head[1] - 1, head[0] + 4.6, head[1] - 1.8, hw2)
            } else {
                L(head[0] - 1.8, head[1] - 2.5, head[0] - 2.6 - mess, head[1] - 4.2, hw2)
                L(head[0], head[1] - 3, head[0] + 0.3 + mess, head[1] - 4.7, hw2)
                L(head[0] + 1.8, head[1] - 2.5, head[0] + 2.8, head[1] - 3.9 + mess, hw2)
                if (solid) L(head[0] - 0.9, head[1] - 2.9, head[0] - 1.3 + mess, head[1] - 4.5, hw2)
            }
            leadX = 0
            // the towel
            pen(amber)
            var tw = extras.towel
            var shoulderA = (tw === "shoulder" ? idleW : 0) * (1 - frontTowel)
            var armA = b * (1 - frontTowel)
            if (shoulderA > 0.01) {                                    // over one shoulder, the loose end down the back
                var sPts = [[neck[0] - 0.8, neck[1] + 0.6], [neck[0] - 1.9, neck[1] + 3.4], [neck[0] - 2.9, neck[1] + 7.2], [neck[0] - 2.6, neck[1] + 10.4]]
                if (solid) {
                    Fill([[neck[0] - 0.2, neck[1] + 0.2], [neck[0] - 1.6, neck[1] + 0.9], [neck[0] - 4.0, neck[1] + 10.6], [neck[0] - 1.6, neck[1] + 10.2]], amber, 0.95 * shoulderA)
                } else Pl(sPts, 2.2, 0.95 * shoulderA)
            }
            if (armA > 0.01) {                                         // on the move: rolled up and tucked under the back arm
                var bob2 = Math.sin(self.walkPhase * 2) * 0.3
                var bun = [[neck[0] - 4.4, neck[1] + 3.2 + bob2], [neck[0] - 1.6, neck[1] + 3.0 + bob2], [neck[0] - 1.2, neck[1] + 6.4 + bob2], [neck[0] - 4.6, neck[1] + 6.6 + bob2]]
                if (solid) Fill(bun, amber, 0.95 * armA)
                else { Pl(bun, 1.4, 0.95 * armA, true); ctx.globalAlpha = 0.6 * armA; L(bun[0][0] + 0.4, (bun[0][1] + bun[3][1]) / 2, bun[1][0] - 0.4, (bun[1][1] + bun[2][1]) / 2, 0.8); ctx.globalAlpha = 1 }
            }
            if (tw === "shoulders" && idleW > 0.01) {                  // sitting: draped over both shoulders, an end down each side
                var dl = [[neck[0] - 3.4, neck[1] + 0.4], [neck[0] - 1.0, neck[1] + 0.9], [neck[0] - 1.6, neck[1] + 7.4], [neck[0] - 4.4, neck[1] + 7.0]]
                var dr = [[neck[0] + 3.4, neck[1] + 0.4], [neck[0] + 1.0, neck[1] + 0.9], [neck[0] + 1.6, neck[1] + 7.4], [neck[0] + 4.4, neck[1] + 7.0]]
                if (solid) { Fill(dl, amber, 0.95 * idleW); Fill(dr, amber, 0.95 * idleW) }
                else { Pl(dl, 1.4, 0.95 * idleW, true); Pl(dr, 1.4, 0.95 * idleW, true) }
                ctx.globalAlpha = 0.95 * idleW
                Q(neck[0] - 3.2, neck[1] + 0.6, neck[0], neck[1] - 0.6, neck[0] + 3.2, neck[1] + 0.6, solid ? 2.6 : 1.8)   // the band behind the neck
                ctx.globalAlpha = 1
            }
            if (frontTowel > 0.01) {                                   // held out between both hands, hanging like a sheet
                var h0 = [p.arms[0][4], p.arms[0][5]], h1 = [p.arms[1][4], p.arms[1][5]]
                var sheet = [[h0[0], h0[1]], [h1[0], h1[1]], [h1[0] + 0.3, h1[1] + 6.5], [h0[0] - 0.3, h0[1] + 6.5]]
                if (solid) Fill(sheet, amber, 0.95 * frontTowel)
                else Pl(sheet, 1.4, 0.95 * frontTowel, true)
                ctx.globalAlpha = 0.6 * frontTowel
                if (solid) pen(white)
                L(h0[0] + 1, h0[1] + 3.2, h1[0] - 1, h1[1] + 3.2, 0.8)
                ctx.globalAlpha = 1; pen(amber)
            }
            if (tw === "tent" && idleW * towelAlpha > 0.01 && extras.tent) {   // stretched overhead between the hands
                var te = extras.tent, a0 = [p.arms[0][4], p.arms[0][5]], a1 = [p.arms[1][4], p.arms[1][5]]
                var al = idleW * towelAlpha
                var midx = (a0[0] + a1[0]) / 2 + te.shift, midy = Math.min(a0[1], a1[1]) - te.peak * 2 + te.recoil
                ctx.globalAlpha = al
                if (solid) {                                           // a filled canopy: the curve sampled, the edges hanging past the hands
                    var cpts = [[a0[0] - 0.8, a0[1] + 3.6], [a0[0], a0[1]]]
                    for (var ci = 1; ci < 8; ci++) { var cu = ci / 8, cu1 = 1 - cu; cpts.push([cu1 * cu1 * a0[0] + 2 * cu1 * cu * midx + cu * cu * a1[0], cu1 * cu1 * a0[1] + 2 * cu1 * cu * midy + cu * cu * a1[1]]) }
                    cpts.push([a1[0], a1[1]]); cpts.push([a1[0] + 0.8, a1[1] + 3.6])
                    cpts.push([a1[0] - 0.6, a1[1] + 2.0]); cpts.push([a0[0] + 0.6, a0[1] + 2.0])
                    Fill(cpts, amber, al)
                }
                Q(a0[0], a0[1], midx, midy, a1[0], a1[1], 2.2)
                L(a0[0], a0[1], a0[0] - 0.8, a0[1] + 3.6, 1.6); L(a1[0], a1[1], a1[0] + 0.8, a1[1] + 3.6, 1.6)   // the edges hanging past the hands
                if (te.stream > 0) ribbon(a1[0] + 0.6, a1[1] + 1, 9, 1, 1.5 + 2.5 * te.stream, 1.8, al, 7)   // the loose end whipping downwind
                ctx.globalAlpha = 1
                if (extras.drops) {                                    // drops landing on it, each with a splash
                    pen(green)
                    var list = extras.drops.list
                    for (var di = 0; di < list.length; di++) {
                        var d = list[di], lx = lerp(a0[0], a1[0], 0.5 + d.x), ly = lerp(a0[1], a1[1], 0.5 + d.x) - te.peak * 2 * (1 - 4 * d.x * d.x) * 0.75 + te.recoil
                        ctx.globalAlpha = al
                        if (d.fall < 1) D(lx, ly - 8 + 8 * d.fall * d.fall, 0.9)
                        else {
                            var s3 = d.splash
                            ctx.globalAlpha = al * (1 - s3)
                            D(lx - 2 * s3, ly - 2.5 * s3 + s3 * s3 * 3, 0.55); D(lx + 2.2 * s3, ly - 2.2 * s3 + s3 * s3 * 3, 0.55); D(lx + 0.3 * s3, ly - 3 * s3 + s3 * s3 * 3.5, 0.5)
                        }
                    }
                    ctx.globalAlpha = 1
                    pen(amber)
                }
            }
            if (tw === "ground" && ps > 0.01) {                        // laid out flat under him
                if (solid) Fill([[hip[0] - 9 * ps, G - 1.9], [hip[0] + 9 * ps, G - 1.9], [hip[0] + 9 * ps, G - 0.2], [hip[0] - 9 * ps, G - 0.2]], amber)
                else { Rect(hip[0] - 9 * ps, G - 1.9, 18 * ps, 1.7, 1.2); L(hip[0] - 7 * ps, G - 1.1, hip[0] + 7 * ps, G - 1.1, 0.6) }
            }
            if (tw === "pillow" && ps > 0.01) {                        // rolled up under his head
                if (solid) { var pp = map(head[0] + 1.2, G - 1.5); ctx.beginPath(); ctx.ellipse(pp[0] - 2.6 * ps * xs, pp[1] - 1.4 * ps, 5.2 * ps * xs, 2.8 * ps); ctx.fill() }
                else { Ring(head[0] + 1.2, G - 1.5, 2.6 * ps, 1.4 * ps, 1.4); Arc(head[0] + 1.2, G - 1.5, 1.2 * ps, Math.PI * 0.2, Math.PI * 1.6, 0.8) }
            }
            if (tw === "scarf") {                                      // wrapped round his neck
                if (solid) { var sp = map(neck[0], neck[1] + 1.4); ctx.beginPath(); ctx.ellipse(sp[0] - 4.2 * xs, sp[1] - 1.6, 8.4 * xs, 3.2); ctx.fill() }
                else Ring(neck[0], neck[1] + 1.4, 4.2, 1.6, 2.0, 0.95)
                if (shakeTowel > 0.01) ribbon(p.arms[1][4], p.arms[1][5], 6, 1, 2.6 * shakeTowel, 2, 0.95 * shakeTowel, 18)
                else L(neck[0] + 3.4, neck[1] + 2.2, neck[0] + 4.4, neck[1] + 6.4, 2.0)   // the loose end
            }
            if (tw === "stream" && idleW > 0.01) {                     // streaming from the hand, downwind
                ribbon(p.arms[1][4], p.arms[1][5], 14, 1, 2 + 2.5 * extras.stream, solid ? 3.0 : 2.0, 0.95 * idleW, 4.5)
            }
            // a cup of tea, resting on the hand
            if ((extras.cup > 0 || self.holdingMug) && cupHand >= 0 && ps > 0.01) {
                pen(solid ? white : green)
                cup(p.arms[cupHand][4], p.arms[cupHand][5], ps)
            }
            if (guideUp > 0.01) {                                      // the Guide: a small slab with an amber mark
                var ghx = p.arms[1][4], ghy = p.arms[1][5]
                if (solid) Fill([[ghx - 1.4, ghy - 3.6], [ghx + 1.4, ghy - 3.6], [ghx + 1.4, ghy], [ghx - 1.4, ghy]], navy)
                pen(green)
                Rect(ghx - 1.4, ghy - 3.6, 2.8, 3.6, 1.1)
                pen(amber); D(ghx, ghy - 1.8, 0.5)
            }
            pen(green)
            map = sceneMap
        }
        function cup(hx, hy, s) {                                      // 3 x 3 cup resting on the hand, a handle, two wisps of steam
            if (solid) { Fill([[hx - 1.5 * s, hy - 3.2 * s], [hx + 1.5 * s, hy - 3.2 * s], [hx + 1.5 * s, hy], [hx - 1.5 * s, hy]], white); pen(green) }
            Rect(hx - 1.5 * s, hy - 3.2 * s, 3 * s, 3.2 * s, 1.0)
            Arc(hx + 1.6 * s, hy - 1.6 * s, 1.0 * s, -Math.PI / 2, Math.PI / 2, 0.9)
            for (var w = -1; w <= 1; w += 2) {
                for (var k = 0; k < 4; k++) {                          // each wisp rises 4 px and fades out
                    ctx.globalAlpha = 0.7 * (1 - k / 4)
                    L(hx + (w * 0.7 + Math.sin(k * 1.3 + ip * 1.3 + w) * 0.6) * s, hy - (3.8 + k) * s,
                      hx + (w * 0.7 + Math.sin((k + 1) * 1.3 + ip * 1.3 + w) * 0.6) * s, hy - (4.8 + k) * s, 0.8)
                }
            }
            ctx.globalAlpha = 1
        }
        function drawMarvin(d, extras, ledLevel) {
            var bx = self.marvinX + d.dx, by = G - 20 + d.dy
            map = function (x, y) { return sceneMap(bx + 12 + (x - 12) * d.flip, by + y) }
            var savedXs = xs
            xs = Math.max(afs * Math.abs(d.flip), 0.5)
            pen(green)
            var top = d.top, hip = d.hip, i
            var hw = Math.max(3.2 * xs, 1.8)
            var body = [[top[0] - hw, top[1]], [top[0] + hw, top[1]], [hip[0] + hw * 0.9, hip[1]], [hip[0] - hw * 0.9, hip[1]]]
            var head = d.head, r = d.headR, tilt = d.tilt
            var nx = -Math.sin(tilt), ny = -Math.cos(tilt)             // unit vector up the neck
            function hl(lx, ly) {                                      // head-local -> box: +x is the back, the front (-x) dips with the tilt
                var c = Math.cos(tilt), s = Math.sin(tilt)
                return [head[0] + lx * c + ly * s, head[1] - lx * s + ly * c]
            }
            if (solid) {
                // the film's Marvin: a short navy body and stubby limbs under a
                // massive, perfectly spherical white head with a tiny visor slit
                Fill(body, navy); pen(green); Pl(body, 1.0, undefined, true)
                pen(navy)
                for (i = 0; i < 2; i++) {                              // legs: short and thick, flat feet
                    var lg2 = d.legs[i]
                    L(lg2[0], lg2[1], lg2[2], lg2[3], 2.6); L(lg2[2], lg2[3], lg2[4], lg2[5], 2.4)
                    L(lg2[4], lg2[5], lg2[4] - 2.4, lg2[5], 2.2)
                }
                for (i = 0; i < 2; i++) {                              // arms: long, past the knees, a round hand
                    var ar2 = d.arms[i]
                    L(ar2[0], ar2[1], ar2[2], ar2[3], 2.2); L(ar2[2], ar2[3], ar2[4], ar2[5], 2.0)
                    D(ar2[4], ar2[5] + 0.6, 1.05)
                }
                leadX = lead
                pen(white); D(head[0], head[1], r)                       // the dome, sitting on the shoulders
                pen(green); Ring(head[0], head[1], r, r, 1.2)
                leadX = 0
                // the tiny visor slit: level whatever the head's tilt, on the front of the dome
                var slitY = head[1] - 0.4 + Math.sin(tilt) * 1.2
                L(head[0] - 3.2, slitY, head[0] - 0.8, slitY, 1.3)
                pen(amber)
                ctx.globalAlpha = Math.min(1, 0.6 + 0.4 * d.perk)
                D(head[0] - 2.0, slitY, 0.42)                              // a pinpoint of eye light in the slit
                ctx.globalAlpha = 1
            } else {
                // body: a box from the shoulder line to the hips, a panel on the chest
                Pl(body, 1.5, undefined, true)
                L(top[0] - hw * 0.55, top[1] + 2, top[0] + hw * 0.55, top[1] + 2, 0.8)
                L(top[0] - hw * 0.55, top[1] + 3.4, top[0] + hw * 0.1, top[1] + 3.4, 0.8)
                // legs: thigh, shin, a flat foot pointing forward
                for (i = 0; i < 2; i++) {
                    var lg = d.legs[i]
                    L(lg[0], lg[1], lg[2], lg[3], 1.8); L(lg[2], lg[3], lg[4], lg[5], 1.6)
                    L(lg[4], lg[5], lg[4] - 2.2, lg[5], 1.6)
                }
                // arms: long, dangling past the hips, a small hand
                for (i = 0; i < 2; i++) {
                    var ar = d.arms[i]
                    L(ar[0], ar[1], ar[2], ar[3], 1.6); L(ar[2], ar[3], ar[4], ar[5], 1.5)
                    Ring(ar[4], ar[5] + 0.6, 0.8, 0.8, 1.0)
                }
                // neck and the oversized head, in a frame rotated by the tilt
                L(top[0], top[1], head[0] - nx * (r - 0.4), head[1] - ny * (r - 0.4), 1.8)
                leadX = lead
                Ring(head[0], head[1], r, r, 1.5)
                leadX = 0
                var v0 = hl(-3.4, -0.5), v1 = hl(2.5, 0.8)             // the sloped visor slit
                L(v0[0], v0[1], v1[0], v1[1], 1.6)
                var g0 = hl(-2.6, 2.3), g1 = hl(-1.2, 2.5)             // a small grille
                L(g0[0], g0[1], g1[0], g1[1], 0.8)
                var g2 = hl(-2.5, 3.1), g3 = hl(-1.3, 3.3); L(g2[0], g2[1], g3[0], g3[1], 0.8)
                pen(amber)
                var e0 = hl(-2.7, -0.3), e1 = hl(-1.0, 0.1)            // the eye, a glow along the visor
                ctx.globalAlpha = Math.min(1, 0.55 + 0.45 * d.perk + 0.3 * Math.max(0, Math.sin(ip * 0.7)))
                L(e0[0], e0[1], e1[0], e1[1], 1.0)
                ctx.globalAlpha = 1
            }
            if (ledLevel > 0.01) {                                     // the diagnostic LED on top
                var lp = hl(0.6, -r - 0.9)
                ctx.globalAlpha = ledLevel
                D(lp[0], lp[1], 0.7)
                if (ledLevel > 0.5) Halo(lp[0], lp[1], 3.5, 0.5 * ledLevel, amber)
                ctx.globalAlpha = 1
            }
            if (spark > 0.01 && pose === "thunder") {                  // static off the dome
                var sp0 = hl(0.8, -r - 0.4)
                ctx.globalAlpha = spark
                Pl([[sp0[0], sp0[1]], [sp0[0] + 1.2, sp0[1] - 1.8], [sp0[0] + 0.2, sp0[1] - 2.2], [sp0[0] + 1.6, sp0[1] - 4.4]], 1.0)
                Pl([[sp0[0] - 0.6, sp0[1] - 0.6], [sp0[0] - 1.8, sp0[1] - 2.0], [sp0[0] - 0.9, sp0[1] - 2.3], [sp0[0] - 2.2, sp0[1] - 3.8]], 0.8)
                ctx.globalAlpha = 1
            }
            pen(green)
            if (extras.cap > 0.01) {                                   // snow settling on the dome
                var pts = [], ca = extras.cap
                for (i = 0; i <= 8; i++) {
                    var an = Math.PI * (1.18 + 0.64 * i / 8) - tilt
                    pts.push([head[0] + Math.cos(an) * (r + 0.6 + ca * 0.8), head[1] + Math.sin(an) * (r + 0.6 + ca * 0.8)])
                }
                Pl(pts, 1.2 + ca * 1.2, 0.9)
            }
            if (extras.capSlide >= 0) {                                // ... and sliding off the front
                var cs = extras.capSlide, sp1 = hl(-r - 0.4 - cs * 1.5, -1.5 + cs * 9)
                ctx.globalAlpha = 1 - cs
                D(sp1[0], sp1[1], 1.3 - cs * 0.6)
                ctx.globalAlpha = 1
            }
            if (extras.pings && idleW > 0.01) {                        // drops pinging off the dome
                ctx.globalAlpha = idleW
                for (i = 0; i < extras.pings.length; i++) {
                    var pg = extras.pings[i], top2 = hl(pg.side * 1.4, -r)
                    if (pg.fall < 1) D(top2[0], top2[1] - 9 + 9 * pg.fall * pg.fall, 0.85)
                    else {
                        var s2 = pg.splash
                        ctx.globalAlpha = idleW * (1 - s2)
                        L(top2[0], top2[1], top2[0] + pg.side * (1 + 2.4 * s2), top2[1] - 2.2 * s2 + s2 * s2 * 2.6, 0.8)
                        L(top2[0], top2[1], top2[0] - pg.side * 0.8 * s2, top2[1] - 2.6 * s2 + s2 * s2 * 2.2, 0.7)
                        ctx.globalAlpha = idleW
                    }
                }
                ctx.globalAlpha = 1
            }
            xs = savedXs
            map = sceneMap
        }
        function zees() {                                              // three z's drifting up an S-curve, growing and fading
            var ox = ab.head[0] + dx + 2, oy = ab.head[1] - 4
            for (var i = 0; i < 3; i++) {
                var zu = ((st + i * 0.9) % 2.7) / 2.7
                var al = (zu < 0.15 ? zu / 0.15 : 1 - (zu - 0.15) / 0.85) * ps
                Txt("z", ox + Math.sin(zu * Math.PI * 2) * 3 + zu * 4, oy - zu * 13, 3 + 3 * zu, al)
            }
        }
        function campfire(x, s) {                                      // three logs, two flickering flames, a warm glow
            Halo(x, G - 2, 11 * s, 0.14 + Math.sin(ip * 1.5) * 0.03, amber)
            L(x - 3 * s, G - 0.8 * s, x + 3 * s, G - 0.8 * s, 1.4)
            L(x - 3 * s, G - 0.8 * s, x + 0.6 * s, G - 5.2 * s, 1.4)
            L(x + 3 * s, G - 0.8 * s, x - 0.6 * s, G - 5.2 * s, 1.4)
            pen(amber)
            function flame(fx, fy, w, h) {
                Pl([[fx - w / 2, fy], [fx + Math.sin(ip * 2.5 + fx) * 0.4 * s, fy - h], [fx + w / 2, fy]], 1.0)
            }
            flame(x - 0.8 * s, G - 2.2 * s, 2.4 * s, 4 * s * (1 + Math.sin(ip * 3.5) * 0.3))
            flame(x + 1.2 * s, G - 2.6 * s, 1.8 * s, 3 * s * (1 + Math.sin(ip * 4.5 + 2) * 0.3))
            pen(green)
        }
    }

    Component.onCompleted: { renderedScene = targetScene; dirty() }
}
