import QtQuick

// Load and temperature on one segmented track, in the same blocks as the
// other gauges. Each block lights in two layers: behind, a translucent wash
// for the temperature on a 30-100 °C scale (amber on the CRT, mustard on the
// movie pages), steady orange at a temperature warning (`tempLevel` 1) and
// a glowing crimson strobe when critical (2); in front, a solid inset fill
// for the load, coloured like every load gauge (good / busy / hot), that
// pulses between full brightness and hazard amber when the load is critical
// (`loadLevel` 2). The levels come from the AlertManager; with `animate` off
// they keep their colours without the motion. A skin may set its own track, load fill (outlined) and
// resting temperature wash (gaugeTrack, gaugeUsage, gaugeTemp), the fill's
// edge, and a temperature above which the wash pulses (tempPulseC). The
// theme's gaugeShape picks blocks ("segmented") or one continuous bar, square
// ("flat"), capsule ("stadium", a glass tube for a "tube" skin) or cut at 45°
// ("chamfer"). The warm and hot alerts keep their colours.
Item {
    id: bar

    property QtObject theme
    property real usageFraction: 0        // 0..1
    property real tempValue: 0            // °C; 0 or less: no temperature layer
    property real minTemp: 30
    property real maxTemp: 100
    property int tempLevel: 0             // 0 nominal, 1 warning, 2 critical
    property int loadLevel: 0             // 0 nominal, 2 critical
    property bool animate: !!theme && theme.alertMotion
    property bool live: false             // gates the pulses
    property int segments: 24
    property real segmentHeight: 9

    readonly property real tempFraction: tempValue > 0 ? Math.max(0, Math.min(1, (tempValue - minTemp) / (maxTemp - minTemp))) : 0
    readonly property bool warm: tempValue > 0 && tempLevel === 1
    readonly property bool hot: tempValue > 0 && tempLevel === 2
    readonly property int loadFilled: Math.round(Math.max(0, Math.min(1, usageFraction)) * segments)
    readonly property int tempFilled: Math.round(tempFraction * segments)
    readonly property real load: usageFraction * 100
    readonly property bool skinFill: theme.gaugeUsage.a > 0
    readonly property color restingLoad: skinFill ? theme.gaugeUsage : load >= 85 ? theme.low : load >= 50 ? theme.mid : theme.high
    // critical load: full brightness <-> hazard amber
    readonly property color loadColor: loadLevel === 2 ? theme.mix(Qt.lighter(restingLoad, 1.25), theme.warnColor, hazard)
                                                       : restingLoad
    readonly property color tempColor: hot ? theme.critColor : warm ? "#FF8A1A" : theme.gaugeTemp.a > 0 ? theme.gaugeTemp
                                     : theme.dark || theme.skinned ? theme.amber : theme.mustard

    // 0 = resting wash, 1 = brightest; a skin's tempPulseC breathes the wash.
    readonly property bool pulsing: !hot && theme.tempPulseC > 0 && tempValue >= theme.tempPulseC
    readonly property bool moving: animate && live
    property real pulse: 0
    SequentialAnimation on pulse {
        running: bar.pulsing && bar.moving
        loops: Animation.Infinite
        onRunningChanged: if (!running) bar.pulse = 0
        NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 600; easing.type: Easing.InOutSine }
    }
    // critical temperature: a hard strobe, dim <-> glowing
    property real strobe: 1
    SequentialAnimation on strobe {
        running: bar.hot && bar.moving
        loops: Animation.Infinite
        onRunningChanged: if (!running) bar.strobe = 1
        NumberAnimation { to: 0.25; duration: 90 }
        PauseAnimation { duration: 160 }
        NumberAnimation { to: 1; duration: 90 }
        PauseAnimation { duration: 160 }
    }
    property real hazard: 0
    SequentialAnimation on hazard {
        running: bar.loadLevel === 2 && bar.moving
        loops: Animation.Infinite
        onRunningChanged: if (!running) bar.hazard = 0
        NumberAnimation { to: 1; duration: 450; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 450; easing.type: Easing.InOutSine }
    }
    // a skin's wash carries its own alpha
    readonly property real tempOpacity: hot ? 0.95 * strobe
                                      : (warm ? 0.5 : theme.gaugeTemp.a > 0 ? 1 : theme.dark ? 0.35 : 0.3) + pulse * 0.3

    implicitWidth: 160
    implicitHeight: segmentHeight

    DynamicMetricGauge {   // drawn in the theme's gauge shape; the colours and motion are this bar's
        width: bar.width; height: bar.segmentHeight
        theme: bar.theme
        shape: bar.theme.skinned ? bar.theme.gaugeShape : bar.theme.gaugeSlot ? "slot" : "segmented"
        segments: bar.segments
        blockStyle: "inset"
        value: bar.usageFraction
        secondary: bar.tempValue > 0 ? bar.tempFraction : -1
        fillColor: bar.loadColor
        secondaryColor: bar.tempColor
        secondaryOpacity: bar.tempOpacity
        outlined: bar.skinFill
        live: bar.live
        glow: bar.hot
        glowOpacity: 0.55 * bar.strobe
    }
}
