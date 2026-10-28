import QtQuick
import QtQuick.Layouts

// A single-module widget's card: the VectorFrame with the page header and a
// module panel inside, snapped to the layout steps on the desktop (SnapFrame)
// and content-sized in a popup. The panel goes in as the default property.
SnapFrame {
    id: page

    property string title: ""
    property bool minimal: false
    property bool desktop: false
    default property alias body: column.data

    snapping: desktop
    contentHeight: frame.implicitHeight

    VectorFrame {
        id: frame
        width: parent.width
        theme: page.theme
        padding: page.minimal ? 10 : 14
        ColumnLayout {
            id: column
            width: parent.width
            spacing: page.minimal ? 8 : 10
            GuideHeader {
                visible: !page.minimal
                Layout.fillWidth: true
                theme: page.theme
                title: page.title
            }
        }
    }
}
