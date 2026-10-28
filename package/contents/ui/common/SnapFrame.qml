import QtQuick
import QtQuick.Layouts

// Stepped resizing for a desktop card. Plasma's applet box follows the drag
// handle freely and cannot be resized from QML, so the card inside it snaps
// instead: 200 ms after the box stops changing, the card takes the nearest
// column width and row height from the theme tokens (260 / 360 / 740 wide,
// 110 / 240 / 380 tall, then whole pill rows; never more than the box) and
// animates there over
// 180 ms. It sits in the top-left corner behind a uniform 4px margin; content
// taller than the step scrolls. Off the desktop (`snapping` false) the card
// is content-sized.
Item {
    id: snap

    property QtObject theme
    property bool snapping: true
    property real contentHeight: 0          // natural height of the card's content
    default property alias content: card.data
    readonly property real cardWidth: card.width

    // The smallest row step that holds the content (at most maxPopupHeight),
    // for the preferred size.
    readonly property real fittingRow: theme.fitHeight(Math.min(naturalHeight, maxPopupHeight))
    // Off the desktop the popup sizes to the content, up to maxPopupHeight.
    readonly property real naturalHeight: contentHeight + theme.margin * 2
    Layout.minimumWidth: theme.colWidthCompact
    Layout.minimumHeight: snapping ? theme.rowHeightPill : Math.min(naturalHeight, maxPopupHeight)
    Layout.preferredWidth: theme.colWidthStandard
    Layout.preferredHeight: snapping ? fittingRow : Math.min(naturalHeight, maxPopupHeight)
    Layout.maximumHeight: snapping ? Infinity : Math.min(naturalHeight, maxPopupHeight)
    property real maxPopupHeight: 760

    property real targetWidth: theme.colWidthStandard
    property real targetHeight: fittingRow
    function resnap() {
        targetWidth = Math.min(width, theme.snapWidth(width))
        targetHeight = Math.min(height, theme.snapHeight(height))
    }
    Timer { id: debounce; interval: 200; onTriggered: snap.resnap() }
    onWidthChanged: debounce.restart()
    onHeightChanged: debounce.restart()
    Component.onCompleted: resnap()

    Behavior on targetWidth { enabled: snap.snapping; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on targetHeight { enabled: snap.snapping; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    Flickable {
        id: scroller
        x: snap.theme.margin
        y: snap.theme.margin
        width: (snap.snapping ? snap.targetWidth : snap.width) - snap.theme.margin * 2
        height: (snap.snapping ? snap.targetHeight : snap.height) - snap.theme.margin * 2
        contentWidth: width
        contentHeight: snap.contentHeight
        interactive: contentHeight > height + 1
        boundsBehavior: Flickable.StopAtBounds
        clip: interactive
        Item {
            id: card
            width: scroller.width
            height: Math.max(scroller.height, snap.contentHeight)
        }
    }
}
