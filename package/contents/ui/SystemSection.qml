import QtQuick
import QtQuick.Layouts
import "system"
import "common"

// The compute module: CPU, RAM, GPU, network and fan pills with the optional
// host profile and sparklines (SystemPanel). Full mode ends with a terminal
// pill that opens the process and service diagnostics. While the section is
// full each pill is small or large on its own (config.<sensor>SensorSize).
CollapsibleSection {
    id: section

    property QtObject theme
    property QtObject feed                // a SystemFeed
    property var config
    property var sensors: []
    property bool minimal: false          // this section's density is "compact"
    property bool live: false
    property int entranceSerial: 0

    signal diagnosticsRequested()
    signal densityToggled()
    signal sensorSizeChosen(string key, string size)   // key: cpu ram gpu net fan

    function sizeKey(kind) { return kind === "fans" ? "fan" : kind }

    ModuleCard {
        width: parent.width
        theme: section.theme
        minimal: section.minimal
        onDensityToggled: section.densityToggled()
        title: i18n("COMPUTE // EDDIE CORE")
        glyph: "M7 7 H17 V17 H7 Z M9.5 9.5 H14.5 V14.5 H9.5 Z M9 7 V4 M12 7 V4 M15 7 V4 M9 17 V20 M12 17 V20 M15 17 V20 M7 9 H4 M7 12 H4 M7 15 H4 M17 9 H20 M17 12 H20 M17 15 H20"
        // Created once the feed and settings are attached, so no binding
        // runs against a null feed while the card is being built.
        Loader {
            Layout.fillWidth: true
            active: section.feed !== null && section.config !== undefined
            sourceComponent: Component {
                SystemPanel {
                    theme: section.theme
                    telemetry: section.feed
                    sensors: section.sensors
                    tempUnit: section.config.tempUnit
                    showFanPercent: section.config.showFanPercent
                    fanMaxRpm: section.config.fanMaxRpm
                    tempAlerts: section.config.tempColorAlerts
                    tempWarnPercent: section.config.tempWarnPercent
                    tempCriticalPercent: section.config.tempCriticalPercent
                    interval: section.feed.interval
                    showGraphs: section.config.showTelemetryGraphs
                    showSpecs: section.config.showSystemSpecs
                    minimal: section.minimal
                    sizes: ({ cpu: section.config.cpuSensorSize, ram: section.config.ramSensorSize,
                              gpu: section.config.gpuSensorSize, net: section.config.netSensorSize,
                              fans: section.config.fanSensorSize })
                    onSizeToggled: kind => section.sensorSizeChosen(section.sizeKey(kind),
                                                                    sizes[kind] === "small" ? "large" : "small")
                    live: section.live && section.open
                    entranceSerial: section.entranceSerial
                }
            }
        }

        Rectangle {   // [LAUNCH FULL PROCESS DIAGNOSTICS]
            id: launch
            visible: !section.minimal
            Layout.fillWidth: true
            Layout.topMargin: 2
            implicitHeight: launchText.implicitHeight + 14
            radius: section.theme.pillRadius
            readonly property bool hot: launchArea.containsMouse
            color: hot ? section.theme.ink : "transparent"
            border.width: section.theme.dark ? 1 : 2
            border.color: section.theme.dark ? section.theme.tint(launchArea.containsMouse ? 1 : 0.6) : section.theme.ink
            Text {
                id: launchText
                anchors.centerIn: parent
                text: i18n("[LAUNCH FULL PROCESS DIAGNOSTICS]")
                color: launch.hot ? section.theme.bg : section.theme.ink
                font { family: section.theme.mono; pixelSize: 11; bold: true; letterSpacing: 0.8 }
            }
            MouseArea {
                id: launchArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: section.diagnosticsRequested()
            }
        }
    }
}
