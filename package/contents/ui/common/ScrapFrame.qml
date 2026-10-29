import QtQuick
import QtQuick.Shapes

// A cobbled garage frame round the whole Guide (frame.style "scrap"), drawn
// by GuideWindow around its body: galvanized plating with an irregular ink
// outline, welded seams and rivets (frame.rivets); a dark marquee at the top
// with the title glowing (plaqueTitle in plaqueText) over a small subtitle,
// flanked by the skin's portal art (frame.portal), turning slowly under
// features.portalSpinners; ooze dripping off the marquee under
// features.slimeDrips (frame.slime); the toolbelt art along the bottom
// (frame.toolbelt); and two decorative scrap buttons, – and ✕.
Item {
    id: scrap

    property QtObject theme
    readonly property var spec: theme.frame || ({})
    readonly property real topHeight: 70
    readonly property real sideWidth: 10
    readonly property real bottomHeight: spec.toolbelt ? 30 : 12
    readonly property color ink: theme.border
    readonly property color plate: theme.dark ? "#5E666E" : "#A9B0B6"
    readonly property color slime: spec.slime || "#7CFC3A"

    // ---- the plating, its ragged outline, seams and rivets ----
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: scrap.ink; strokeWidth: 3
            joinStyle: ShapePath.RoundJoin
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: scrap.width; y2: scrap.height
                GradientStop { position: 0; color: Qt.lighter(scrap.plate, 1.15) }
                GradientStop { position: 0.5; color: scrap.plate }
                GradientStop { position: 1; color: Qt.darker(scrap.plate, 1.15) }
            }
            PathSvg {
                // a hand-cut sheet: each side wanders a pixel or two
                path: {
                    var w = scrap.width, h = scrap.height, j = [1.5, -1, 2, -1.5, 1, -2, 0.5]
                    var d = "M 3 4", k = 0
                    for (var x = 40; x < w - 3; x += 40) d += " L " + x + " " + (3 + j[k++ % 7])
                    d += " L " + (w - 3) + " 3"
                    for (var y = 40; y < h - 3; y += 40) d += " L " + (w - 3 + j[k++ % 7]) + " " + y
                    d += " L " + (w - 4) + " " + (h - 3)
                    for (x = w - 40; x > 3; x -= 40) d += " L " + x + " " + (h - 3 + j[k++ % 7])
                    d += " L 3 " + (h - 4)
                    for (y = h - 40; y > 4; y -= 40) d += " L " + (3 + j[k++ % 7]) + " " + y
                    return d + " Z"
                }
            }
        }
    }
    SkinTexture { anchors { fill: parent; margins: 4 } kind: "brushed"; color: "white"; strength: 0.08 }
    Repeater {   // welded seams across the plating, beaded
        model: Math.max(0, Math.floor(scrap.height / 160))
        Row {
            required property int index
            x: 6; y: scrap.topHeight + (index + 1) * 160
            spacing: 3
            Repeater {
                model: Math.max(0, Math.floor((scrap.width - 12) / 7))
                Rectangle { width: 4; height: 3; radius: 1.5; color: Qt.darker(scrap.plate, 1.35) }
            }
        }
    }
    Repeater {   // rivets round the edge
        model: {
            var pts = [], w = scrap.width, h = scrap.height
            for (var x = 16; x < w - 10; x += 56) { pts.push([x, 9]); pts.push([x, h - 9]) }
            for (var y = 64; y < h - 20; y += 56) { pts.push([7, y]); pts.push([w - 7, y]) }
            return pts
        }
        Rectangle {
            required property var modelData
            x: modelData[0] - 3; y: modelData[1] - 3
            width: 6; height: 6; radius: 3
            color: scrap.spec.rivets || "#C9CED3"
            border { width: 1; color: scrap.ink }
        }
    }

    // ---- the marquee, its portals and its ooze ----
    Marquee {
        id: marquee
        anchors.horizontalCenter: parent.horizontalCenter
        y: 10
        maxWidth: scrap.width - 60
        theme: scrap.theme
        title: scrap.spec.plaqueTitle || scrap.theme.lex("appTitle", "THE SUB-ETHA GUIDE", "SYSTEM GUIDE")
        subtitle: scrap.spec.plaqueSubtitle || ""
        plaque: scrap.spec.plaque || "#1B1F24"
        textColor: scrap.spec.plaqueText || scrap.slime
        subtextColor: scrap.spec.plaqueSubtext || scrap.theme.inkSoft
        ink: scrap.ink
        bloom: true
        leftArt: scrap.spec.portal || ""
        rightArt: scrap.spec.portal || ""
        spin: !!scrap.theme.skin && scrap.theme.skin.features.portalSpinners === true && scrap.theme.live
    }
    SlimeDrips {
        visible: scrap.theme.slimeDrips
        x: marquee.x + marquee.plate.x + 6; y: marquee.y + marquee.plate.y + marquee.plate.height - 2
        width: marquee.plate.width - 12
        color: scrap.slime
        seed: 3
        running: scrap.theme.live
    }
    Row {   // the scrap buttons: – and ✕, ornament
        anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: 10 }
        spacing: 5
        Repeater {
            model: [["–", "#2EC4B6"], ["✕", "#FF3EA5"]]
            Rectangle {
                required property var modelData
                width: 18; height: 16; radius: 3
                rotation: modelData[0] === "✕" ? 3 : -4
                color: modelData[1]
                border { width: 2; color: scrap.ink }
                Text { anchors.centerIn: parent; text: parent.modelData[0]; color: "#111111"; font { pixelSize: 10; bold: true } }
            }
        }
    }

    // ---- the toolbelt ----
    Image {
        visible: !!scrap.spec.toolbelt
        x: 8; y: parent.height - scrap.bottomHeight
        width: parent.width - 16; height: scrap.bottomHeight - 4
        source: scrap.spec.toolbelt || ""
        sourceSize.height: height * 2
        fillMode: Image.TileHorizontally
    }
}
