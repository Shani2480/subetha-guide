import QtQuick
import QtQuick.Shapes

// A small cartoon half-dial (controls.dialStyle "semicircle"): five wedges
// from green to red across the top half, a needle from the hub at the
// bottom swinging to `value` (0..1), and the caption under it. Outlined in
// the theme's border colour, thick under cartoon outlines.
Item {
    id: dial

    property QtObject theme
    property real value: 0
    property string caption: ""
    property string valueText: ""

    readonly property real r: Math.min(width / 2, height - captionText.implicitHeight - 2) - 1
    readonly property real cx: width / 2
    readonly property real cy: r + 1
    readonly property color ink: theme.border
    readonly property real line: theme.cartoon ? 2.5 : 1.5
    readonly property var wedges: ["#3CC23C", "#9AD62E", "#F2D43C", "#F59A23", "#E8312A"]

    implicitWidth: 56
    implicitHeight: 42

    Shape {   // the face and its wedges
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: dial.ink; strokeWidth: dial.line
            fillColor: dial.theme.card
            PathAngleArc { centerX: dial.cx; centerY: dial.cy; radiusX: dial.r; radiusY: dial.r; startAngle: 180; sweepAngle: 180 }
            PathLine { x: dial.cx - dial.r; y: dial.cy }
        }
    }
    Repeater {
        model: 5
        Shape {
            required property int index
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: dial.wedges[index]
                strokeWidth: dial.r * 0.3
                fillColor: "transparent"
                capStyle: ShapePath.FlatCap
                PathAngleArc {
                    centerX: dial.cx; centerY: dial.cy
                    radiusX: dial.r * 0.78; radiusY: radiusX
                    startAngle: 180 + index * 36 + 1; sweepAngle: 34
                }
            }
        }
    }
    Text {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: hub.top; bottomMargin: 1 }
        text: dial.valueText
        color: dial.theme.ink
        font { family: dial.theme.sans; pixelSize: Math.max(7, dial.r * 0.3); bold: true }
    }
    Rectangle {   // the needle
        x: dial.cx - width / 2; y: dial.cy - height
        width: dial.line + 0.5; height: dial.r * 0.9
        radius: width / 2
        color: dial.ink
        antialiasing: true
        transformOrigin: Item.Bottom
        rotation: -90 + 180 * Math.max(0, Math.min(1, dial.value))
        Behavior on rotation { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
    }
    Rectangle {
        id: hub
        x: dial.cx - width / 2; y: dial.cy - height / 2
        width: dial.r * 0.22; height: width; radius: width / 2
        color: "#E8312A"
        border { width: 1; color: dial.ink }
    }
    Text {
        id: captionText
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
        text: dial.caption
        color: dial.theme.ink
        font { family: dial.theme.sans; pixelSize: 8; bold: true; letterSpacing: 0.5 }
    }
}
