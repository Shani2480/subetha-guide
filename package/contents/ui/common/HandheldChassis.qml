import QtQuick
import QtQuick.Shapes

// A skin's "handheld" chassis (theme.frame.style), drawn by VectorFrame over a
// frame that asks for it: speaker vents cut into the top edge, and along the
// bottom a controls strip, a D-pad on the left, the skin's face screen in the
// middle (theme.faces: idle, happy under the pointer, stressed on a critical
// reading) and round face buttons on the right. Fills its frame's surface;
// stripHeight is the room the frame keeps free for the strip.
Item {
    id: chassis

    property QtObject theme
    readonly property var spec: theme.frame || ({})
    readonly property real stripHeight: 40
    readonly property color line: theme.border

    HoverHandler { id: hover }

    // ---- speaker grille ----
    Column {
        anchors { top: parent.top; topMargin: 5; horizontalCenter: parent.horizontalCenter }
        spacing: 3
        Repeater {
            model: chassis.spec.vents === null || chassis.spec.vents === undefined ? 3 : chassis.spec.vents
            Rectangle { width: 34; height: 2; radius: 1; color: chassis.line; opacity: 0.45 }
        }
    }

    // ---- controls strip ----
    Item {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
        height: chassis.stripHeight - 12

        Shape {   // D-pad
            id: dpad
            readonly property real s: parent.height
            readonly property real arm: s / 3
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: s; height: s
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: chassis.spec.dpad || chassis.theme.badge
                strokeColor: chassis.line
                strokeWidth: 2
                joinStyle: ShapePath.RoundJoin
                startX: dpad.arm; startY: 0
                PathLine { x: dpad.arm * 2; y: 0 }
                PathLine { x: dpad.arm * 2; y: dpad.arm }
                PathLine { x: dpad.s; y: dpad.arm }
                PathLine { x: dpad.s; y: dpad.arm * 2 }
                PathLine { x: dpad.arm * 2; y: dpad.arm * 2 }
                PathLine { x: dpad.arm * 2; y: dpad.s }
                PathLine { x: dpad.arm; y: dpad.s }
                PathLine { x: dpad.arm; y: dpad.arm * 2 }
                PathLine { x: 0; y: dpad.arm * 2 }
                PathLine { x: 0; y: dpad.arm }
                PathLine { x: dpad.arm; y: dpad.arm }
                PathLine { x: dpad.arm; y: 0 }
            }
        }

        Rectangle {   // face screen
            readonly property string face: hover.hovered && chassis.theme.faces.happy ? chassis.theme.faces.happy
                                         : chassis.theme.mood === "stressed" && chassis.theme.faces.stressed ? chassis.theme.faces.stressed
                                         : chassis.theme.faces.idle || ""
            visible: face !== ""
            anchors.centerIn: parent
            width: parent.height * 1.5; height: parent.height
            radius: 6
            color: chassis.theme.card
            border { width: 2; color: chassis.line }
            Image {
                anchors { fill: parent; margins: 3 }
                source: parent.face
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
        }

        Row {   // face buttons, the first one larger
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 6
            Repeater {
                model: chassis.spec.buttons && chassis.spec.buttons.length ? chassis.spec.buttons
                                                                           : [chassis.theme.cool, chassis.theme.low, chassis.theme.high]
                Rectangle {
                    required property var modelData
                    required property int index
                    anchors.verticalCenter: parent.verticalCenter
                    width: index === 0 ? 18 : 13; height: width
                    radius: width / 2
                    color: modelData
                    border { width: 2; color: chassis.line }
                }
            }
        }
    }
}
