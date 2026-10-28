import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "weather"
import "common"

// Panel item: one reading or several (PanelReadings.qml), each an optional
// icon, a monospace figure and an optional micro meter, sized from the panel
// thickness. Horizontal panels lay the readings out in a row, icon | figure
// | meter, with thin dividers; vertical panels stack each one, icon over
// figure over meter, the figure shrunk to fit the panel width. Nothing
// animates in the panel but alerts: a reading at a warning turns amber; a
// critical one flashes its figure and icon to crimson once a second, and a
// critical reading the item isn't showing puts a blinking 4 px pip on its
// top-right corner (with alert motion off both hold steady). The hover card
// opens with an "ALERT: ..." line for each critical reading. The light theme inks in the panel's own
// text colour; the dark theme keeps its phosphor green. Left click opens the
// popup, middle click asks for a refresh. Resting the pointer on it for
// 350 ms opens the hover card (PanelHoverPopup) with the large card of the
// shown reading; it closes 200 ms after the pointer has left both.
MouseArea {
    id: compact

    property bool dark: false
    property var readings: []
    property bool showIcon: true
    property bool showMeter: true
    property bool vertical: false
    property var weather: null            // the WeatherFeed's parsed data, for the condition icon
    property string iconStyle: "wireframe"

    property QtObject theme               // SubEthaTheme, for the hover card
    property Component preview            // the hover card's content
    property bool expanded: false         // the popup is open: no hover card
    property QtObject alerts              // an AlertManager
    property var offPanelCritical: []     // PanelReadings.offPanelCritical
    property bool animate: true           // alert motion, while the panel item is live
    property int popupLocation: 0         // Plasmoid.location, where the card opens
    readonly property bool previewOpen: hoverCard.visible

    signal refreshRequested()

    Timer {
        id: hoverOpenTimer
        interval: 350
        onTriggered: if (compact.containsMouse && !compact.expanded && compact.preview) hoverCard.visible = true
    }
    Timer {
        id: hoverCloseTimer
        interval: 200
        onTriggered: if (!compact.containsMouse && !hoverCard.hovered) hoverCard.visible = false
    }
    onContainsMouseChanged: {
        if (containsMouse) { hoverCloseTimer.stop(); hoverOpenTimer.restart() }
        else { hoverOpenTimer.stop(); hoverCloseTimer.restart() }
    }
    onExpandedChanged: if (expanded) { hoverOpenTimer.stop(); hoverCard.visible = false }
    onPressed: { hoverOpenTimer.stop(); hoverCard.visible = false }
    PanelHoverPopup {
        id: hoverCard
        visible: false
        visualParent: compact
        location: compact.popupLocation
        theme: compact.theme
        content: compact.preview
        alertLines: compact.alerts ? compact.alerts.culprits.filter(c => c.level === 2).map(c => c.text) : []
        onHoveredChanged: if (!hovered && !compact.containsMouse) hoverCloseTimer.restart()
                          else hoverCloseTimer.stop()
    }

    readonly property color ink: dark ? "#00FF66" : Kirigami.Theme.textColor
    readonly property color busy: dark ? "#FFB000" : "#E8890C"
    readonly property color alert: dark ? "#FF3333" : "#FF6B4A"
    function levelColor(level) { return level === "alert" ? alert : level === "busy" ? busy : ink }
    readonly property color critical: theme ? theme.critColor : alert
    // figure and icon at the reading's alert level; a critical one flashes
    function alertInk(r) { return r.alert === 2 ? (flashOn ? critical : ink) : r.alert === 1 ? busy : ink }

    readonly property bool anyCritical: readings.some(r => r.alert === 2) || offPanelCritical.length > 0
    property bool flashOn: true           // 500 ms crimson, 500 ms resting
    Timer {
        interval: 500
        repeat: true
        running: compact.animate && compact.anyCritical
        onTriggered: compact.flashOn = !compact.flashOn
        onRunningChanged: if (!running) compact.flashOn = true
    }
    Rectangle {   // a critical reading off the panel: the pip, top-right
        visible: compact.offPanelCritical.length > 0
        z: 1
        anchors { top: parent.top; right: parent.right; margins: 1 }
        width: 4; height: 4
        radius: 2
        color: compact.critical
        opacity: compact.flashOn ? 1 : 0.15
    }

    readonly property real thickness: vertical ? width : height
    readonly property real glyphSize: Math.max(12, Math.min(22, Math.round(thickness * (vertical ? 0.42 : 0.55))))
    readonly property real fontPx: Math.max(9, Math.min(13, Math.round(thickness * (vertical ? 0.3 : 0.42))))
    readonly property real gap: Math.max(2, Math.round(thickness * 0.1))

    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    hoverEnabled: true
    implicitWidth: vertical ? Kirigami.Units.iconSizes.medium : layout.width + Kirigami.Units.smallSpacing * 2
    implicitHeight: vertical ? layout.height + Kirigami.Units.smallSpacing * 2 : Kirigami.Units.iconSizes.medium
    // The panel sizes its items from these, along its length.
    Layout.minimumWidth: vertical ? -1 : implicitWidth
    Layout.preferredWidth: vertical ? -1 : implicitWidth
    Layout.minimumHeight: vertical ? implicitHeight : -1
    Layout.preferredHeight: vertical ? implicitHeight : -1
    onClicked: mouse => { if (mouse.button === Qt.MiddleButton) refreshRequested() }

    readonly property string weatherIconStyle: dark
        ? (iconStyle === "black" ? "white" : iconStyle === "solid-black" ? "solid-white" : iconStyle)
        : (iconStyle === "white" ? "black" : iconStyle === "solid-white" ? "solid-black" : iconStyle)

    Grid {
        id: layout
        anchors.centerIn: parent
        columns: compact.vertical ? 1 : Math.max(1, compact.readings.length * 2 - 1)
        rowSpacing: compact.gap * 2
        columnSpacing: compact.gap * 2
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        Repeater {
            model: Math.max(0, compact.readings.length * 2 - 1)   // readings with a divider between each pair
            Loader {
                required property int index
                readonly property var reading: compact.readings[index / 2] || null
                sourceComponent: index % 2 === 1 ? divider : cell
            }
        }
    }

    Component {
        id: divider
        Rectangle {
            width: compact.vertical ? compact.width * 0.5 : 1
            height: compact.vertical ? 1 : compact.thickness * 0.5
            color: compact.ink
            opacity: 0.3
        }
    }

    Component {
        id: cell
        Grid {
            id: cellGrid
            readonly property var r: parent.reading
            readonly property color tone: compact.levelColor(r.level)
            readonly property bool meter: compact.showMeter && r.fraction >= 0
            columns: compact.vertical ? 1 : 3
            spacing: compact.gap
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            Item {
                visible: compact.showIcon
                width: compact.glyphSize; height: compact.glyphSize
                VectorGlyph {
                    visible: cellGrid.r.key !== "weather"
                    anchors.fill: parent
                    path: cellGrid.r.glyph
                    color: cellGrid.r.source ? compact.alertInk(cellGrid.r) : cellGrid.r.level === "alert" ? compact.alert : compact.ink
                    strokeWidth: 2
                }
                WeatherIcon {
                    visible: cellGrid.r.key === "weather"
                    anchors.fill: parent
                    condition: compact.weather ? compact.weather.current.condition : "cloudy"
                    code: compact.weather ? compact.weather.current.code : -1
                    isDay: compact.weather ? compact.weather.current.isDay : true
                    iconStyle: compact.weatherIconStyle
                    palette: ({ outline: compact.ink, sun: compact.busy, precip: compact.dark ? "#00E5FF" : "#26A69A",
                                bolt: compact.busy, boltCore: compact.alert, bg: "transparent", solid: !compact.dark })
                    running: false
                }
            }
            Text {
                // Without an icon a label says what the figure is.
                text: compact.vertical ? cellGrid.r.shortText
                    : (compact.showIcon || cellGrid.r.key === "weather" || cellGrid.r.key === "clock" ? "" : cellGrid.r.label + " ") + cellGrid.r.text
                color: cellGrid.r.source ? compact.alertInk(cellGrid.r) : cellGrid.r.level === "alert" ? compact.alert : compact.ink
                font { family: "monospace"; pixelSize: compact.fontPx; bold: true }
                width: compact.vertical ? Math.min(implicitWidth, compact.width - 4) : implicitWidth
                fontSizeMode: compact.vertical ? Text.HorizontalFit : Text.FixedSize
                minimumPixelSize: 7
                horizontalAlignment: Text.AlignHCenter
                // The clock reads as a retro digital pill: the figure in a thin outline.
                readonly property bool pill: cellGrid.r.key === "clock" && !compact.vertical
                leftPadding: pill ? 4 : 0
                rightPadding: pill ? 4 : 0
                Rectangle {
                    visible: parent.pill
                    anchors { fill: parent; topMargin: -1; bottomMargin: -1 }
                    radius: 3
                    color: "transparent"
                    border { width: 1; color: compact.ink }
                    opacity: 0.6
                }
            }
            DualMetricBar {   // cpu / gpu: load over temperature on one track
                visible: cellGrid.meter && cellGrid.r.temp !== undefined
                width: compact.vertical ? Math.max(12, compact.width * 0.6) : 24
                segments: 6
                segmentHeight: 4
                theme: compact.theme
                usageFraction: cellGrid.r.load || 0
                tempValue: cellGrid.r.temp || 0
                tempLevel: cellGrid.r.tempLevel || 0
                loadLevel: cellGrid.r.loadLevel || 0
                animate: compact.animate
                live: compact.animate
            }
            Rectangle {   // micro meter: track and fill
                visible: cellGrid.meter && cellGrid.r.temp === undefined
                width: compact.vertical ? Math.max(12, compact.width * 0.6) : 24
                height: 3
                radius: 1
                color: Qt.rgba(compact.ink.r, compact.ink.g, compact.ink.b, 0.2)
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, cellGrid.r.fraction))
                    height: parent.height
                    radius: 1
                    color: cellGrid.tone
                }
            }
        }
    }
}
