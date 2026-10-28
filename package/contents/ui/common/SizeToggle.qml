import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

// A telemetry pill's size switch, for the top-right corner of its first row:
// a bare monospace "[ - ]" while the pill is large and "[ + ]" while small,
// in the theme's ink, dimmed until hovered. Clicking emits `toggled`; the
// owner writes the new size back to the configuration.
Text {
    id: tag

    property QtObject theme
    property bool small: false

    signal toggled()

    Layout.alignment: Qt.AlignTop | Qt.AlignRight
    text: small ? "[ + ]" : "[ - ]"
    color: theme.ink
    opacity: area.containsMouse ? 1 : 0.45
    Behavior on opacity { NumberAnimation { duration: 120 } }
    font { family: theme.mono; pixelSize: 10; bold: true }

    MouseArea {
        id: area
        anchors { fill: parent; margins: -4 }   // a slightly larger hit target than the text
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tag.toggled()
    }
    QQC2.ToolTip.visible: area.containsMouse
    QQC2.ToolTip.text: small ? i18n("Expand detailed telemetry & sparkline") : i18n("Collapse to compact indicator")
    QQC2.ToolTip.delay: 400
}
