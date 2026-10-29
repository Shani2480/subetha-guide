import QtQuick
import QtQuick.Shapes

// A skeuomorphic round meter (geometry.gaugeShape "analog-dial"): a brushed
// chrome bezel (the skin's controls.dialRim art when it ships one), a dark
// face with white ticks every tenth of the scale, a glowing needle on a
// centre cap that sweeps to the reading, the reading and its caption in the
// middle, and a convex lens highlight over it all. `value` is 0..1 of the
// scale; a temperature dial (`temperature`) runs 0..controls.dialTempMax °C
// with a red zone from controls.dialDangerFrom. The skin's controls colours
// (dialFace, dialTicks, dialLens, needleUsage, needleTemp, dialDanger)
// replace the defaults.
Item {
    id: dial

    property QtObject theme
    property real value: 0                  // 0..1 of the scale
    property bool temperature: false
    property string valueText: ""
    property string caption: ""

    readonly property var spec: theme.controls || ({})
    function cc(key, fallback) { return theme.osColor("controls", key, fallback) }
    readonly property real tempMax: spec.dialTempMax || 100
    readonly property real dangerFrom: spec.dialDangerFrom || tempMax * 0.85
    readonly property color face: cc("dialFace", "#15181C")
    readonly property color ticks: cc("dialTicks", "#F2F4F6")
    readonly property color lens: cc("dialLens", "#FFFFFF")
    readonly property color danger: cc("dialDanger", "#E02A2A")
    readonly property color needle: temperature ? cc("needleTemp", theme.gaugeTemp.a > 0 ? theme.gaugeTemp : theme.amber)
                                                : cc("needleUsage", theme.gaugeUsage.a > 0 ? theme.gaugeUsage : theme.high)
    // the scale sweeps 240°, from lower left (-120° off straight up) to lower right
    readonly property real sweep: 240
    function angleOf(f) { return -sweep / 2 + sweep * Math.max(0, Math.min(1, f)) }
    readonly property real r: Math.min(width, height) / 2
    readonly property real rim: Math.max(3, r * 0.12)

    implicitWidth: 72
    implicitHeight: 72

    // ---- the bezel ----
    Image {
        visible: !!dial.spec.dialRim
        anchors.fill: parent
        source: dial.spec.dialRim || ""
        sourceSize: Qt.size(dial.width * 2, dial.height * 2)
    }
    Shape {   // brushed chrome: a conical sweep of light round the ring
        visible: !dial.spec.dialRim
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 1
            strokeColor: "#5A6068"
            fillRule: ShapePath.OddEvenFill
            fillGradient: ConicalGradient {
                centerX: dial.r; centerY: dial.r; angle: 45
                GradientStop { position: 0; color: "#F4F6F8" }
                GradientStop { position: 0.2; color: "#8A9098" }
                GradientStop { position: 0.45; color: "#E2E6EA" }
                GradientStop { position: 0.7; color: "#7C828A" }
                GradientStop { position: 1; color: "#F4F6F8" }
            }
            PathAngleArc { centerX: dial.r; centerY: dial.r; radiusX: dial.r - 0.5; radiusY: dial.r - 0.5; startAngle: 0; sweepAngle: 360 }
            PathAngleArc { centerX: dial.r; centerY: dial.r; radiusX: dial.r - dial.rim; radiusY: dial.r - dial.rim; startAngle: 0; sweepAngle: 360; moveToStart: true }
        }
    }

    // ---- the face ----
    Rectangle {
        anchors.centerIn: parent
        width: (dial.r - dial.rim) * 2; height: width
        radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.lighter(dial.face, 1.5) }
            GradientStop { position: 1; color: dial.face }
        }
    }
    Shape {   // the red zone, a temperature dial's top end
        visible: dial.temperature
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: dial.danger
            strokeWidth: Math.max(2, dial.r * 0.09)
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: dial.r; centerY: dial.r
                radiusX: dial.r - dial.rim - dial.r * 0.1; radiusY: radiusX
                startAngle: -90 + dial.angleOf(dial.dangerFrom / dial.tempMax)
                sweepAngle: dial.angleOf(1) - dial.angleOf(dial.dangerFrom / dial.tempMax)
            }
        }
    }
    Repeater {   // ticks, a long one every fifth
        model: 11
        Rectangle {
            required property int index
            readonly property bool major: index % 5 === 0
            x: dial.r - width / 2
            y: dial.rim + 2
            width: major ? 1.6 : 1
            height: major ? dial.r * 0.16 : dial.r * 0.1
            color: dial.ticks
            antialiasing: true
            transform: Rotation { origin.x: width / 2; origin.y: dial.r - dial.rim - 2; angle: dial.angleOf(index / 10) }
        }
    }

    // ---- reading ----
    Column {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.verticalCenter; topMargin: dial.r * 0.14 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: dial.valueText
            color: dial.ticks
            font { family: dial.theme.sans; pixelSize: Math.max(8, dial.r * 0.3); bold: true }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: dial.caption
            color: dial.ticks
            opacity: 0.7
            font { family: dial.theme.sans; pixelSize: Math.max(6, dial.r * 0.17) }
        }
    }

    // ---- the needle: a glow under a bright blade, on a cap ----
    Item {
        anchors.fill: parent
        rotation: dial.angleOf(dial.value)
        Behavior on rotation { NumberAnimation { duration: 600; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        Rectangle {
            x: dial.r - width / 2; y: dial.rim + dial.r * 0.12
            width: Math.max(3, dial.r * 0.11); height: dial.r - dial.rim - dial.r * 0.12
            radius: width / 2
            color: dial.needle
            opacity: 0.35
        }
        Rectangle {
            x: dial.r - width / 2; y: dial.rim + dial.r * 0.14
            width: Math.max(1.5, dial.r * 0.05); height: dial.r - dial.rim - dial.r * 0.14 + dial.r * 0.12
            radius: width / 2
            color: dial.needle
            antialiasing: true
        }
    }
    Rectangle {   // the cap
        anchors.centerIn: parent
        width: dial.r * 0.22; height: width; radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0; color: "#E8ECEF" }
            GradientStop { position: 1; color: "#5C636B" }
        }
        border { width: 0.5; color: "#2A2E33" }
    }

    // ---- the lens: a convex gloss over the top half ----
    Rectangle {
        x: dial.rim + dial.r * 0.08; y: dial.rim + 1
        width: (dial.r - dial.rim - dial.r * 0.08) * 2; height: (dial.r - dial.rim) * 0.95
        radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(dial.lens.r, dial.lens.g, dial.lens.b, 0.38) }
            GradientStop { position: 1; color: Qt.rgba(dial.lens.r, dial.lens.g, dial.lens.b, 0.0) }
        }
    }
}
