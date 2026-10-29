import QtQuick
import QtQuick.Shapes

// Ooze hanging from an edge (features.slimeDrips): a wavy lip along the top
// with drips of different lengths, each one stretching and recovering on
// its own slow cycle. Seeded by `seed`, so every edge drips differently.
Item {
    id: drips

    property color color: "#7CFC3A"
    property int seed: 1
    property bool running: false
    property real lip: 4

    implicitHeight: 22
    clip: false

    readonly property var spots: {
        var out = [], s = seed * 7919 + 13
        var n = Math.max(2, Math.floor(width / 46))
        for (var i = 0; i < n; i++) {
            s = (s * 9301 + 49297) % 233280
            out.push({ x: (i + 0.25 + 0.5 * s / 233280) * width / n, len: 7 + (s % 13), w: 4 + (s % 4) })
        }
        return out
    }
    Shape {   // the lip
        width: drips.width; height: drips.lip * 2
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1; strokeColor: "transparent"
            fillColor: drips.color
            PathSvg {
                path: {
                    var w = drips.width, l = drips.lip, d = "M 0 0 H " + w + " V " + l
                    for (var x = w; x > 0; x -= 12) d += " Q " + (x - 6) + " " + (l * 1.8) + " " + Math.max(0, x - 12) + " " + l
                    return d + " Z"
                }
            }
        }
    }
    Repeater {
        model: drips.spots
        Item {
            id: drip
            required property var modelData
            required property int index
            x: modelData.x - modelData.w / 2; y: drips.lip - 1
            width: modelData.w
            property real stretch: 1
            height: modelData.len * stretch
            Rectangle {   // the strand
                width: parent.width * 0.6; x: parent.width * 0.2
                height: parent.height
                color: drips.color
            }
            Rectangle {   // its bead
                anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.bottom }
                width: drip.modelData.w; height: width * 1.2; radius: width / 2
                color: drips.color
                Rectangle { x: 1; y: 1.5; width: 1.5; height: 2; radius: 1; color: "white"; opacity: 0.6 }
            }
            SequentialAnimation on stretch {
                running: drips.running
                loops: Animation.Infinite
                PauseAnimation { duration: 600 + drip.index * 430 }
                NumberAnimation { to: 1.45; duration: 1800; easing.type: Easing.InQuad }
                NumberAnimation { to: 1; duration: 500; easing.type: Easing.OutBack }
            }
        }
    }
}
