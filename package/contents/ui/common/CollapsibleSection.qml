import QtQuick
import QtQuick.Layouts

// A module slot in a stacked layout. While `open` it is as tall as its
// content; closing animates the height to 0 and then hides it, so the
// sections below slide up into place. The content is clipped while the
// height moves, never laid out squashed. Works in a ColumnLayout or with
// hand-placed y positions.
Item {
    id: section

    property bool open: true
    default property alias content: holder.data
    readonly property real contentHeight: holder.childrenRect.height

    property real shownHeight: open ? contentHeight : 0
    Behavior on shownHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    height: shownHeight
    implicitHeight: shownHeight
    Layout.fillWidth: true
    Layout.preferredHeight: shownHeight
    visible: height > 0.5
    clip: shownHeight < contentHeight - 0.5

    Item {
        id: holder
        width: parent.width
        height: section.contentHeight
    }
}
