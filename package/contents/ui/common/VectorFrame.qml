import QtQuick

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
// `chassis`, BezelDecor.qml.
Item {
    id: frame

    property QtObject theme
    property real padding: 14
    property bool plain: theme.minimal
    property bool chassis: false
    default property alias content: inner.data

    readonly property string style: theme.frame ? theme.frame.style : ""
    readonly property bool handheld: chassis && style === "handheld"
    readonly property bool bezel: chassis && style === "bezel"
    implicitHeight: inner.childrenRect.height + padding * 2 + Math.abs(theme.shadowY)
                  + (handheld ? body.stripHeight : bezel ? decor.footerHeight : 0)

    HoverHandler { id: hover; enabled: frame.theme.skinned }
    // Hovered, a skin's face lifts a shade toward its text colour rather than
    // turning into a card, so text chosen to read on `bg` still reads.
    property color fill: hover.hovered ? Qt.tint(theme.bg, Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.06))
                                       : theme.bg
    Behavior on fill { ColorAnimation { duration: 120 } }
    ThemeShapeContainer {
        id: shell
        anchors.fill: parent
        theme: frame.theme
        role: "card"
        fillColor: frame.fill
        // the Guide's targeting reticles, or a bezel skin's brackets
        cornerBrackets: !frame.plain && (frame.theme.cornerBrackets || borderStyle === "tech-brackets")
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
            visible: !frame.plain && frame.theme.skinned && frame.theme.fx.grid
            anchors { fill: parent; margins: surface.textureInset }
            color: frame.theme.ink
            opacity: 0.07
        }
        ThemeEffectsLayer {   // raster, phosphor decay, glass sheen (the brackets are the shell's)
            anchors { fill: parent; margins: surface.textureInset }
            theme: frame.theme
            plain: frame.plain
            brackets: false
            radius: shell.radius
        }
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
        anchors { left: surface.left; right: surface.right; top: surface.top; margins: frame.padding }
    }
}
