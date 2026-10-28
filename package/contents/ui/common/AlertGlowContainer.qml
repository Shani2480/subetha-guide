import QtQuick

// An alert halo for a card or pill, in the theme's own shape for `role`
// (ThemeShapeContainer), drawn just outside its bounds so the layout never
// moves. Warning (1): a steady amber outline. Critical (2): a crimson outline
// and glow that breathes (opacity 0.2 <-> 0.9, 600 ms each way, sine) while
// `animate` is on, or holds at full strength while it is off. Nominal (0):
// nothing. Put it over the card it marks (anchors.fill); content placed
// inside sits above the halo.
Item {
    id: root

    property QtObject theme
    property string role: "pill"          // card | pill
    property int alertLevel: 0            // 0 nominal, 1 warning, 2 critical
    property bool animate: !!theme && theme.alertMotion   // the breathing; the owner folds in its own `live`
    property real spread: 3               // px outside the bounds
    default property alias content: innerContent.data

    readonly property color tone: alertLevel === 2 ? theme.critColor : theme.warnColor

    property real breath: 0.9
    SequentialAnimation on breath {
        running: root.alertLevel === 2 && root.animate
        loops: Animation.Infinite
        onRunningChanged: if (!running) root.breath = 0.9
        NumberAnimation { to: 0.2; duration: 600; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.9; duration: 600; easing.type: Easing.InOutSine }
    }

    ThemeShapeContainer {
        id: halo
        visible: root.alertLevel > 0
        anchors { fill: parent; margins: -root.spread }
        theme: root.theme
        role: root.role
        fillColor: "transparent"
        strokeColor: root.tone
        strokeWidth: 2
        borderStyle: "solid"
        cornerBrackets: false
        shadowType: root.alertLevel === 2 ? "glow" : "none"
        shadowColor: root.tone
        shadowBlur: 8
        opacity: root.alertLevel === 2 ? root.breath : 0.75
    }

    Item {
        id: innerContent
        anchors.fill: parent
    }
}
