import QtQuick
import QtQuick.Controls as QQC2

// A section's density switch: a small monospace tag, "[ - ]" while the
// section is full and "[ + ]" while compact, worn like a legend on the top
// border of the section's card (top-right corner, half above the edge) so it
// costs no height in either mode. Clicking emits `toggled`; the owner writes
// the new density back to the configuration.
Rectangle {
    id: tag

    property QtObject theme
    property bool compact: false

    signal toggled()

    anchors { top: parent.top; right: parent.right; topMargin: -height / 2 + 1; rightMargin: 18 }
    z: 20
    width: label.implicitWidth + 10
    height: label.implicitHeight + 2
    radius: theme.skinned ? Math.min(4, theme.pillRadius) : 4
    readonly property bool hot: area.containsMouse
    color: hot ? theme.ink : theme.bg
    border.width: theme.stroke(1, 1.5)
    border.color: theme.dark ? theme.tint(hot ? 1 : 0.55) : theme.ink

    Text {
        id: label
        anchors.centerIn: parent
        text: tag.compact ? "[ + ]" : "[ - ]"
        color: tag.hot ? tag.theme.bg : tag.theme.ink
        font { family: tag.theme.mono; pixelSize: 9; bold: true }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -3   // a slightly larger hit target than the tag
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tag.toggled()
    }
    QQC2.ToolTip.visible: area.containsMouse
    QQC2.ToolTip.text: i18n("Toggle Compact / Full telemetry")
    QQC2.ToolTip.delay: 400
}
