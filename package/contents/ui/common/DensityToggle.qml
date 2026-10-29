import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Shapes

// A section's density switch: a small monospace tag, "[ - ]" while the
// section is full and "[ + ]" while compact, worn like a legend on the top
// border of the section's card (top-right corner, half above the edge) so it
// costs no height in either mode. Clicking emits `toggled`; the owner writes
// the new density back to the configuration. A skin's sections.toggle
// (theme.toggleStyle) draws it as an angled outlined pill in thin mono, a
// rounded glass button glossed over its top half, or a sharp box inked in
// black with a flat offset shadow. Under flag-tab sections (theme.flagTabs)
// it sits at the right end of the flag's row, the card's top-right corner;
// on a bitmap frame (theme.cardFrame), inside it, just above the content.
Rectangle {
    id: tag

    property QtObject theme
    property bool compact: false

    signal toggled()

    readonly property string kind: theme.toggleStyle
    readonly property bool angled: kind === "angled"
    readonly property bool drawn: kind !== ""     // its own picture, not the plain tag
    readonly property bool inRow: theme.flagTabs
    readonly property var frameSpec: theme.cardFrame
    anchors {
        top: parent.top; right: parent.right
        topMargin: !frameSpec ? (inRow ? 0 : -height / 2 + 1)
                 : frameSpec.toggle ? frameSpec.toggle[1] * frameSpec.scale
                 : Math.max(0, frameSpec.content[1] * frameSpec.scale - height - 2)
        rightMargin: !frameSpec ? (inRow ? 0 : 18)
                   : frameSpec.toggle ? frameSpec.toggle[0] * frameSpec.scale : frameSpec.content[2] * frameSpec.scale + 2
    }
    z: 20
    width: label.implicitWidth + (angled ? 10 + height : drawn ? 14 : 10)
    height: angled || inRow ? 18 : drawn ? 16 : label.implicitHeight + 2
    radius: theme.skinned ? Math.min(4, theme.pillRadius) : 4
    readonly property bool hot: area.containsMouse
    color: drawn ? "transparent" : hot ? theme.ink : theme.bg
    border.width: drawn ? 0 : theme.stroke(1, 1.5)
    border.color: theme.dark ? theme.tint(hot ? 1 : 0.55) : theme.ink

    Rectangle {   // glass: a rounded Aero button, a gloss over its top half
        visible: tag.kind === "glass"
        anchors.fill: parent
        radius: 5
        border { width: 1; color: tag.theme.dark ? Qt.rgba(0.7, 0.9, 1, 0.45) : Qt.rgba(0.2, 0.4, 0.5, 0.45) }
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, tag.hot ? 0.5 : 0.32) }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, tag.hot ? 0.22 : 0.1) }
            GradientStop { position: 0.51; color: Qt.rgba(0, 0, 0, 0.08) }
            GradientStop { position: 1; color: Qt.rgba(tag.theme.accent.r, tag.theme.accent.g, tag.theme.accent.b, tag.hot ? 0.45 : 0.22) }
        }
    }
    Rectangle {   // box: a flat 2px offset shadow under...
        visible: tag.kind === "box"
        x: 2; y: 2; width: parent.width; height: parent.height
        color: "#000000"
    }
    Rectangle {   // ...a sharp square inked in black
        visible: tag.kind === "box"
        anchors.fill: parent
        color: tag.hot ? tag.theme.accent : tag.theme.card
        border { width: 2; color: "#000000" }
    }

    Shape {   // the angled pill: both ends slanted at 45°, outlined in the accent
        visible: tag.angled
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            id: pill
            readonly property real s: tag.height / 2
            fillColor: tag.hot ? tag.theme.accent : tag.theme.bg
            strokeColor: tag.theme.accent
            strokeWidth: 1
            joinStyle: ShapePath.MiterJoin
            PathSvg { path: `M ${pill.s + 0.5} 0.5 H ${tag.width - 0.5} L ${tag.width - pill.s - 0.5} ${tag.height - 0.5} H 0.5 Z` }
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: tag.compact ? "[ + ]" : "[ - ]"
        color: tag.angled ? (tag.hot ? "#FFFFFF" : tag.theme.ink)
             : tag.kind === "box" ? (tag.hot ? tag.theme.readableOn(tag.theme.accent, "#000000") : tag.theme.ink)
             : tag.kind === "glass" ? tag.theme.ink
             : tag.hot ? tag.theme.bg : tag.theme.ink
        font { family: tag.theme.mono; pixelSize: tag.angled ? 10 : 9; bold: !tag.angled; letterSpacing: tag.angled ? 1 : 0 }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -3   // a slightly larger hit target than the tag
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tag.toggled()
    }
    QQC2.ToolTip.visible: area.containsMouse
    QQC2.ToolTip.text: i18n("Toggle Compact / Full telemetry")
    QQC2.ToolTip.delay: 400
}
