import QtQuick

// The outer card of every Sub-Etha widget: cream paper with a flat offset
// shadow, or CRT black with a coordinate grid, raster scanlines and amber
// corner reticles. Grid, scanlines and reticles are left off while `plain`
// (by default the theme's minimal flag; a compact section sets it for its own
// card). Content goes inside, padded; the frame sizes to it.
//
// A skin sets the border, radius, shadow and hover fill through the theme;
// one with a "handheld" frame swaps grid and reticles for its own chassis
// (HandheldChassis.qml) on the frames that ask for it with `chassis`.
Item {
    id: frame

    property QtObject theme
    property real padding: 14
    property bool plain: theme.minimal
    property bool chassis: false
    default property alias content: inner.data

    readonly property bool handheld: chassis && !!theme.frame
    readonly property real shadowX: Math.max(0, theme.shadowX)
    readonly property real shadowY: Math.max(0, theme.shadowY)
    implicitHeight: inner.childrenRect.height + padding * 2 + shadowY + (handheld ? body.stripHeight : 0)

    Rectangle {   // flat offset shadow (light)
        visible: frame.theme.flatShadow
        x: frame.shadowX; y: frame.shadowY
        width: surface.width; height: surface.height
        radius: surface.radius
        color: frame.theme.shadow
    }

    HoverHandler { id: hover; enabled: frame.theme.skinned }
    Rectangle {
        id: surface
        anchors { fill: parent; rightMargin: frame.shadowX; bottomMargin: frame.shadowY }
        radius: frame.theme.outerRadius
        color: hover.hovered ? frame.theme.cardHover : frame.theme.bg
        Behavior on color { ColorAnimation { duration: 120 } }
        border.width: frame.theme.borderWidth
        border.color: frame.theme.border

        // Tiled textures uploaded once, not painted: a 24px coordinate grid and
        // a 1px raster line every 2px. Inset past the rounded corners so the
        // textures never poke out of them.
        Image {
            visible: !frame.plain && !frame.theme.frame
            anchors { fill: parent; margins: Math.max(2, surface.radius * 0.3) }
            source: Qt.resolvedUrl(frame.theme.dark ? "grid-dark.svg" : "grid-light.svg")
            sourceSize: Qt.size(24, 24)
            fillMode: Image.Tile
            smooth: false
            opacity: frame.theme.dark ? 0.05 : 0.06
        }
        Image {
            visible: frame.theme.dark && !frame.plain
            anchors { fill: parent; margins: Math.max(2, surface.radius * 0.3) }
            source: Qt.resolvedUrl("scanlines.svg")
            sourceSize: Qt.size(4, 2)
            fillMode: Image.Tile
            smooth: false
            opacity: 0.15
        }

        // L-shaped targeting reticles in the four corners.
        Repeater {
            model: frame.plain || frame.theme.frame ? 0 : 4
            Item {
                required property int index
                readonly property bool atRight: index % 2 === 1
                readonly property bool atBottom: index >= 2
                readonly property real inset: 9
                width: 9; height: 9
                x: atRight ? surface.width - width - inset : inset
                y: atBottom ? surface.height - height - inset : inset
                Rectangle {   // horizontal arm
                    width: parent.width; height: 1.5
                    y: parent.atBottom ? parent.height - height : 0
                    color: frame.theme.dark ? frame.theme.amber : frame.theme.ink
                }
                Rectangle {   // vertical arm
                    width: 1.5; height: parent.height
                    x: parent.atRight ? parent.width - width : 0
                    color: frame.theme.dark ? frame.theme.amber : frame.theme.ink
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

    Item {
        id: inner
        anchors { left: surface.left; right: surface.right; top: surface.top; margins: frame.padding }
    }
}
