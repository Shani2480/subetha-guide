import QtQuick
import QtQuick.Shapes

// A character in a card's corner (narrative.vignettes): the skin's ~48px
// drawing with a comic speech bubble beside it, the tail pointing at them.
// The owner places it where it covers no figures (it takes its own row).
Item {
    id: vig

    property QtObject theme
    property string art: ""
    property string text: ""

    TextMetrics { id: natural; text: vig.text; font: label.font }
    implicitWidth: Math.min(natural.advanceWidth + 16, 220) + 6 + 48
    implicitHeight: Math.max(48, bubble.height)

    Rectangle {
        id: bubble
        visible: vig.text !== ""
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(natural.advanceWidth + 16, Math.max(80, vig.width - 60)); height: label.implicitHeight + 10
        radius: 9
        color: "white"
        border { width: vig.theme.cartoon ? 2.5 : 1.5; color: "#111111" }
        Text {
            id: label
            anchors.centerIn: parent
            width: parent.width - 14
            text: vig.text
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: "#111111"
            font { family: vig.theme.sans; pixelSize: 10; bold: true }
        }
    }
    Shape {   // the tail, toward the character
        visible: bubble.visible
        x: bubble.width - 2; y: bubble.y + bubble.height / 2 - 5
        width: 10; height: 10
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "#111111"; strokeWidth: vig.theme.cartoon ? 2.5 : 1.5
            fillColor: "white"
            PathSvg { path: "M 0 1 L 9 5 L 0 9" }
        }
    }
    Image {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: 48; height: 48
        source: vig.art
        sourceSize: Qt.size(96, 96)
        fillMode: Image.PreserveAspectFit
    }
}
