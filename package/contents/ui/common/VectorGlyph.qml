import QtQuick
import QtQuick.Shapes

// A technical line-art glyph: an SVG path on a 24-unit grid, stroked in one
// colour with round caps and scaled to the item. A Shape renders once on the
// GPU; nothing repaints.
Item {
    id: glyph

    property string path: ""
    property color color: "black"
    property real strokeWidth: 1.6

    Shape {
        width: 24; height: 24
        anchors.centerIn: parent
        scale: Math.min(glyph.width, glyph.height) / 24
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: glyph.color
            strokeWidth: glyph.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: glyph.path }
        }
    }
}
