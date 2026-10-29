import QtQuick
import QtQuick.Shapes

// A section's header under sections.style "flagtab" (theme.flagTabs): a solid
// flag in the sections' bandColor (else the accent) with a 45° right edge,
// holding the skin's flagMark and the title in bandText (else white), "N — "
// before it when the sections are numbered; under cartoon outlines it is
// inked in black. It sits on the card's top-left edge; the density toggle
// takes the row's right end.
Item {
    id: flag

    property QtObject theme
    property string title: ""
    property int number: 0                // the section's place among those shown; 0: none

    implicitHeight: 18
    implicitWidth: row.implicitWidth + 10 + height

    Shape {
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
            text: flag.theme.sectionLabel(flag.title, flag.number)
            color: flag.theme.flagInk
            font { family: flag.theme.mono; pixelSize: 11; bold: true; letterSpacing: 1.2 }
        }
    }
}
