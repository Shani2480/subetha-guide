import QtQuick
import QtQuick.Shapes

// The chronometer's 48px dial: an outer ring sweeping through the minute
// (seconds / 60) and an inner ring through the day (hours / 24), each over
// a faint track, with twelve hour ticks and the ISO week in the middle.
// Drawn once as Shapes; only the two sweep angles change, once a second.
Item {
    id: dial

    property QtObject theme
    property real secondFraction: 0
    property real dayFraction: 0
    property string centerText: ""

    implicitWidth: 48
    implicitHeight: 48

    readonly property real c: width / 2
    readonly property real outerR: c - 3
    readonly property real innerR: c - 9

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {   // tracks
            strokeColor: dial.theme.tint(0.18)
            strokeWidth: 3
            fillColor: "transparent"
            PathAngleArc { centerX: dial.c; centerY: dial.c; radiusX: dial.outerR; radiusY: dial.outerR; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: dial.theme.tint(0.18)
            strokeWidth: 3
            fillColor: "transparent"
            PathAngleArc { centerX: dial.c; centerY: dial.c; radiusX: dial.innerR; radiusY: dial.innerR; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {   // seconds
            strokeColor: dial.theme.ink
            strokeWidth: 3
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: dial.c; centerY: dial.c; radiusX: dial.outerR; radiusY: dial.outerR
                startAngle: -90; sweepAngle: Math.max(0.01, dial.secondFraction * 360)
            }
        }
        ShapePath {   // hours
            strokeColor: dial.theme.accent
            strokeWidth: 3
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: dial.c; centerY: dial.c; radiusX: dial.innerR; radiusY: dial.innerR
                startAngle: -90; sweepAngle: Math.max(0.01, dial.dayFraction * 360)
            }
        }
    }
    Repeater {   // hour ticks between the rings
        model: 12
        Rectangle {
            required property int index
            x: dial.c - width / 2
            y: dial.c - (dial.outerR + dial.innerR) / 2 - height / 2
            width: 1; height: index % 3 === 0 ? 4 : 2
            color: dial.theme.tint(0.6)
            transform: Rotation { origin.x: 0.5; origin.y: (dial.outerR + dial.innerR) / 2 + height / 2; angle: index * 30 }
        }
    }
    Text {
        anchors.centerIn: parent
        text: dial.centerText
        color: dial.theme.ink
        font { family: dial.theme.mono; pixelSize: 8; bold: true }
    }
}
