import QtQuick

// Load and temperature on one segmented track, in the same blocks as the
// other gauges. Each block lights in two layers: behind, a translucent wash
// for the temperature on a 30-100 °C scale (amber on the CRT, mustard on the
// movie pages), turning orange from warnPercent of the scale and pulsing red
// from criticalPercent (with `alerts` off it keeps its resting colour); in
// front, a solid inset fill for the load, coloured like every load gauge
// (good / busy / hot). A skin may set its own track, load fill (outlined) and
// resting temperature wash (gaugeTrack, gaugeUsage, gaugeTemp); the warm and
// hot alerts keep their colours.
Item {
    id: bar

    property QtObject theme
    property real usageFraction: 0        // 0..1
    property real tempValue: 0            // °C; 0 or less: no temperature layer
    property real minTemp: 30
    property real maxTemp: 100
    property bool alerts: true
    property int warnPercent: 80          // of the temperature scale
    property int criticalPercent: 90
    property bool live: false             // gates the warning pulse
    property int segments: 24
    property real segmentHeight: 9

    readonly property real tempFraction: tempValue > 0 ? Math.max(0, Math.min(1, (tempValue - minTemp) / (maxTemp - minTemp))) : 0
    readonly property bool warm: alerts && tempValue > 0 && tempFraction * 100 >= warnPercent
    readonly property bool hot: alerts && tempValue > 0 && tempFraction * 100 >= criticalPercent
    readonly property int loadFilled: Math.round(Math.max(0, Math.min(1, usageFraction)) * segments)
    readonly property int tempFilled: Math.round(tempFraction * segments)
    readonly property real load: usageFraction * 100
    readonly property bool skinFill: theme.gaugeUsage.a > 0
    readonly property color loadColor: skinFill ? theme.gaugeUsage : load >= 85 ? theme.low : load >= 50 ? theme.mid : theme.high
    readonly property color tempColor: hot ? theme.red : warm ? "#FF8A1A" : theme.gaugeTemp.a > 0 ? theme.gaugeTemp
                                     : theme.dark ? theme.amber : theme.mustard

    // 0 = resting wash, 1 = brightest; pulses only while hot and on screen.
    property real pulse: 0
    SequentialAnimation on pulse {
        running: bar.hot && bar.live
        loops: Animation.Infinite
        onRunningChanged: if (!running) bar.pulse = 0
        NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 600; easing.type: Easing.InOutSine }
    }
    // a skin's wash carries its own alpha
    readonly property real tempOpacity: (hot ? 0.45 : warm ? 0.5 : theme.gaugeTemp.a > 0 ? 1 : theme.dark ? 0.35 : 0.3) + pulse * 0.3

    readonly property real spacing: 2
    implicitWidth: 160
    implicitHeight: segmentHeight

    Row {
        spacing: bar.spacing
        Repeater {
            model: bar.segments
            Rectangle {   // one block: outline, temperature wash, load fill
                required property int index
                readonly property bool loaded: index < bar.loadFilled
                width: (bar.width - bar.spacing * (bar.segments - 1)) / bar.segments
                height: bar.segmentHeight
                radius: bar.theme.dark ? 0 : Math.min(2, height / 2)
                color: "transparent"
                border.width: 1
                border.color: loaded ? (bar.skinFill ? bar.theme.border : bar.loadColor)
                            : bar.theme.gaugeTrack.a > 0 ? bar.theme.gaugeTrack : bar.theme.tint(bar.theme.dark ? 0.3 : 0.45)
                Rectangle {   // temperature, behind
                    visible: index < bar.tempFilled
                    anchors.fill: parent
                    radius: parent.radius
                    color: bar.tempColor
                    opacity: bar.tempOpacity
                }
                Rectangle {   // load, in front; a skin's fill is the whole block, outlined
                    visible: parent.loaded
                    anchors { fill: parent; margins: bar.skinFill ? 0 : parent.height >= 7 ? 2 : 1 }
                    radius: bar.skinFill ? parent.radius : bar.theme.dark ? 0 : 1
                    color: bar.loadColor
                    border { width: bar.skinFill ? 1.5 : 0; color: bar.theme.border }
                }
            }
        }
    }
}
