import QtQuick

// A Guide pill: rounded card with a 2px outline and, on the movie pages, a
// flat 2px offset shadow. It slides in from the left (x -30 -> 0, scale
// 0.9 -> 1, 260 ms OutBack, staggered 45 ms per cascadeIndex) when it is
// created or entranceSerial changes, and its border pulses badge -> alert
// while `critical`. Content goes inside, padded; the pill sizes to it.
Item {
    id: pill

    property QtObject theme
    property bool live: false            // on screen; gates every animation
    property int entranceSerial: 0
    property int cascadeIndex: 0
    property bool critical: false
    property real radius: theme.pillRadius
    property real horizontalPadding: 14
    property real verticalPadding: 10
    default property alias content: inner.data

    // 0 = badge colour, 1 = alert; animates only while critical and live.
    property real pulse: 0
    readonly property color borderColor: critical ? theme.mix(theme.badge, theme.alert, pulse)
                                       : theme.dark ? theme.tint(0.7) : theme.ink
    // Warning text: mustard is unreadable on cream, so light stays red.
    readonly property color alertInk: theme.dark ? borderColor : theme.alert

    implicitHeight: inner.childrenRect.height + verticalPadding * 2 + 2
    // A pill that switches size (small <-> large) grows or shrinks over 200 ms
    // instead of jumping, its content clipped to the moving outline.
    property bool animateHeight: false
    Behavior on implicitHeight {
        enabled: pill.animateHeight && pill.live
        NumberAnimation { id: grow; duration: 200; easing.type: Easing.OutCubic }
    }
    clip: grow.running

    transform: [
        Translate { id: slide },
        Scale { id: pop; origin.x: pill.width / 2; origin.y: pill.height / 2 }
    ]
    function enter() {
        if (!live) { entrance.stop(); slide.x = 0; pop.xScale = pop.yScale = 1; pill.opacity = 1; return }
        entrance.restart()
    }
    Component.onCompleted: enter()
    onEntranceSerialChanged: enter()
    SequentialAnimation {
        id: entrance
        ScriptAction { script: { slide.x = -30; pop.xScale = pop.yScale = 0.9; pill.opacity = 0 } }
        PauseAnimation { duration: Math.max(0, pill.cascadeIndex) * 45 }   // index is -1 while a delegate is torn down
        ParallelAnimation {
            NumberAnimation { target: slide; property: "x"; to: 0; duration: 260; easing.type: Easing.OutBack }
            NumberAnimation { target: pop; property: "xScale"; to: 1; duration: 260; easing.type: Easing.OutBack }
            NumberAnimation { target: pop; property: "yScale"; to: 1; duration: 260; easing.type: Easing.OutBack }
            NumberAnimation { target: pill; property: "opacity"; to: 1; duration: 140 }
        }
    }

    SequentialAnimation on pulse {
        running: pill.critical && pill.live
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 550; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 550; easing.type: Easing.InOutSine }
    }

    Rectangle {   // flat offset shadow (light)
        visible: pill.theme.flatShadow
        x: 2; y: 2
        width: face.width; height: face.height
        radius: face.radius
        color: pill.theme.ink
    }
    Rectangle {
        id: face
        anchors { fill: parent; rightMargin: 2; bottomMargin: 2 }
        radius: pill.radius
        color: pill.theme.card
        border.width: 2
        border.color: pill.borderColor
    }
    Item {
        id: inner
        anchors {
            left: face.left; right: face.right; top: face.top
            leftMargin: pill.horizontalPadding; rightMargin: pill.horizontalPadding; topMargin: pill.verticalPadding
        }
    }
}
