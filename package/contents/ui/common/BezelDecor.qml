import QtQuick
import QtQuick.Shapes

// A "bezel" skin's ornament on the frames that ask for it (VectorFrame's
// `chassis`, the Guide's header): calibration ticks down the left edge, a 45°
// accent tab across the top-right corner, a hazard-striped top rail, corner
// rivets, a controls row (a chunky pushbutton pill and two analog dials for
// load and heat, theme.meterA / meterB), a watermark line along the bottom
// with the skin's alert icon blinking at its end on a critical reading, and,
// now and then while the Guide is on screen, a split-second chromatic glitch.
// Each piece shows only if theme.frame names it. Fills its frame's surface;
// footerHeight is the room the frame keeps free below the content.
Item {
    id: decor

    property QtObject theme
    readonly property var spec: theme.frame || ({})
    readonly property bool controls: !!spec.button || !!spec.dials
    readonly property real lineHeight: spec.watermark || spec.alertIcon ? 16 : 0
    readonly property real footerHeight: (controls ? 34 : 0) + lineHeight
    readonly property real cut: theme.chamfer

    // ---- calibration ticks: ||| | || down the middle of the left edge ----
    Column {
        visible: decor.spec.ticks === true
        x: 3
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Repeater {
            model: [6, 4, 4, 0, 6, 0, 4, 4, 0, 6, 4, 4]   // 0: a gap
            Rectangle {
                required property int modelData
                width: Math.max(1, modelData); height: 1
                color: decor.theme.border
                opacity: modelData > 0 ? 0.7 : 0
            }
        }
    }

    // ---- 45° accent tab over the top-right corner ----
    Shape {
        visible: !!decor.spec.slash
        anchors { top: parent.top; right: parent.right }
        width: 46; height: 46
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: decor.spec.slash || "transparent"
            strokeColor: "transparent"
            startX: 16; startY: 0
            PathLine { x: 30; y: 0 }
            PathLine { x: 46; y: 16 }
            PathLine { x: 46; y: 30 }
            PathLine { x: 16; y: 0 }
        }
    }

    // ---- hazard rail: angled stripes along the top ----
    Item {
        visible: (decor.spec.hazard || []).length === 2
        x: Math.max(8, decor.theme.outerRadius); y: decor.theme.borderWidth + 2
        width: parent.width - x * 2 - decor.cut; height: 5
        clip: true
        Row {
            x: -6
            spacing: 0
            Repeater {
                model: Math.max(0, Math.ceil((parent.parent.width + 12) / 6))
                Rectangle {
                    required property int index
                    width: 6; height: 14; y: -4
                    color: (decor.spec.hazard || [])[index % 2] || "transparent"
                    transform: Rotation { origin.x: 3; origin.y: 7; angle: 35 }
                }
            }
        }
    }

    // ---- rivets: a bolt in each corner with a highlight notch ----
    Repeater {
        model: decor.spec.rivets ? 4 : 0
        Rectangle {
            required property int index
            readonly property real inset: 5
            x: index % 2 ? decor.width - width - inset : inset
            y: index >= 2 ? decor.height - height - inset : inset
            width: 7; height: 7; radius: 3.5
            color: decor.spec.rivets
            border { width: 1; color: Qt.darker(decor.spec.rivets, 1.8) }
            Rectangle { x: 1.5; y: 1.5; width: 2; height: 2; radius: 1; color: "white"; opacity: 0.8 }
        }
    }

    // ---- controls row: pushbutton pill and two dials ----
    Item {
        visible: decor.controls
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12; bottomMargin: 8 + decor.lineHeight }
        height: 26

        Item {   // the pushbutton: a base and a cap that sinks when pressed
            id: pushbutton
            visible: !!decor.spec.button
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: capText.implicitWidth + 22; height: 22
            readonly property color tone: decor.spec.button && decor.spec.button.color ? decor.spec.button.color : decor.theme.alert
            Rectangle { y: 3; width: parent.width; height: parent.height - 3; radius: height / 2; color: Qt.darker(pushbutton.tone, 1.8) }
            Rectangle {
                y: press.pressed ? 2 : 0
                width: parent.width; height: parent.height - 3
                radius: height / 2
                color: pushbutton.tone
                border { width: 1.5; color: Qt.darker(pushbutton.tone, 1.8) }
                Text {
                    id: capText
                    anchors.centerIn: parent
                    text: decor.spec.button ? decor.spec.button.text : ""
                    color: "white"
                    font { family: decor.theme.mono; pixelSize: 9; bold: true; letterSpacing: 0.6 }
                }
            }
            TapHandler { id: press }
        }

        Row {
            visible: !!decor.spec.dials
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 8
            Repeater {
                model: [decor.theme.meterA, decor.theme.meterB]
                Item {   // half-round meter: dial face, ticks and a needle
                    required property real modelData
                    width: 34; height: 20
                    clip: true   // the top half of a round face; the pivot sits at (17, 17)
                    Rectangle {
                        width: 34; height: 34; radius: 17
                        color: decor.theme.card
                        border { width: 1.5; color: decor.theme.border }
                    }
                    Repeater {
                        model: 5
                        Rectangle {
                            required property int index
                            x: 16.25; y: 3; width: 1.5; height: 4
                            color: decor.theme.inkSoft
                            transform: Rotation { origin.x: 0.75; origin.y: 14; angle: -60 + index * 30 }
                        }
                    }
                    Rectangle {   // needle
                        x: 16; y: 4; width: 2; height: 14; radius: 1
                        color: decor.spec.dials
                        antialiasing: true
                        transform: Rotation {
                            origin { x: 1; y: 13 }
                            angle: -60 + 120 * Math.max(0, Math.min(1, modelData))
                            Behavior on angle { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
                        }
                    }
                    Rectangle { x: 14; y: 14; width: 6; height: 6; radius: 3; color: decor.theme.border }
                }
            }
        }
    }

    // ---- watermark and alert icon ----
    Image {
        id: mark
        visible: !!decor.spec.mark
        anchors { left: parent.left; bottom: parent.bottom; leftMargin: 10 + decor.cut; bottomMargin: 4 }
        width: visible ? 10 : 0; height: 10
        source: decor.spec.mark || ""
        sourceSize: Qt.size(20, 20)
        opacity: 0.8
    }
    Text {
        visible: !!decor.spec.watermark
        anchors { left: mark.right; bottom: parent.bottom; leftMargin: mark.visible ? 4 : 10 + decor.cut; bottomMargin: 5 }
        width: parent.width - 40 - decor.cut - mark.width
        text: decor.spec.watermark || ""
        color: decor.spec.watermarkColor || decor.theme.inkSoft
        opacity: 0.8
        font { family: decor.theme.mono; pixelSize: 8; letterSpacing: 0.6 }
        elide: Text.ElideRight
    }
    Image {
        id: alert
        visible: !!decor.spec.alertIcon && decor.theme.mood === "stressed"
        anchors { right: parent.right; bottom: parent.bottom; margins: 4 }
        width: 12; height: 12
        source: decor.spec.alertIcon || ""
        sourceSize: Qt.size(24, 24)
        SequentialAnimation on opacity {
            running: alert.visible && decor.theme.live
            loops: Animation.Infinite
            onRunningChanged: if (!running) alert.opacity = 1
            NumberAnimation { to: 0.2; duration: 400 }
            NumberAnimation { to: 1; duration: 400 }
        }
    }

    // ---- glitch: two offset colour slices for about 0.2 s, every 18-40 s ----
    property bool glitching: false
    property real sliceY: 0.3
    Timer {
        running: decor.spec.glitch === true && decor.theme.live && decor.visible
        repeat: true
        interval: 18000 + Math.random() * 22000
        onTriggered: {
            interval = 18000 + Math.random() * 22000
            decor.sliceY = 0.15 + Math.random() * 0.7
            decor.glitching = true
            glitchOff.restart()
        }
    }
    Timer { id: glitchOff; interval: 180; onTriggered: decor.glitching = false }
    Repeater {
        model: [{ c: decor.theme.accent, dx: -3, dy: 0 }, { c: decor.theme.cool, dx: 3, dy: 3 }]
        Rectangle {
            required property var modelData
            visible: decor.glitching
            x: 6 + modelData.dx; y: decor.height * decor.sliceY + modelData.dy
            width: decor.width - 12; height: 2
            color: modelData.c
            opacity: 0.55
        }
    }
}
