import QtQuick
import QtQuick.Shapes

// One gauge, drawn the way the theme's gaugeShape asks (skins.js
// parseGeometry). Every bar in the suite goes through it, so a skin restyles
// all of them at once:
//   "segmented"  LED blocks; under a skin with CRT scanlines, ASCII cells
//                (█ lit, ▓ the secondary wash, ░ unlit) in the theme's mono font
//   "flat"       one square bar
//   "stadium"    a capsule with a specular highlight along the top
//   "chamfer"    one bar with its corners cut at 45°
//   "wavy"       a Material-style sine wave over a flat track, ending in a stop dot
//   "slot"       one bar in the theme's own gauge outline (ThemeShapeContainer
//                role "gauge"); the Guide's continuous meters
// A skin's controls.meter, when set, wins over the shape: the meter of the
// operating system it imitates (skins.js 2.1.0):
//   "bevel"   Windows XP: an inset 3D track (dark top-left edge, light
//             bottom-right) holding a glass fill with a white specular band;
//             glossy green blocks when the gaugeShape is segmented
//   "ascii"   a terminal's [||||||||....] drawn in the mono font
//   "gadget"  a Vista Sidebar meter: glossy capsules ramping green to orange
//   "angled"  slanted parallelogram blocks, like a battery's cells
// With controls.meterLabel the percentage sits at the right end.
// `value` is the main reading (0..1), drawn solid in front; `secondary`
// (0..1, below 0 for none) a translucent wash behind it, like a temperature.
// The owner keeps the colours and alert animations; `glow` haloes the track.
Item {
    id: gauge

    property QtObject theme
    property real value: 0
    property real secondary: -1
    property color fillColor: theme.gaugeUsage.a > 0 ? theme.gaugeUsage : theme.high
    // what it measures (cpu, gpu, memory, swap, disk, battery): the skin's
    // controls.meterColors fills it while the reading is `nominal`; a warning
    // or critical fill keeps its own colour
    property string metric: ""
    property bool nominal: true
    readonly property color skinFill: theme.meterColor(metric)
    readonly property color paint: nominal && skinFill.a > 0 ? skinFill : fillColor
    property color secondaryColor: theme.gaugeTemp.a > 0 ? theme.gaugeTemp : theme.mid
    property real secondaryOpacity: 0.35
    property color trackColor: theme.gaugeTrack.a > 0 ? theme.gaugeTrack : theme.tint(0.12)
    // a skin's own fill is outlined in its gauge edge colour
    property bool outlined: theme.gaugeUsage.a > 0
    property color edgeColor: theme.gaugeEdge
    property real edgeWidth: theme.gaugeEdgeWidth
    property string shape: !theme.skinned ? "segmented" : theme.gaugeShape === "analog-dial" ? "stadium" : theme.gaugeShape
    property string meter: theme.skinned ? theme.meterStyle : ""
    property bool showLabel: theme.skinned && !!theme.controls.meterLabel && meter !== "ascii"
    function cc(key, fallback) { return theme.osColor("controls", key, fallback) }
    property bool live: false               // the wave moves only while on screen
    property bool animateValue: false       // ease the continuous fill's width

    // segmented
    property int segments: 24
    property bool themeSegments: true       // the skin's geometry.segments overrides `segments` on a stretched bar
    readonly property int blockCount: themeSegments && blockWidth <= 0 && theme.gaugeSegments > 0 ? theme.gaugeSegments : segments
    property string blockStyle: "solid"     // solid: lit blocks filled; inset: outline with a fill inside
    property real blockWidth: 0             // 0: the blocks share the width
    property real blockRadius: theme.skinned ? theme.gaugeBlockRadius : theme.dark ? 0 : 2
    property color blockTrack: theme.gaugeTrack.a > 0 ? theme.gaugeTrack : theme.tint(theme.dark ? 0.3 : 0.45)
    property real spacing: 2
    property int pulseIndex: -1             // one block half-lit, e.g. the next cell while charging
    property real pulseOpacity: 0

    // alert halo
    property bool glow: false
    property color glowColor: theme.critColor
    property real glowOpacity: 0.55

    readonly property real fraction: Math.max(0, Math.min(1, value))
    readonly property real secondaryFraction: secondary < 0 ? 0 : Math.max(0, Math.min(1, secondary))
    readonly property int filled: Math.round(fraction * blockCount)
    readonly property int secondaryFilled: Math.round(secondaryFraction * blockCount)
    readonly property bool ascii: shape === "segmented" && theme.skinned && theme.fx.crtScanlines
    readonly property bool continuous: shape !== "segmented" && shape !== "wavy"

    implicitWidth: 160
    implicitHeight: 8

    Rectangle {   // the alert halo around the track
        visible: gauge.glow
        anchors { fill: parent; margins: -2 }
        radius: gauge.shape === "stadium" || gauge.shape === "wavy" ? height / 2 : Math.min(height / 2, gauge.blockRadius + 2)
        color: "transparent"
        border { width: 2; color: gauge.glowColor }
        opacity: gauge.glowOpacity
    }

    Text {   // controls.meterLabel: the percentage at the right end
        id: label
        visible: gauge.showLabel
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: 34
        horizontalAlignment: Text.AlignRight
        text: Math.round(gauge.fraction * 100) + "%"
        color: gauge.theme.ink
        font { family: gauge.theme.sans; pixelSize: Math.max(9, Math.min(12, gauge.height + 2)) }
    }
    Loader {
        anchors { fill: parent; rightMargin: gauge.showLabel ? label.width + 4 : 0 }
        sourceComponent: gauge.meter === "bevel" ? bevelMeter : gauge.meter === "ascii" ? asciiMeter
                       : gauge.meter === "gadget" ? gadgetMeter : gauge.meter === "angled" ? angledMeter
                       : gauge.meter === "slime" ? slimeMeter
                       : gauge.meter === "candy" ? candyMeter
                       : gauge.ascii ? asciiBar : gauge.shape === "segmented" ? blocks
                       : gauge.shape === "wavy" ? wave : bar
    }

    Component {
        id: blocks
        Row {
            spacing: gauge.spacing
            Repeater {
                model: gauge.blockCount
                Rectangle {   // one block: outline, secondary wash, fill
                    required property int index
                    readonly property bool on: index < gauge.filled
                    readonly property bool pulsing: index === gauge.pulseIndex
                    readonly property bool inset: gauge.blockStyle === "inset"
                    width: gauge.blockWidth > 0 ? gauge.blockWidth
                         : (gauge.width - gauge.spacing * (gauge.blockCount - 1)) / gauge.blockCount
                    height: gauge.height
                    radius: Math.min(gauge.blockRadius, height / 2)
                    color: inset || !on ? (pulsing ? Qt.rgba(gauge.paint.r, gauge.paint.g, gauge.paint.b, gauge.pulseOpacity) : "transparent")
                                        : gauge.paint
                    border.width: 1
                    border.color: on || pulsing ? (gauge.outlined ? gauge.edgeColor : gauge.paint) : gauge.blockTrack
                    Rectangle {   // the secondary reading, behind
                        visible: index < gauge.secondaryFilled
                        anchors.fill: parent
                        radius: parent.radius
                        color: gauge.secondaryColor
                        opacity: gauge.secondaryOpacity
                    }
                    Rectangle {   // inset: the fill inside the outline; a skin's fill is the whole block
                        visible: parent.inset && parent.on
                        anchors { fill: parent; margins: gauge.outlined ? 0 : parent.height >= 7 ? 2 : 1 }
                        radius: gauge.outlined ? parent.radius : Math.min(1, parent.radius)
                        color: gauge.paint
                        border { width: gauge.outlined ? gauge.edgeWidth : 0; color: gauge.edgeColor }
                    }
                }
            }
        }
    }

    Component {
        id: asciiBar
        Row {
            Repeater {
                model: gauge.blockCount
                Text {
                    required property int index
                    width: gauge.width / gauge.blockCount
                    height: gauge.height
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: index < gauge.filled ? "█" : index < gauge.secondaryFilled ? "▓" : "░"
                    // unlit cells are the same phosphor, dimmed, as on a real terminal
                    color: index < gauge.filled ? gauge.paint : index < gauge.secondaryFilled ? gauge.secondaryColor
                         : gauge.paint
                    opacity: index < gauge.secondaryFilled ? 1 : 0.35
                    font { family: gauge.theme.mono; pixelSize: Math.max(8, gauge.height * 1.35) }
                    fontSizeMode: Text.VerticalFit
                    minimumPixelSize: 6
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    Component {
        id: bar
        Item {
            id: track
            readonly property string outlineShape: gauge.shape === "flat" ? "sharp" : gauge.shape === "slot"
                                                 ? gauge.theme.shapeOf("gauge") : gauge.shape
            readonly property real r: height / 2
            ThemeShapeContainer {
                anchors.fill: parent
                theme: gauge.theme
                role: "gauge"
                shapeType: track.outlineShape
                fillColor: gauge.trackColor
                strokeColor: gauge.theme.tint(0.45)
                strokeWidth: gauge.theme.gaugeTube ? 1.5 : 0
            }
            ThemeShapeContainer {
                visible: gauge.secondaryFraction > 0
                width: parent.width * gauge.secondaryFraction; height: parent.height
                theme: gauge.theme
                role: "gauge"
                shapeType: track.outlineShape
                fillColor: gauge.secondaryColor
                strokeWidth: 0
                opacity: gauge.secondaryOpacity
            }
            ThemeShapeContainer {
                visible: gauge.fraction > 0
                width: Math.max(height, parent.width * gauge.fraction); height: parent.height
                theme: gauge.theme
                role: "gauge"
                shapeType: track.outlineShape
                fillColor: gauge.paint
                strokeColor: gauge.edgeColor
                strokeWidth: gauge.outlined ? gauge.edgeWidth : 0
                Behavior on width { enabled: gauge.animateValue; NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
            Rectangle {   // stadium: the specular highlight; a "tube" skin's glass
                visible: gauge.theme.gaugeTube || (gauge.theme.skinned && track.outlineShape === "stadium")
                x: track.r; y: Math.max(1, parent.height * 0.12)
                width: Math.max(0, parent.width - track.r * 2); height: Math.max(1, parent.height * 0.18)
                radius: height / 2
                color: "white"
                opacity: gauge.theme.gaugeTube ? 0.35 : 0.28
            }
            Repeater {   // tube: graduation marks
                model: gauge.theme.gaugeTube ? 9 : 0
                Rectangle {
                    required property int index
                    x: track.width * (index + 1) / 10; y: track.height - height - 1
                    width: 1; height: index % 2 === 0 ? track.height * 0.45 : track.height * 0.25
                    color: gauge.theme.tint(0.5)
                }
            }
        }
    }

    Component {
        id: wave
        Canvas {
            id: canvas
            property real phase: 0
            renderStrategy: Canvas.Cooperative
            NumberAnimation on phase {
                from: 0; to: Math.PI * 2; duration: 1600
                loops: Animation.Infinite
                running: gauge.live && gauge.fraction > 0
            }
            onPhaseChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections {
                target: gauge
                function onFractionChanged() { canvas.requestPaint() }
                function onSecondaryFractionChanged() { canvas.requestPaint() }
                function onFillColorChanged() { canvas.requestPaint() }
                function onTrackColorChanged() { canvas.requestPaint() }
                function onSecondaryColorChanged() { canvas.requestPaint() }
            }
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var w = width, h = height, mid = h / 2
                var line = Math.max(2, h * 0.38), amp = Math.max(1, (h - line) / 2)
                var gap = line * 1.2                                   // between the wave's end and the track
                var end = w * gauge.fraction
                ctx.lineCap = "round"
                ctx.lineWidth = line
                // the track: from past the wave to the end, with a stop dot
                ctx.strokeStyle = gauge.trackColor
                ctx.beginPath(); ctx.moveTo(Math.min(w - line / 2, end + gap), mid); ctx.lineTo(w - line / 2, mid)
                if (end + gap < w - line / 2) ctx.stroke()
                ctx.fillStyle = gauge.paint
                ctx.beginPath(); ctx.arc(w - line / 2, mid, line / 4, 0, Math.PI * 2); ctx.fill()
                if (gauge.secondaryFraction > 0) {                     // the wash, flat behind the wave
                    ctx.globalAlpha = gauge.secondaryOpacity
                    ctx.strokeStyle = gauge.secondaryColor
                    ctx.lineWidth = h
                    ctx.lineCap = "butt"
                    ctx.beginPath(); ctx.moveTo(0, mid); ctx.lineTo(w * gauge.secondaryFraction, mid); ctx.stroke()
                    ctx.globalAlpha = 1
                    ctx.lineWidth = line
                    ctx.lineCap = "round"
                }
                if (end <= line / 2) return
                ctx.strokeStyle = gauge.paint
                ctx.beginPath()
                var k = Math.PI * 2 / Math.max(12, h * 2.6)            // one wave every ~2.6 heights
                for (var x = line / 2; x <= end - line / 2 + 0.5; x += 1) {
                    var y = mid + amp * Math.sin(x * k - canvas.phase)
                    if (x === line / 2) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                }
                ctx.stroke()
            }
        }
    }

    // ---- controls.meter: the OS's own meters ----
    // candy: Vista's jelly bar, a recessed capsule whose fill is split by a
    // crisp glare line; the skin's four stops for what it measures while
    // nominal (controls.meterStops), else the fill's colour split the same way
    readonly property var candyStops: {
        var s = nominal && skinFill.a > 0 ? theme.meterStops(metric) : null
        return s ? s : [Qt.lighter(paint, 1.35), paint, Qt.darker(paint, 1.45), Qt.darker(paint, 1.75)]
    }
    Component {
        id: candyMeter
        Rectangle {
            id: slot
            radius: height / 2
            color: gauge.cc("meterTrack", gauge.trackColor)
            border { width: 1; color: gauge.cc("meterInsetDark", Qt.rgba(0, 0, 0, 0.6)) }
            Rectangle {   // the secondary wash
                visible: gauge.secondary >= 0
                width: slot.width * Math.max(0, Math.min(1, gauge.secondary)); height: slot.height
                radius: Math.min(slot.radius, width / 2)
                color: gauge.secondaryColor
                opacity: gauge.secondaryOpacity
            }
            Rectangle {
                id: jelly
                visible: width > 1
                width: slot.width * Math.max(0, Math.min(1, gauge.value)); height: slot.height
                radius: Math.min(slot.radius, width / 2)
                gradient: Gradient {
                    GradientStop { position: 0; color: gauge.candyStops[0] }
                    GradientStop { position: 0.48; color: gauge.candyStops[1] }
                    GradientStop { position: 0.52; color: gauge.candyStops[2] }
                    GradientStop { position: 1; color: gauge.candyStops[3] }
                }
                Rectangle {   // the specular line along its top
                    anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 1
                              leftMargin: Math.min(jelly.radius, jelly.width / 2); rightMargin: anchors.leftMargin }
                    height: Math.min(2, slot.height / 4)
                    color: Qt.rgba(1, 1, 1, 0.55)
                }
            }
        }
    }
    Component {
        id: bevelMeter
        Item {
            id: bevel
            readonly property bool blocks: gauge.theme.gaugeShape === "segmented"
            // a meter's own colour (controls.meterColors) shaded the same way, else the skin's gradient
            readonly property bool ownFill: gauge.nominal && gauge.skinFill.a > 0
            readonly property color fillTop: ownFill ? Qt.lighter(gauge.skinFill, 1.45) : gauge.cc("meterFillTop", blocks ? "#8EE68E" : "#6299F0")
            readonly property color fillBottom: ownFill ? gauge.skinFill : gauge.cc("meterFillBottom", blocks ? "#25A225" : "#316AC5")
            readonly property color sheen: gauge.cc("meterSheen", "#FFFFFF")
            Rectangle { anchors.fill: parent; radius: 2; color: gauge.cc("meterInsetLight", "#FFFFFF") }
            Rectangle { width: parent.width - 1; height: parent.height - 1; radius: 2; color: gauge.cc("meterInsetDark", "#7F9DB9") }
            Rectangle {
                id: well
                x: 1; y: 1; width: parent.width - 2; height: parent.height - 2
                radius: 1
                color: gauge.cc("meterTrack", "#EBE8D7")
                clip: true
                Rectangle {   // the secondary reading, a wash behind
                    visible: gauge.secondaryFraction > 0
                    width: parent.width * gauge.secondaryFraction; height: parent.height
                    color: gauge.secondaryColor
                    opacity: gauge.secondaryOpacity
                }
                Item {   // the fill: one glass bar, or glossy blocks
                    x: 1; y: 1
                    width: Math.max(0, (parent.width - 2) * gauge.fraction); height: parent.height - 2
                    clip: true
                    Behavior on width { enabled: gauge.animateValue; NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    Rectangle {
                        visible: !bevel.blocks
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0; color: bevel.fillTop }
                            GradientStop { position: 1; color: bevel.fillBottom }
                        }
                    }
                    Row {
                        visible: bevel.blocks
                        spacing: 2
                        Repeater {
                            model: bevel.blocks ? Math.max(0, Math.ceil(well.width / 10)) : 0
                            Rectangle {
                                width: 8; height: well.height - 2
                                gradient: Gradient {
                                    GradientStop { position: 0; color: bevel.fillTop }
                                    GradientStop { position: 0.5; color: Qt.darker(bevel.fillTop, 1.05) }
                                    GradientStop { position: 1; color: bevel.fillBottom }
                                }
                            }
                        }
                    }
                    Rectangle {   // the specular band across the middle
                        y: parent.height * 0.22; width: parent.width; height: Math.max(1, parent.height * 0.24)
                        color: bevel.sheen
                        opacity: 0.45
                    }
                }
            }
        }
    }
    Component {
        id: asciiMeter
        Item {
            TextMetrics { id: cell; text: "|"; font: line.font }
            Text {
                id: line
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                readonly property string pct: gauge.theme.controls.meterLabel ? " " + Math.round(gauge.fraction * 100) + "%" : ""
                readonly property int cells: Math.max(4, Math.floor(parent.width / Math.max(1, cell.advanceWidth)) - 2 - pct.length)
                readonly property int lit: Math.round(gauge.fraction * cells)
                text: "[" + "|".repeat(lit) + ".".repeat(cells - lit) + "]" + pct
                color: gauge.paint
                font { family: gauge.theme.mono; pixelSize: Math.max(10, Math.min(14, gauge.height + 4)) }
                renderType: Text.NativeRendering
            }
        }
    }
    Component {
        id: gadgetMeter
        Row {
            id: capsules
            spacing: 2
            readonly property int n: Math.max(6, Math.min(gauge.blockCount, Math.floor(width / 9)))
            readonly property int lit: Math.round(gauge.fraction * n)
            Repeater {
                model: capsules.n
                Rectangle {
                    required property int index
                    readonly property real t: index / Math.max(1, capsules.n - 1)
                    readonly property color hue: t < 0.5 ? gauge.theme.mix(gauge.cc("meterFillTop", "#5CD65C"), "#F2D43C", t * 2)
                                                        : gauge.theme.mix("#F2D43C", gauge.cc("meterFillBottom", "#FF8C1A"), (t - 0.5) * 2)
                    readonly property bool on: index < capsules.lit
                    width: (capsules.width - capsules.spacing * (capsules.n - 1)) / capsules.n
                    height: gauge.height
                    // the row bows: the ends sit a pixel lower than the middle
                    y: Math.round(Math.pow(t * 2 - 1, 2) * Math.min(2, gauge.height * 0.2))
                    radius: Math.min(height / 2, width / 2)
                    color: on ? hue : gauge.cc("meterTrack", Qt.rgba(1, 1, 1, 0.12))
                    border { width: 1; color: on ? Qt.darker(hue, 1.3) : Qt.rgba(0, 0, 0, 0.35) }
                    Rectangle {   // gloss on the upper half
                        x: 1; y: 1; width: parent.width - 2; height: parent.height * 0.45
                        radius: parent.radius
                        color: "white"; opacity: parent.on ? 0.45 : 0.12
                    }
                }
            }
        }
    }
    Component {
        id: angledMeter
        Item {
            id: cells
            readonly property int n: Math.max(6, Math.min(gauge.blockCount, Math.floor(width / 9)))
            readonly property int lit: Math.round(gauge.fraction * n)
            readonly property real slant: Math.min(6, height * 0.6)
            readonly property real cw: (width - slant - 2 * (n - 1)) / n
            Repeater {
                model: cells.n
                Shape {
                    id: cellShape
                    required property int index
                    readonly property bool on: index < cells.lit
                    readonly property bool washed: !on && index < Math.round(gauge.secondaryFraction * cells.n)
                    x: index * (cells.cw + 2); width: cells.cw + cells.slant; height: cells.height
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeWidth: 1
                        strokeColor: cellShape.on ? gauge.paint : gauge.blockTrack
                        fillColor: cellShape.on ? gauge.paint : cellShape.washed ? Qt.rgba(gauge.secondaryColor.r, gauge.secondaryColor.g, gauge.secondaryColor.b, gauge.secondaryOpacity) : "transparent"
                        PathSvg { path: `M ${cells.slant} 0.5 H ${cells.cw + cells.slant - 0.5} L ${cells.cw - 0.5} ${cells.height - 0.5} H 0.5 Z` }
                    }
                }
            }
        }
    }
    Component {
        id: slimeMeter
        Item {   // a glass tube of ooze: a wobbling meniscus, now and then a drop
            id: tube
            readonly property color ooze: gauge.theme.frame && gauge.theme.frame.slime ? gauge.theme.frame.slime : gauge.paint
            readonly property real level: Math.max(0, Math.min(1, gauge.fraction)) * (width - 4)
            property real phase: 0
            NumberAnimation on phase { running: gauge.theme.live; from: 0; to: 2 * Math.PI; duration: 1800; loops: Animation.Infinite }
            Rectangle {   // the glass
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.08)
                border { width: 1.5; color: gauge.theme.border }
            }
            Rectangle {   // the ooze
                x: 2; y: 2; height: parent.height - 4
                width: tube.level
                radius: height / 2
                color: tube.ooze
                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuad } }
                Rectangle {   // the meniscus, a bulge that wobbles
                    visible: parent.width > 4
                    x: parent.width - width / 2 + Math.sin(tube.phase) * 1.2
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.height * (0.9 + 0.12 * Math.sin(tube.phase * 2)); height: parent.height
                    radius: height / 2
                    color: Qt.lighter(tube.ooze, 1.15)
                }
            }
            Rectangle {   // the glint on the glass
                x: height; y: 2; width: parent.width - height * 2; height: Math.max(1, parent.height * 0.2)
                radius: height / 2
                color: "white"; opacity: 0.35
            }
            Rectangle {   // the drop, falling from the tube's underside
                id: drop
                visible: tube.level > 8 && gauge.theme.live
                x: 2 + tube.level * 0.6; y: tube.height - 2
                width: 3; height: 4; radius: 1.5
                color: tube.ooze
                opacity: 0
                SequentialAnimation on y {
                    running: drop.visible; loops: Animation.Infinite
                    PauseAnimation { duration: 3200 }
                    ScriptAction { script: drop.opacity = 1 }
                    NumberAnimation { from: tube.height - 2; to: tube.height + 6; duration: 600; easing.type: Easing.InQuad }
                    ScriptAction { script: drop.opacity = 0 }
                }
            }
        }
    }
}
