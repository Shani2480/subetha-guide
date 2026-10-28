import QtQuick
import QtQuick.Shapes

// A rolling telemetry graph: `historyData` (oldest first, each 0..1) drawn as a
// GPU Shape, a stroked PathPolyline over a faint filled area. The newest
// sample sits on the right edge and the trace grows leftwards until
// `capacity` samples span the width. It re-tessellates only when a sample
// arrives, never per frame. `inverted` hangs the graph from the top edge (the
// lower half of a two-way throughput plot).
Item {
    id: graph

    property var historyData: []
    property color strokeColor: "black"
    property color fillColor: Qt.rgba(strokeColor.r, strokeColor.g, strokeColor.b, 0.18)
    property real lineWidth: 1.5
    property int capacity: 24
    property bool inverted: false
    // Skin styling, all off by default: a stepped trace, a band over the top
    // of the graph past dangerAbove, and the trace turning hotColor while the
    // newest sample is past hotAbove.
    property bool stepped: false
    property color dangerColor: "transparent"
    property real dangerAbove: 0.85
    property color hotColor: "transparent"
    property real hotAbove: 0.75
    readonly property real newest: historyData && historyData.length ? Number(historyData[historyData.length - 1]) || 0 : 0
    readonly property color trace: hotColor.a > 0 && newest > hotAbove ? hotColor : strokeColor

    readonly property var points: {
        var pts = []
        var n = historyData ? historyData.length : 0
        if (n < 2 || width <= 0) return pts
        var step = width / Math.max(1, capacity - 1)
        var x0 = width - step * (n - 1)
        var span = height - lineWidth
        for (var i = 0; i < n; i++) {
            var f = Math.max(0, Math.min(1, Number(historyData[i]) || 0))
            var y = inverted ? lineWidth / 2 + f * span : height - lineWidth / 2 - f * span
            if (stepped && i > 0) pts.push(Qt.point(x0 + step * i, pts[pts.length - 1].y))
            pts.push(Qt.point(x0 + step * i, y))
        }
        return pts
    }
    readonly property var area: points.length < 2 ? []
        : [Qt.point(points[0].x, inverted ? 0 : height)].concat(points)
              .concat([Qt.point(points[points.length - 1].x, inverted ? 0 : height)])

    Rectangle {   // danger zone
        visible: graph.dangerColor.a > 0
        width: parent.width
        height: parent.height * (1 - graph.dangerAbove)
        y: graph.inverted ? parent.height - height : 0
        color: Qt.rgba(graph.dangerColor.r, graph.dangerColor.g, graph.dangerColor.b, 0.12)
        Rectangle {
            width: parent.width; height: 1
            y: graph.inverted ? 0 : parent.height - 1
            color: graph.dangerColor
            opacity: 0.6
        }
    }

    Shape {
        anchors.fill: parent
        visible: graph.points.length >= 2
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillColor: graph.fillColor
            PathPolyline { path: graph.area }
        }
        ShapePath {
            strokeColor: graph.trace
            strokeWidth: graph.lineWidth
            fillColor: "transparent"
            joinStyle: graph.stepped ? ShapePath.MiterJoin : ShapePath.RoundJoin
            capStyle: graph.stepped ? ShapePath.SquareCap : ShapePath.RoundCap
            PathPolyline { path: graph.points }
        }
    }
}
