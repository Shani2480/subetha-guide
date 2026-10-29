import QtQuick

// A cartoon lab mainframe dressed round the whole Guide (frame.style
// "console"), drawn by GuideWindow around its body:
//   the top rail   the skin's tube art at both ends (frame.tubes, the right
//                  one mirrored), its siren at the top centre (frame.siren),
//                  flashing while a reading is critical (theme.mood), over a
//                  bevelled name plaque (plaqueTitle, plaqueSubtitle)
//   the pillars    narrow side wings of toggle switches, round red, yellow
//                  and green buttons and bulbs, only when the widget is wide
//   the rail       a conduit of LED segments along the bottom, lit by the
//                  busier of CPU and GPU (theme.meterA)
// Everything is outlined in the border colour, 3px under cartoon outlines.
Item {
    id: console_

    property QtObject theme
    readonly property var spec: theme.frame || ({})
    readonly property real topHeight: 64
    readonly property real sideWidth: spec.pillars !== false && width >= 400 ? 30 : 0
    readonly property real bottomHeight: spec.rail !== false ? 18 : 0
    readonly property real line: theme.cartoon ? 3 : 2
    readonly property color ink: theme.border
    readonly property color metal: Qt.darker(theme.card, theme.dark ? 0.8 : 1.12)
    readonly property bool alarm: theme.mood === "stressed"

    // ---- the cabinet ----
    Rectangle {
        anchors.fill: parent
        radius: 12
        color: console_.metal
        border { width: console_.line; color: console_.ink }
    }

    // ---- the top rail ----
    Image {
        visible: !!console_.spec.tubes
        x: 8; y: 6
        width: 64; height: console_.topHeight - 10
        source: console_.spec.tubes || ""
        sourceSize: Qt.size(128, 108)
        fillMode: Image.PreserveAspectFit
        horizontalAlignment: Image.AlignLeft
    }
    Image {
        visible: !!console_.spec.tubes
        x: parent.width - width - 8; y: 6
        width: 64; height: console_.topHeight - 10
        source: console_.spec.tubes || ""
        sourceSize: Qt.size(128, 108)
        fillMode: Image.PreserveAspectFit
        horizontalAlignment: Image.AlignLeft
        mirror: true
    }
    Image {   // the siren
        id: siren
        visible: !!console_.spec.siren
        anchors.horizontalCenter: parent.horizontalCenter
        y: 3
        width: 22; height: 18
        source: console_.spec.siren || ""
        sourceSize: Qt.size(44, 36)
        fillMode: Image.PreserveAspectFit
        SequentialAnimation on opacity {
            running: console_.alarm && console_.theme.alertMotion
            loops: Animation.Infinite
            onRunningChanged: if (!running) siren.opacity = 1
            NumberAnimation { to: 0.25; duration: 220 }
            NumberAnimation { to: 1; duration: 220 }
        }
        Rectangle {   // the beacon's glow while it flashes
            visible: console_.alarm
            anchors.centerIn: parent
            width: parent.width * 1.8; height: width; radius: width / 2
            color: "#E8312A"; opacity: 0.25; z: -1
        }
    }
    Rectangle {   // the plaque
        id: plaque
        anchors.horizontalCenter: parent.horizontalCenter
        y: 22
        width: Math.min(parent.width - 160, Math.max(plaqueTitle.implicitWidth, plaqueSub.implicitWidth) + 28)
        height: 36
        radius: 6
        border { width: console_.line; color: console_.ink }
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.lighter(console_.spec.plaque || console_.theme.accent, 1.3) }
            GradientStop { position: 1; color: console_.spec.plaque || console_.theme.accent }
        }
        Rectangle {   // the bevel's lit upper edge
            x: 4; y: 3; width: parent.width - 8; height: 1.5
            color: "white"; opacity: 0.6
        }
        Column {
            anchors.centerIn: parent
            Text {
                id: plaqueTitle
                anchors.horizontalCenter: parent.horizontalCenter
                text: console_.spec.plaqueTitle || console_.theme.lex("appTitle", "THE SUB-ETHA GUIDE", "SYSTEM GUIDE")
                color: console_.spec.plaqueText || console_.theme.ink
                font { family: console_.theme.sans; pixelSize: 13; bold: true; letterSpacing: 0.8 }
            }
            Text {
                id: plaqueSub
                visible: text !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                text: console_.spec.plaqueSubtitle || ""
                color: console_.spec.plaqueSubtext || console_.theme.inkSoft
                font { family: console_.theme.sans; pixelSize: 8; bold: true; letterSpacing: 1 }
            }
        }
    }

    // ---- the pillars ----
    Repeater {
        model: console_.sideWidth > 0 ? 2 : 0
        Column {
            required property int index
            x: index === 0 ? 5 : console_.width - console_.sideWidth + 5
            y: console_.topHeight + 8
            width: console_.sideWidth - 10
            spacing: 9
            Repeater {   // toggle switches
                model: 2
                Rectangle {
                    width: parent.width; height: 14; radius: 3
                    color: Qt.darker(console_.metal, 1.25)
                    border { width: 1.5; color: console_.ink }
                    Rectangle { x: 2; y: 2; width: parent.width / 2 - 2; height: parent.height - 4; radius: 2; color: "#E8E8E8"; border { width: 1; color: console_.ink } }
                }
            }
            Repeater {   // round buttons
                model: ["#E8312A", "#F2D43C", "#3CC23C"]
                Rectangle {
                    required property color modelData
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 14; height: 14; radius: 7
                    color: modelData
                    border { width: 1.5; color: console_.ink }
                    Rectangle { x: 3; y: 2.5; width: 4; height: 3; radius: 2; color: "white"; opacity: 0.6 }
                }
            }
            Repeater {   // bulbs, glowing in turn
                model: 2
                Rectangle {
                    id: bulb
                    required property int index
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 12; height: 16; radius: 6
                    color: "#FFE680"
                    border { width: 1.5; color: console_.ink }
                    SequentialAnimation on opacity {
                        running: console_.theme.live
                        loops: Animation.Infinite
                        PauseAnimation { duration: bulb.index * 700 }
                        NumberAnimation { to: 0.45; duration: 700 }
                        NumberAnimation { to: 1; duration: 700 }
                    }
                }
            }
        }
    }

    // ---- the rail ----
    Rectangle {
        visible: console_.bottomHeight > 0
        x: 10; y: parent.height - console_.bottomHeight + 1
        width: parent.width - 20; height: console_.bottomHeight - 6
        radius: height / 2
        color: Qt.darker(console_.metal, 1.4)
        border { width: 1.5; color: console_.ink }
        Row {
            id: leds
            anchors { fill: parent; margins: 3; leftMargin: 8; rightMargin: 8 }
            spacing: 3
            readonly property int n: Math.max(4, Math.floor(width / 14))
            readonly property int lit: Math.round(Math.max(0, Math.min(1, console_.theme.meterA)) * n)
            Repeater {
                model: leds.n
                Rectangle {
                    required property int index
                    readonly property real t: index / Math.max(1, leds.n - 1)
                    width: (leds.width - leds.spacing * (leds.n - 1)) / leds.n; height: leds.height
                    radius: 2
                    color: index < leds.lit ? (t < 0.6 ? "#3CC23C" : t < 0.85 ? "#F2D43C" : "#E8312A") : Qt.rgba(1, 1, 1, 0.1)
                }
            }
        }
    }
}
