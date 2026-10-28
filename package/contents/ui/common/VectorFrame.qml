import QtQuick
import QtQuick.Effects

// The outer card of every Sub-Etha widget: cream paper with a flat offset
// shadow, or CRT black with a coordinate grid, raster scanlines and amber
// corner reticles. Grid, scanlines and reticles are left off while `plain`
// (by default the theme's minimal flag; a compact section sets it for its own
// card). Content goes inside, padded; the frame sizes to it.
//
// A skin sets the border, radius, shadow and hover fill through the theme.
// Its frame style replaces grid and reticles with its own ornament: a
// "handheld" chassis (HandheldChassis.qml), or a "bezel" with cut corners,
// L brackets and, on the frames that ask with `chassis`, BezelDecor.qml.
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
    readonly property real chamfer: theme.chamfer
    readonly property real shadowX: Math.max(0, theme.shadowX)
    readonly property real shadowY: Math.max(0, theme.shadowY)
    implicitHeight: inner.childrenRect.height + padding * 2 + shadowY
                  + (handheld ? body.stripHeight : bezel ? decor.footerHeight : 0)

    Item {   // flat offset shadow (light), blurred when the skin asks
        visible: frame.theme.flatShadow
        x: frame.shadowX; y: frame.shadowY
        width: surface.width; height: surface.height
        layer.enabled: frame.theme.shadowBlur > 0
        layer.effect: MultiEffect { blurEnabled: true; blur: frame.theme.shadowBlur; blurMax: 24; autoPaddingEnabled: true }
        Rectangle {
            visible: frame.chamfer === 0
            anchors.fill: parent
            radius: surface.radius
            color: frame.theme.shadow
        }
        BezelShape {
            visible: frame.chamfer > 0
            anchors.fill: parent
            chamfer: frame.chamfer
            fillColor: frame.theme.shadow
        }
    }

    HoverHandler { id: hover; enabled: frame.theme.skinned }
    property color fill: hover.hovered ? theme.cardHover : theme.bg
    Behavior on fill { ColorAnimation { duration: 120 } }
    BezelShape {
        visible: frame.chamfer > 0
        anchors.fill: surface
        chamfer: frame.chamfer
        fillColor: frame.fill
        strokeColor: frame.theme.border
        strokeWidth: frame.theme.borderWidth
    }
    Rectangle {
        id: surface
        anchors { fill: parent; rightMargin: frame.shadowX; bottomMargin: frame.shadowY }
        radius: frame.chamfer > 0 ? 0 : frame.theme.outerRadius
        color: frame.chamfer > 0 ? "transparent" : frame.fill
        border.width: frame.chamfer > 0 ? 0 : frame.theme.borderWidth
        border.color: frame.theme.border

        // Tiled textures uploaded once, not painted: a 24px coordinate grid and
        // a 1px raster line every 2px. Inset past the rounded or cut corners so
        // the textures never poke out of them.
        readonly property real textureInset: Math.max(2, radius * 0.3, frame.chamfer)
        Image {
            visible: !frame.plain && !frame.theme.frame
            anchors { fill: parent; margins: surface.textureInset }
            source: Qt.resolvedUrl(frame.theme.dark ? "grid-dark.svg" : "grid-light.svg")
            sourceSize: Qt.size(24, 24)
            fillMode: Image.Tile
            smooth: false
            opacity: frame.theme.dark ? 0.05 : 0.06
        }
        Image {
            visible: frame.theme.dark && !frame.plain
            anchors { fill: parent; margins: surface.textureInset }
            source: Qt.resolvedUrl("scanlines.svg")
            sourceSize: Qt.size(4, 2)
            fillMode: Image.Tile
            smooth: false
            opacity: frame.theme.scanlineOpacity
        }

        // L-shaped corner marks: the Guide's targeting reticles, or a bezel
        // skin's brackets (only on the two uncut corners when chamfered).
        readonly property color bracket: frame.theme.frame ? frame.theme.frame.brackets || "transparent"
                                       : frame.theme.dark ? frame.theme.amber : frame.theme.ink
        Repeater {
            model: frame.plain || (frame.theme.frame && !frame.theme.frame.brackets) ? 0 : 4
            Item {
                required property int index
                readonly property bool atRight: index % 2 === 1
                readonly property bool atBottom: index >= 2
                readonly property bool cut: frame.chamfer > 0 && atRight !== atBottom
                readonly property real inset: frame.theme.frame ? 5 : 9
                visible: !cut
                width: frame.theme.frame ? 11 : 9; height: width
                x: atRight ? surface.width - width - inset : inset
                y: atBottom ? surface.height - height - inset : inset
                Rectangle {   // horizontal arm
                    width: parent.width; height: 1.5
                    y: parent.atBottom ? parent.height - height : 0
                    color: surface.bracket
                }
                Rectangle {   // vertical arm
                    width: 1.5; height: parent.height
                    x: parent.atRight ? parent.width - width : 0
                    color: surface.bracket
                }
            }
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
