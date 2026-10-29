import QtQuick

// A cartoon glass thermometer (controls.thermometer): a round bulb and a
// tube outlined in thick ink, the red fluid risen to `value` °C over
// `minC`..`maxC`, a tick every tenth of the scale and a gleam down the glass.
Item {
    id: thermo

    property QtObject theme
    property real value: 15
    property real minC: -20
    property real maxC: 40
    property color fluid: "#E8312A"
    property color ink: theme ? theme.border : "black"
    readonly property real level: Math.max(0, Math.min(1, (value - minC) / (maxC - minC)))
    readonly property real tubeW: Math.max(6, width * 0.42)
    readonly property real bulb: Math.min(width, height * 0.36)

    implicitWidth: 18
    implicitHeight: 52

    Rectangle {   // the tube's glass
        id: tube
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: thermo.tubeW; height: parent.height - thermo.bulb * 0.6
        radius: width / 2
        color: Qt.rgba(1, 1, 1, 0.85)
        border { width: 2; color: thermo.ink }
        Rectangle {   // the fluid column
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 2 }
            width: parent.width - 6
            height: (parent.height - 6) * thermo.level + 4
            radius: width / 2
            color: thermo.fluid
            Behavior on height { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        }
        Repeater {   // ticks
            model: 9
            Rectangle {
                required property int index
                x: parent.width - 2; y: 4 + (parent.height - 8) * (index + 1) / 10
                width: index % 2 === 0 ? 4 : 2; height: 1.2
                color: thermo.ink
            }
        }
        Rectangle {   // the gleam down the glass
            x: 2; y: 4; width: 1.5; height: parent.height * 0.6
            radius: 1; color: "white"; opacity: 0.8
        }
    }
    Rectangle {   // the bulb
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
        width: thermo.bulb; height: width; radius: width / 2
        color: thermo.fluid
        border { width: 2; color: thermo.ink }
        Rectangle { x: parent.width * 0.22; y: parent.height * 0.2; width: parent.width * 0.25; height: width; radius: width / 2; color: "white"; opacity: 0.6 }
    }
}
