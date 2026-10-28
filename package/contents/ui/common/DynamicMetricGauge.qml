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
// `value` is the main reading (0..1), drawn solid in front; `secondary`
// (0..1, below 0 for none) a translucent wash behind it, like a temperature.
// The owner keeps the colours and alert animations; `glow` haloes the track.
Item {
    id: gauge

    property QtObject theme
    property real value: 0
    property real secondary: -1
    property color fillColor: theme.gaugeUsage.a > 0 ? theme.gaugeUsage : theme.high
    property color secondaryColor: theme.gaugeTemp.a > 0 ? theme.gaugeTemp : theme.mid
    property real secondaryOpacity: 0.35
    property color trackColor: theme.gaugeTrack.a > 0 ? theme.gaugeTrack : theme.tint(0.12)
    // a skin's own fill is outlined in its gauge edge colour
    property bool outlined: theme.gaugeUsage.a > 0
    property color edgeColor: theme.gaugeEdge
    property real edgeWidth: theme.gaugeEdgeWidth
    property string shape: theme.skinned ? theme.gaugeShape : "segmented"
    property bool live: false               // the wave moves only while on screen
    property bool animateValue: false       // ease the continuous fill's width

    // segmented
    property int segments: 24
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
    readonly property int filled: Math.round(fraction * segments)
    readonly property int secondaryFilled: Math.round(secondaryFraction * segments)
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

    Loader {
        anchors.fill: parent
        sourceComponent: gauge.ascii ? asciiBar : gauge.shape === "segmented" ? blocks
                       : gauge.shape === "wavy" ? wave : bar
    }

    Component {
        id: blocks
        Row {
            spacing: gauge.spacing
            Repeater {
                model: gauge.segments
                Rectangle {   // one block: outline, secondary wash, fill
                    required property int index
                    readonly property bool on: index < gauge.filled
                    readonly property bool pulsing: index === gauge.pulseIndex
                    readonly property bool inset: gauge.blockStyle === "inset"
                    width: gauge.blockWidth > 0 ? gauge.blockWidth
                         : (gauge.width - gauge.spacing * (gauge.segments - 1)) / gauge.segments
                    height: gauge.height
                    radius: Math.min(gauge.blockRadius, height / 2)
                    color: inset || !on ? (pulsing ? Qt.rgba(gauge.fillColor.r, gauge.fillColor.g, gauge.fillColor.b, gauge.pulseOpacity) : "transparent")
                                        : gauge.fillColor
                    border.width: 1
                    border.color: on || pulsing ? (gauge.outlined ? gauge.edgeColor : gauge.fillColor) : gauge.blockTrack
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
                        color: gauge.fillColor
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
                model: gauge.segments
                Text {
                    required property int index
                    width: gauge.width / gauge.segments
                    height: gauge.height
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: index < gauge.filled ? "█" : index < gauge.secondaryFilled ? "▓" : "░"
                    // unlit cells are the same phosphor, dimmed, as on a real terminal
                    color: index < gauge.filled ? gauge.fillColor : index < gauge.secondaryFilled ? gauge.secondaryColor
                         : gauge.fillColor
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
                fillColor: gauge.fillColor
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
                ctx.fillStyle = gauge.fillColor
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
                ctx.strokeStyle = gauge.fillColor
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
}
