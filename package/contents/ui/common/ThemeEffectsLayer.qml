import QtQuick

// The screen effects a theme asks for (SubEthaTheme.fx), laid over a frame's
// face: a CRT raster, phosphor decay (a refresh beam fading behind it and a
// curved-tube vignette, shaders/phosphor.frag), L corner brackets and a
// glass pane's specular sheen. Each is a Loader, so an effect the theme
// leaves off costs nothing; a skin gets only what its `features` block
// turns on. Owners that draw their own brackets pass brackets: false.
Item {
    id: fxLayer

    property QtObject theme
    property bool plain: false            // a compact section: no effects at all
    property bool brackets: true
    property real radius: 0               // the frame's corner, so the sheen stays inside it
    property real scanlineOpacity: theme && theme.scanlineOpacity !== undefined ? theme.scanlineOpacity : 0.15
    property color bracketColor: theme ? theme.bracketColor : "transparent"
    property real bracketSize: 8
    property real bracketInset: 3
    property bool running: !!theme && !!theme.live
    readonly property var fx: theme && theme.fx ? theme.fx : ({})

    Loader {
        anchors.fill: parent
        active: !fxLayer.plain && !!fxLayer.fx.crtScanlines
        sourceComponent: Image {
            source: Qt.resolvedUrl("scanlines.svg")
            sourceSize: Qt.size(4, 2)
            fillMode: Image.Tile
            smooth: false
            asynchronous: true
            opacity: fxLayer.scanlineOpacity
        }
    }
    Loader {
        anchors.fill: parent
        active: !fxLayer.plain && !!fxLayer.fx.phosphorDecay
        sourceComponent: ShaderEffect {
            property real phase: 0
            property real strength: 1
            property color tint: fxLayer.theme ? fxLayer.theme.ink : "transparent"
            fragmentShader: Qt.resolvedUrl("shaders/phosphor.frag.qsb")
            NumberAnimation on phase {
                from: 0; to: 1; duration: 2500
                loops: Animation.Infinite
                running: fxLayer.running
            }
        }
    }
    Loader {
        anchors.fill: parent
        active: !fxLayer.plain && fxLayer.brackets && !!fxLayer.fx.cornerBrackets
        sourceComponent: Canvas {
            renderTarget: Canvas.FramebufferObject
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections { target: fxLayer; function onBracketColorChanged() { requestPaint() } }
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = fxLayer.bracketColor
                ctx.lineWidth = 1.5
                ctx.lineCap = "square"
                var i = fxLayer.bracketInset, s = fxLayer.bracketSize, w = width, h = height
                ctx.beginPath()
                ctx.moveTo(i, i + s); ctx.lineTo(i, i); ctx.lineTo(i + s, i)
                ctx.moveTo(w - i - s, i); ctx.lineTo(w - i, i); ctx.lineTo(w - i, i + s)
                ctx.moveTo(w - i, h - i - s); ctx.lineTo(w - i, h - i); ctx.lineTo(w - i - s, h - i)
                ctx.moveTo(i + s, h - i); ctx.lineTo(i, h - i); ctx.lineTo(i, h - i - s)
                ctx.stroke()
            }
        }
    }
    Loader {
        anchors.fill: parent
        active: !!fxLayer.fx.glassBlur
        sourceComponent: Item {
            Rectangle {   // frosted tint: lighter at the top, as glass catches the sky
                anchors.fill: parent
                radius: fxLayer.radius
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, fxLayer.theme && fxLayer.theme.dark ? 0.06 : 0.18) }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0) }
                    GradientStop { position: 1; color: Qt.rgba(1, 1, 1, fxLayer.theme && fxLayer.theme.dark ? 0.02 : 0.06) }
                }
            }
            Rectangle {   // the specular rim along the top edge
                x: Math.max(fxLayer.radius * 0.6, 6); y: 1
                width: parent.width - 2 * x
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0) }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, fxLayer.theme && fxLayer.theme.dark ? 0.35 : 0.8) }
                    GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
                }
            }
        }
    }
}
