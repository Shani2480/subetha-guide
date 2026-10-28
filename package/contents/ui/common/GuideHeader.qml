import QtQuick
import QtQuick.Layouts

// The Guide's page header: a monospace title (and optional subtitle) with the
// DON'T PANIC badge on the right.
RowLayout {
    id: header

    property QtObject theme
    property string title: ""
    property string subtitle: ""

    spacing: 10
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        Text {
            Layout.fillWidth: true
            text: header.title
            color: header.theme.ink
            font { family: header.theme.mono; pixelSize: 11; bold: true; letterSpacing: 0.6 }
            wrapMode: Text.WordWrap
        }
        Text {
            visible: header.subtitle !== ""
            Layout.fillWidth: true
            text: header.subtitle
            color: header.theme.tint(0.6)
            font { family: header.theme.mono; pixelSize: 10; bold: true; letterSpacing: 0.4 }
            elide: Text.ElideRight
        }
    }
    DontPanicBadge {
        Layout.alignment: Qt.AlignTop
        theme: header.theme
    }
}
