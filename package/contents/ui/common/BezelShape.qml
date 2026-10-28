import QtQuick
import QtQuick.Shapes

// A bezel skin's frame outline: a rectangle with its top-right and
// bottom-left corners cut at 45° by `chamfer` px, filled and stroked. The
// stroke sits inside the bounds.
Shape {
    id: bezel

    property real chamfer: 12
    property color fillColor: "transparent"
    property color strokeColor: "transparent"
    property real strokeWidth: 0

    readonly property real i: strokeWidth / 2
    readonly property real c: Math.min(chamfer, width / 2, height / 2)
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: bezel.fillColor
        strokeColor: bezel.strokeWidth > 0 ? bezel.strokeColor : "transparent"
        strokeWidth: bezel.strokeWidth
        joinStyle: ShapePath.MiterJoin
        startX: bezel.i; startY: bezel.i
        PathLine { x: bezel.width - bezel.c - bezel.i; y: bezel.i }
        PathLine { x: bezel.width - bezel.i; y: bezel.c + bezel.i }
        PathLine { x: bezel.width - bezel.i; y: bezel.height - bezel.i }
        PathLine { x: bezel.c + bezel.i; y: bezel.height - bezel.i }
        PathLine { x: bezel.i; y: bezel.height - bezel.c - bezel.i }
        PathLine { x: bezel.i; y: bezel.i }
    }
}
