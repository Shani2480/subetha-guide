import QtQuick
import QtQuick.Layouts

// The Guide's page header: a monospace title (and optional subtitle) with the
// DON'T PANIC badge on the right (or, when a skin's legend would take more
// than 40% of the width, on a line of its own under the title), and a bezel
// skin's logo before the title.
RowLayout {
    id: header

    property QtObject theme
    property string title: ""
    property string subtitle: ""

    spacing: 10
    readonly property bool badgeBelow: badge.implicitWidth > width * 0.4
    Image {
        visible: source != ""
        Layout.alignment: Qt.AlignTop
        Layout.preferredWidth: 22; Layout.preferredHeight: 22
        source: header.theme.frame && header.theme.frame.logo ? header.theme.frame.logo : ""
        sourceSize: Qt.size(44, 44)
        fillMode: Image.PreserveAspectFit
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        Text {
            Layout.fillWidth: true
            text: header.title
            color: header.theme.onBackground   // the frame's face is the theme's background
            font { family: header.theme.mono; pixelSize: 11; bold: true; letterSpacing: 0.6 }
            wrapMode: Text.WordWrap
        }
        Text {
            visible: header.subtitle !== ""
            Layout.fillWidth: true
            text: header.subtitle
            color: header.theme.onBackgroundDim
            font { family: header.theme.mono; pixelSize: 10; bold: true; letterSpacing: 0.4 }
            elide: Text.ElideRight
        }
        DontPanicBadge {   // the wide legend's own line
            visible: header.badgeBelow
            Layout.topMargin: 4
            theme: header.theme
        }
    }
    DontPanicBadge {
        id: badge
        visible: !header.badgeBelow
        Layout.alignment: Qt.AlignTop
        theme: header.theme
    }
}
