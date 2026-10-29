import QtQuick
import QtQuick.Shapes

// A technical line-art glyph: an SVG path on a 24-unit grid, stroked in one
// colour with round caps and scaled to the item. A Shape renders once on the
// GPU; nothing repaints. A skin's own icon for the same thing (`source`, an
// image URL from theme.icon()) takes its place when there is one.
Item {
    id: glyph

    property string path: ""
    property color color: "black"
    property real strokeWidth: 1.6
    property string source: ""

    Image {
        visible: glyph.source !== ""
        anchors.fill: parent
        source: glyph.source
        sourceSize: Qt.size(Math.max(16, glyph.width * 2), Math.max(16, glyph.height * 2))
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
    Shape {
        visible: glyph.source === ""
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
