import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// A config-dialog option drawn as a miniature: a 140x100 bordered card holding
// a schematic of what the option looks like, with its name underneath. The
// selected card wears the accent border; hovering pops it slightly and shows
// the description as a tooltip. The schematic goes in as the default property
// and fills the card (clipped to its rounded corners).
ColumnLayout {
    id: preview

    property string title: ""
    property string cardDescription: ""
    property bool selected: false
    property color surface: Kirigami.Theme.backgroundColor
    default property alias schematic: art.data

    signal clicked()

    spacing: Kirigami.Units.smallSpacing

    Rectangle {
        id: card
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 140
        implicitHeight: 100
        radius: 10
        color: preview.surface
        border.width: 2
        border.color: preview.selected ? Kirigami.Theme.highlightColor
                    : mouseArea.containsMouse ? Kirigami.Theme.hoverColor
                    : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.3)
        scale: mouseArea.containsMouse ? 1.02 : 1.0
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        Item {   // the schematic, inside the border
            id: art
            anchors { fill: parent; margins: 2 }
            clip: true
        }
        Rectangle {   // selected tick
            visible: preview.selected
            anchors { right: parent.right; top: parent.top; margins: 6 }
            width: 18; height: 18; radius: 9
            color: Kirigami.Theme.highlightColor
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 12; height: 12
                source: "checkmark"
                color: Kirigami.Theme.highlightedTextColor
                isMask: true
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: preview.clicked()
        }
        QQC2.ToolTip.visible: mouseArea.containsMouse && preview.cardDescription !== ""
        QQC2.ToolTip.text: preview.cardDescription
        QQC2.ToolTip.delay: 300
    }
    QQC2.Label {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: 150
        text: preview.title
        font.bold: preview.selected
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }
}
