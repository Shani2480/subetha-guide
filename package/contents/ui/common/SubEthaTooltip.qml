import QtQuick
import QtQuick.Controls as QQC2

// The Guide's own hover tooltip, for technical detail behind a metric:
// a cream paper slip with a 2px ink outline and flat offset shadow (light),
// or a CRT box with a phosphor outline and amber corner reticles (dark),
// monospace lines inside. Put it in the hovered item next to a HoverHandler
// and bind `shown` to the handler; it opens after `delay` and positions
// itself above its parent like any ToolTip.
QQC2.ToolTip {
    id: tip

    property QtObject theme
    property bool shown: false

    visible: shown && text !== ""
    delay: 450
    timeout: -1
    padding: 9
    y: -implicitHeight - 6

    contentItem: Text {
        text: tip.text
        color: tip.theme.ink
        font { family: tip.theme.mono; pixelSize: 10; bold: true; letterSpacing: 0.3 }
        lineHeight: 1.15
        textFormat: Text.PlainText
    }
    background: Item {
        Rectangle {   // flat offset shadow (light)
            visible: tip.theme.skinned ? tip.theme.flatShadow : !tip.theme.dark
            x: tip.theme.skinned ? tip.theme.shadowX : 2; y: tip.theme.skinned ? tip.theme.shadowY : 2
            width: parent.width; height: parent.height
            radius: tip.theme.skinned ? Math.min(6, tip.theme.pillRadius) : 6
            color: tip.theme.ink
        }
        Rectangle {
            anchors.fill: parent
            radius: tip.theme.skinned ? Math.min(6, tip.theme.pillRadius) : tip.theme.dark ? 2 : 6
            color: tip.theme.dark ? tip.theme.crtBlack : tip.theme.cream
            border.width: tip.theme.skinned ? Math.min(2, tip.theme.borderWidth) : tip.theme.dark ? 1 : 2
            border.color: tip.theme.skinned ? tip.theme.border : tip.theme.dark ? tip.theme.tint(0.8) : tip.theme.ink
        }
        Repeater {   // corner reticles (dark)
            model: (tip.theme.skinned ? tip.theme.fx.cornerBrackets : tip.theme.dark) ? 4 : 0
            Item {
                required property int index
                readonly property bool atRight: index % 2 === 1
                readonly property bool atBottom: index >= 2
                width: 6; height: 6
                x: atRight ? parent.width - width - 3 : 3
                y: atBottom ? parent.height - height - 3 : 3
                Rectangle { width: parent.width; height: 1; y: parent.atBottom ? parent.height - 1 : 0; color: tip.theme.skinned ? tip.theme.bracketColor : tip.theme.amber }
                Rectangle { width: 1; height: parent.height; x: parent.atRight ? parent.width - 1 : 0; color: tip.theme.skinned ? tip.theme.bracketColor : tip.theme.amber }
            }
        }
    }
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 90 } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 70 } }
}
