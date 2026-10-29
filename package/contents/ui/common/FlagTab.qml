import QtQuick
import QtQuick.Shapes

// A section's header under sections.style "flagtab" (theme.flagTabs): a solid
// flag in the sections' bandColor (else the accent) with a 45° right edge,
// holding the skin's flagMark and the title in bandText (else white), "N — "
// before it when the sections are numbered; under cartoon outlines it is
// inked in black. It sits on the card's top-left edge; the density toggle
// takes the row's right end. On a bitmap frame with a `title` box
// (theme.cardFrame) it draws no flag: the title is set into that box, on the
// tab the picture paints, shrinking to fit it.
Item {
    id: flag

    property QtObject theme
    property string title: ""
    property int number: 0                // the section's place among those shown; 0: none

    readonly property var spec: theme.cardFrame
    readonly property bool onFrame: !!spec && !!spec.title
    x: onFrame ? spec.title[0] * spec.scale : 0
    y: onFrame ? spec.title[1] * spec.scale : 0
    z: onFrame ? 2 : 0                    // over the card it is set into
    implicitHeight: onFrame ? spec.title[3] * spec.scale : 18
    implicitWidth: onFrame ? spec.title[2] * spec.scale : row.implicitWidth + 10 + height

    Shape {
        visible: !flag.onFrame
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            readonly property real ink: flag.theme.cartoon ? 2 : 0
            fillColor: flag.theme.flagFill
            strokeColor: ink > 0 ? "#000000" : "transparent"
            strokeWidth: ink
            joinStyle: ShapePath.MiterJoin
            PathSvg { path: `M 1 1 H ${flag.width - 1} L ${flag.width - flag.height + 1} ${flag.height - 1} H 1 Z` }
        }
    }
    Row {
        id: row
        x: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5
        Image {
            id: mark
            visible: flag.theme.flagMark !== ""
            anchors.verticalCenter: parent.verticalCenter
            height: 11
            width: height * Math.max(1, implicitWidth) / Math.max(1, implicitHeight)
            source: flag.theme.flagMark
            sourceSize.height: 22
            fillMode: Image.PreserveAspectFit
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: flag.onFrame ? flag.width - row.x * 2 - (mark.visible ? mark.width + row.spacing : 0) : implicitWidth
            fontSizeMode: flag.onFrame ? Text.HorizontalFit : Text.FixedSize
            minimumPixelSize: 7
            text: flag.theme.sectionLabel(flag.title, flag.number)
            color: flag.theme.flagInk
            font {
                family: flag.theme.titleFamily
                pixelSize: flag.onFrame ? Math.max(7, Math.min(flag.theme.sansTitles ? flag.theme.titleSize : 14, Math.round(flag.height * 0.6))) : 11
                bold: flag.theme.titleBold
                letterSpacing: flag.theme.sansTitles ? 0.2 : 1.2
            }
        }
    }
}
