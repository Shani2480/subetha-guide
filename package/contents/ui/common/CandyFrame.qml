import QtQuick
import QtQuick.Shapes

// A pastel candy box round the whole Guide (frame.style "candy"), drawn by
// GuideWindow around its body: the box in frame.rim with a gently wavy
// 2.5px ink outline and a flat offset shadow, the skin's sweets
// (frame.decorations) tiled small down the left edge and along the top and
// bottom, the shared dark Marquee with frame.hudLeft and frame.hudRight at
// its ends, and two decorative lights, green and red, at the top right.
Item {
    id: candy

    property QtObject theme
    readonly property var spec: theme.frame || ({})
    readonly property real topHeight: 70
    readonly property real sideWidth: spec.decorations ? 22 : 10
    readonly property real bottomHeight: spec.decorations ? 24 : 12
    readonly property color ink: theme.border
    readonly property color rim: spec.rim || Qt.lighter(theme.accent, 1.5)

    function wavy(w, h, d) {   // the box's outline, a soft wave along each side
        var s = "M " + d + " " + d, k = 0, a = 1.2
        for (var x = d + 24; x < w - d; x += 24) s += " Q " + (x - 12) + " " + (d + (k++ % 2 ? a : -a)) + " " + x + " " + d
        s += " L " + (w - d) + " " + d
        for (var y = d + 24; y < h - d; y += 24) s += " Q " + (w - d + (k++ % 2 ? a : -a)) + " " + (y - 12) + " " + (w - d) + " " + y
        s += " L " + (w - d) + " " + (h - d)
        for (x = w - d - 24; x > d; x -= 24) s += " Q " + (x + 12) + " " + (h - d + (k++ % 2 ? a : -a)) + " " + x + " " + (h - d)
        s += " L " + d + " " + (h - d)
        for (y = h - d - 24; y > d; y -= 24) s += " Q " + (d + (k++ % 2 ? a : -a)) + " " + (y + 12) + " " + d + " " + y
        return s + " Z"
    }
    Shape {   // the flat offset shadow
        x: 3; y: 3; width: candy.width; height: candy.height
        preferredRendererType: Shape.CurveRenderer
        ShapePath { strokeWidth: -1; strokeColor: "transparent"; fillColor: candy.ink; PathSvg { path: candy.wavy(candy.width - 3, candy.height - 3, 2) } }
    }
    Shape {
        width: candy.width; height: candy.height
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: candy.ink; strokeWidth: 2.5
            fillColor: candy.rim
            PathSvg { path: candy.wavy(candy.width - 3, candy.height - 3, 2) }
        }
    }
    // the sweets along the edges
    Row {
        visible: !!candy.spec.decorations
        x: 8; y: 4; spacing: 6
        Repeater {
            model: candy.spec.decorations ? Math.max(0, Math.floor((candy.width - 16) / 22)) : 0
            Image { source: candy.spec.decorations; width: 16; height: 16; sourceSize: Qt.size(32, 32); opacity: 0.9 }
        }
    }
    Row {
        visible: !!candy.spec.decorations
        x: 8; y: candy.height - 22; spacing: 6
        Repeater {
            model: candy.spec.decorations ? Math.max(0, Math.floor((candy.width - 16) / 22)) : 0
            Image { source: candy.spec.decorations; width: 16; height: 16; sourceSize: Qt.size(32, 32); opacity: 0.9 }
        }
    }
    Column {
        visible: !!candy.spec.decorations
        x: 3; y: candy.topHeight; spacing: 8
        Repeater {
            model: candy.spec.decorations ? Math.max(0, Math.floor((candy.height - candy.topHeight - 30) / 24)) : 0
            Image { source: candy.spec.decorations; width: 16; height: 16; sourceSize: Qt.size(32, 32); opacity: 0.9 }
        }
    }

    Marquee {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 12
        maxWidth: candy.width - 80
        theme: candy.theme
        title: candy.spec.plaqueTitle || candy.theme.lex("appTitle", "THE SUB-ETHA GUIDE", "SYSTEM GUIDE")
        subtitle: candy.spec.plaqueSubtitle || ""
        plaque: candy.spec.plaque || "#2A1F3D"
        textColor: candy.spec.plaqueText || "#FFE680"
        subtextColor: candy.spec.plaqueSubtext || "#F2C6E8"
        ink: candy.ink
        leftArt: candy.spec.hudLeft || ""
        rightArt: candy.spec.hudRight || ""
        artSize: 34
    }
    Row {   // the lights, top right
        anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: 12 }
        spacing: 5
        Repeater {
            model: ["#3CC23C", "#E8312A"]
            Rectangle {
                required property color modelData
                width: 12; height: 12; radius: 6
                color: modelData
                border { width: 2; color: candy.ink }
                Rectangle { x: 2.5; y: 2; width: 3.5; height: 3; radius: 2; color: "white"; opacity: 0.7 }
            }
        }
    }
}
