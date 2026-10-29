import QtQuick
import QtQuick.Shapes

// The outer card of every Sub-Etha widget: cream paper with a flat offset
// shadow, or CRT black with a coordinate grid, raster scanlines and amber
// corner reticles. Grid, scanlines and reticles are left off while `plain`
// (by default the theme's minimal flag; a compact section sets it for its own
// card). Content goes inside, padded; the frame sizes to it.
//
// The outline, border, corner marks and shadow are the theme's card geometry
// (a ThemeShapeContainer); a skin also sets the hover fill. Its frame style
// replaces the grid with its own ornament: a "handheld" chassis
// (HandheldChassis.qml), or a "bezel" with, on the frames that ask with
// `chassis`, BezelDecor.qml. A bitmap skin's sections.frame is drawn as the
// outline (SkinFrame), the content placed inside its insets.
Item {
    id: frame

    property QtObject theme
    property real padding: 14
    property bool plain: theme.minimal
    property bool chassis: false
    // A Win32 group (theme.groupBands): no outline, shadow or effects of its
    // own, the window's body showing through; GroupBand draws its title.
    property bool flat: false
    // A Vista gadget's gloss: a curved white sheen over this fraction of the
    // top, fading down (0: none).
    property real gloss: 0
    property color tint: "transparent"   // a skin's surface for this card (sections.tints)
    property bool active: false          // an open section: the border in the skin's borderActive, as on hover
    default property alias content: inner.data

    readonly property string style: theme.frame ? theme.frame.style : ""
    readonly property bool handheld: chassis && style === "handheld"
    readonly property bool bezel: chassis && style === "bezel"
    implicitHeight: inner.childrenRect.height
                  + (shell.framed ? shell.insetTop + shell.insetBottom : padding * 2 + Math.abs(theme.shadowY))
                  + (handheld ? body.stripHeight : bezel ? decor.footerHeight : 0)

    HoverHandler { id: hover; enabled: frame.theme.skinned }
    // Hovered, a skin's face lifts a shade toward its text colour rather than
    // turning into a card, so text chosen to read on `bg` still reads.
    property color fill: tint.a > 0 ? tint
                       : hover.hovered ? Qt.tint(theme.bg, Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.06))
                       : theme.bg
    Behavior on fill { ColorAnimation { duration: 120 } }
    ThemeShapeContainer {
        id: shell
        anchors.fill: parent
        theme: frame.theme
        role: "card"
        fillColor: frame.flat ? "transparent" : frame.fill
        frameSource: frame.flat ? "" : frame.theme.cardFrameSource
        strokeColor: frame.active || hover.hovered ? frame.theme.borderActive : frame.theme.border
        strokeWidth: frame.flat ? 0 : frame.theme.borderWidth
        shadowType: frame.flat ? "none" : frame.theme.shadowType
        // the Guide's targeting reticles, or a bezel skin's brackets
        cornerBrackets: !frame.plain && !frame.flat && (frame.theme.cornerBrackets || borderStyle === "tech-brackets")
        bracketSize: frame.theme.frame ? 11 : 9
        bracketInset: frame.theme.frame ? 5 : 9
    }
    Item {
        id: surface
        x: shell.face.x; y: shell.face.y
        width: shell.face.width; height: shell.face.height

        // Tiled textures uploaded once, not painted: a 24px coordinate grid and
        // a 1px raster line every 2px. Inset past the rounded or cut corners so
        // the textures never poke out of them.
        readonly property real textureInset: Math.max(2, shell.radius * 0.3, shell.cut)
        SkinTexture {   // carbon weave and the like, under the content
            visible: !frame.flat && !frame.theme.windowed
            anchors { fill: parent; margins: surface.textureInset }
            kind: frame.theme.fx.texture || ""
            color: frame.theme.ink
        }
        Image {
            visible: !frame.plain && !frame.theme.skinned && !frame.theme.frame
            anchors { fill: parent; margins: surface.textureInset }
            source: Qt.resolvedUrl(frame.theme.dark ? "grid-dark.svg" : "grid-light.svg")
            sourceSize: Qt.size(24, 24)
            fillMode: Image.Tile
            smooth: false
            opacity: frame.theme.dark ? 0.05 : 0.06
        }
        SkinGrid {   // a skin's grid is drawn in its own ink
            visible: !frame.plain && !frame.flat && frame.theme.skinned && frame.theme.fx.grid
            anchors { fill: parent; margins: surface.textureInset }
            color: frame.theme.ink
            opacity: 0.07
        }
        Shape {   // the gadget's gloss, its lower edge bowed
            id: glossShape
            visible: frame.gloss > 0
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            readonly property real r: Math.min(shell.radius, height / 2)
            readonly property real g: height * frame.gloss
            readonly property real w: width
            readonly property bool diagonal: !!frame.theme && !!frame.theme.skin && !!frame.theme.skin.sections
                                             && frame.theme.skin.sections.glossShape === "diagonal"
            ShapePath {
                strokeWidth: -1
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 0; y1: 0; x2: 0; y2: surface.height * frame.gloss
                    GradientStop { position: 0; color: frame.theme ? frame.theme.osColor("sections", "gloss", Qt.rgba(1, 1, 1, 0.32)) : Qt.rgba(1, 1, 1, 0.32) }
                    GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.02) }
                }
                PathSvg {
                    path: `M ${glossShape.r} 0 H ${glossShape.w - glossShape.r} Q ${glossShape.w} 0 ${glossShape.w} ${glossShape.r}`
                        + (glossShape.diagonal   // sections.glossShape "diagonal": high on the right, sweeping low on the left
                           ? ` V ${glossShape.g * 0.44} C ${glossShape.w * 0.65} ${glossShape.g * 0.93} ${glossShape.w * 0.25} ${glossShape.g * 0.27} 0 ${glossShape.g * 0.8}`
                           : ` V ${glossShape.g * 0.7} Q ${glossShape.w / 2} ${glossShape.g * 1.15} 0 ${glossShape.g}`)
                        + ` V ${glossShape.r} Q 0 0 ${glossShape.r} 0 Z`
                }
            }
        }
        ThemeEffectsLayer {   // raster, phosphor decay, glass sheen (the brackets are the shell's)
            anchors { fill: parent; margins: surface.textureInset }
            theme: frame.theme
            plain: frame.plain || frame.flat
            brackets: false
            radius: shell.radius
        }
    }

    SlimeDrips {   // ooze off the card's top edge (features.slimeDrips)
        visible: frame.theme.slimeDrips && !frame.flat && !frame.chassis
        anchors { left: surface.left; right: surface.right; top: surface.top; leftMargin: 10; rightMargin: 10 }
        color: frame.theme.slimeColor
        seed: Math.round(frame.width) % 97
        running: frame.theme.live
    }
    Screws {   // a skin's mounting screws (sections.screws), not on the chassis or a flat group
        visible: frame.theme.screws && !frame.flat && !frame.chassis
        anchors.fill: surface
        ink: frame.theme.border
    }
    HandheldChassis {
        id: body
        visible: frame.handheld
        anchors.fill: surface
        theme: frame.theme
    }
    BezelDecor {
        id: decor
        visible: frame.bezel
        anchors.fill: surface
        theme: frame.theme
    }

    Item {
        id: inner
        anchors {
            left: surface.left; right: surface.right; top: surface.top
            // a bitmap frame's content insets say where content starts
            leftMargin: shell.framed ? shell.insetLeft : frame.padding
            rightMargin: shell.framed ? shell.insetRight : frame.padding
            topMargin: shell.framed ? shell.insetTop : frame.padding
        }
    }
}
