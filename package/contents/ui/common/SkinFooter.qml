import QtQuick

// A skin's footer (style.footer, theme.footer) along the widget's bottom
// edge: its mark and uppercase label at the left, its motto tracked wide at
// the right, both in the secondary text colour, and its endMark after the
// motto. The marks keep their aspect (a wordmark is wide). Nothing without one.
Item {
    id: foot

    property QtObject theme
    readonly property var spec: theme.footer

    visible: spec !== null
    implicitHeight: visible ? 22 : 0

    Row {
        id: lead
        anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
        spacing: 6
        Mark { source: foot.spec && foot.spec.mark ? foot.spec.mark : "" }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: foot.spec ? foot.spec.label.toUpperCase() : ""
            color: foot.theme.inkSoft
            font { family: foot.theme.mono; pixelSize: 10; bold: true; letterSpacing: 1 }
        }
    }
    Mark {
        id: endMark
        anchors { right: parent.right; rightMargin: 2; verticalCenter: parent.verticalCenter }
        source: foot.spec && foot.spec.endMark ? foot.spec.endMark : ""
    }
    Text {
        anchors { right: endMark.visible ? endMark.left : parent.right; rightMargin: endMark.visible ? 6 : 2; verticalCenter: parent.verticalCenter }
        width: Math.min(implicitWidth, parent.width - lead.width - 16 - (endMark.visible ? endMark.width + 8 : 2))
        horizontalAlignment: Text.AlignRight
        text: foot.spec ? foot.spec.motto : ""
        color: foot.theme.inkSoft
        elide: Text.ElideLeft
        font { family: foot.theme.mono; pixelSize: 9; letterSpacing: 3 }
    }

    component Mark: Image {
        visible: source != ""
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        height: 16
        width: height * Math.max(1, implicitWidth) / Math.max(1, implicitHeight)
        sourceSize.height: 32
        fillMode: Image.PreserveAspectFit
    }
}
