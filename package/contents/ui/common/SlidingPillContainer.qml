import QtQuick

// A Guide pill: the theme's pill shape (ThemeShapeContainer), outlined and
// shadowed as the theme has it: a capsule with a flat 2px offset shadow on
// the movie pages, sharp with a phosphor glow on the terminal. It slides in
// from the left (x -30 -> 0, scale 0.9 -> 1, 260 ms OutBack, staggered 45 ms
// per cascadeIndex) when it is created or entranceSerial changes. At an
// alert (`alertLevel`, or 2 while `critical`) its border turns amber or
// crimson and an AlertGlowContainer haloes it, breathing when critical.
// Content goes inside, padded; the pill sizes to it.
// With a `monitorTab` set, double-clicking the pill emits monitorRequested
// for that tab of the System Monitor (controls inside keep their own clicks).
Item {
    id: pill

    property QtObject theme
    property bool live: false            // on screen; gates every animation
    property int entranceSerial: 0
    property int cascadeIndex: 0
    property bool critical: false
    property int alertLevel: critical ? 2 : 0   // 0 nominal, 1 warning, 2 critical
    property real radius: theme.pillRadius
    property real horizontalPadding: 14
    property real verticalPadding: 10
    property color tint: "transparent"   // a skin's surface for this kind of card (sections.tints)
    property string monitorTab: ""        // overview sensors processes services network disks; "" = no link
    property string art: ""               // a skin's picture against the pill's right edge, behind the content
    default property alias content: inner.data

    signal monitorRequested(string tab)

    readonly property color borderColor: alertLevel === 2 ? theme.critColor : alertLevel === 1 ? theme.warnColor
                                       : theme.dark ? theme.tint(0.7) : theme.ink
    // text at the pill's alert level
    readonly property color alertInk: alertLevel === 1 ? theme.warnColor : theme.critColor

    // a capsule's round ends take a little more room at the sides
    readonly property real sidePadding: horizontalPadding + (shell.shape === "stadium" ? Math.round(shell.radius * 0.25) : 0)
    implicitHeight: inner.childrenRect.height + verticalPadding * 2 + Math.abs(theme.shadowY)
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

    AlertGlowContainer {
        anchors.fill: shell
        theme: pill.theme
        role: "pill"
        alertLevel: pill.alertLevel
        animate: pill.theme.alertMotion && pill.live
    }

    ThemeShapeContainer {
        id: shell
        anchors.fill: parent
        theme: pill.theme
        role: "pill"
        // in a Win32 group (theme.groupBands) a pill is a plain row over a hairline rule
        fillColor: pill.tint.a > 0 ? pill.tint : pill.theme.groupBands ? "transparent" : pill.theme.card
        strokeColor: pill.borderColor
        strokeWidth: pill.alertLevel > 0 ? Math.max(2, pill.theme.borderWidth) : pill.theme.groupBands ? 0 : pill.theme.borderWidth
        shadowType: pill.theme.groupBands ? "none" : pill.theme.shadowType
        cornerRadius: pill.radius
        bracketSize: 7
        bracketInset: 3
    }
    Rectangle {
        visible: pill.theme.groupBands
        anchors.bottom: parent.bottom
        width: parent.width; height: 1
        color: pill.theme.osColor("sections", "rule", pill.theme.tint(pill.theme.dark ? 0.25 : 0.18))
    }
    Screws {
        visible: pill.theme.screws
        x: shell.face.x; y: shell.face.y; width: shell.face.width; height: shell.face.height
        inset: 4; size: 6
        ink: pill.theme.border
    }
    Image {
        visible: source != ""
        x: shell.face.x + shell.face.width - width - pill.theme.borderWidth - 2
        y: shell.face.y + pill.theme.borderWidth + 2
        height: shell.face.height - (pill.theme.borderWidth + 2) * 2
        width: Math.min(shell.face.width * 0.45, height * 3)
        source: pill.art
        sourceSize: Qt.size(width * 2, height * 2)
        fillMode: Image.PreserveAspectFit
        horizontalAlignment: Image.AlignRight
        opacity: 0.35
    }
    TapHandler {
        enabled: pill.monitorTab !== ""
        onDoubleTapped: pill.monitorRequested(pill.monitorTab)
    }

    Item {   // placed, not anchored: the face is not a sibling
        id: inner
        x: shell.face.x + pill.sidePadding
        y: shell.face.y + pill.verticalPadding
        width: shell.face.width - pill.sidePadding * 2
    }
}
