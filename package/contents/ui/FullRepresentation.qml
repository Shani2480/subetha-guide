import QtQuick
import QtQuick.Layouts
import "common"

// The Guide's card: one header (title, location or host, DON'T PANIC) over
// the enabled sections, stacked in a fixed order: weather, system, storage,
// power. A section switched off folds to nothing and the ones below slide up.
// At the wide step (740) the sections flow into two columns, weather and
// storage on the left, system and power on the right. On the desktop the
// whole stack snaps to the layout steps (SnapFrame) and scrolls when taller.
// Each section is full or compact on its own (config.<key>Density, flipped by
// the tag on its card); a section that changes density animates its height
// (CollapsibleSection) and the ones below and beside slide with it. The
// header folds away only while every shown section is compact.
SnapFrame {
    id: full

    property bool desktop: false
    property var sections: []
    property string subtitle: ""
    property bool live: false
    property var config
    property QtObject weatherFeed
    property QtObject systemFeed
    property var systemSensors: []
    property QtObject diskFeed
    property QtObject batteryFeed

    signal locationChosen(string name, real latitude, real longitude)
    signal densityChosen(string key, string density)
    signal sensorSizeChosen(string key, string size)
    signal configureRequested()
    signal diagnosticsRequested()

    function has(key) { return sections.indexOf(key) >= 0 }
    function compact(key) { return !!config && config[key + "Density"] === "compact" }
    function toggleDensity(key) { densityChosen(key, compact(key) ? "full" : "compact") }
    property int entranceSerial: 0        // bumped each time the view opens: the pills cascade in again
    onLiveChanged: if (live) entranceSerial++

    snapping: desktop
    contentHeight: stack.height
    Layout.preferredWidth: desktop ? theme.colWidthStandard : 400

    Item {
        id: stack
        readonly property real gap: 8
        readonly property bool twoColumns: width >= full.theme.colWidthWide - full.theme.margin * 2 - 1
        readonly property real columnWidth: twoColumns ? (width - gap) / 2 : width
        readonly property real rightX: twoColumns ? columnWidth + gap : 0
        // Room above the first cards for the density tags on their top borders.
        readonly property real firstY: header.height + (header.open ? 0 : 6)
        width: parent.width
        height: Math.max(diskSection.y + diskSection.height, batterySection.y + batterySection.height,
                         empty.visible ? empty.y + empty.height : 0)

        CollapsibleSection {
            id: header
            width: parent.width
            open: !full.theme.minimal
            Column {
                width: parent.width
                VectorFrame {
                    width: parent.width
                    theme: full.theme
                    padding: 14
                    GuideHeader {
                        width: parent.width
                        theme: full.theme
                        title: i18n("THE SUB-ETHA GUIDE")
                        subtitle: i18n("MOSTLY HARMLESS // %1", full.subtitle)
                    }
                }
                Item { width: 1; height: stack.gap }
            }
        }

        WeatherSection {
            id: weatherSection
            x: 0
            y: stack.firstY
            width: stack.columnWidth
            open: full.has("weather")
            theme: full.theme
            feed: full.weatherFeed
            config: full.config
            minimal: full.compact("weather")
            onDensityToggled: full.toggleDensity("weather")
            live: full.live
            gap: stack.gap
            onLocationChosen: (name, latitude, longitude) => full.locationChosen(name, latitude, longitude)
            onConfigureRequested: full.configureRequested()
        }
        SystemSection {
            id: systemSection
            x: stack.rightX
            y: stack.twoColumns ? stack.firstY : weatherSection.y + weatherSection.height
            width: stack.columnWidth
            open: full.has("system")
            theme: full.theme
            feed: full.systemFeed
            config: full.config
            sensors: full.systemSensors
            minimal: full.compact("system")
            onDensityToggled: full.toggleDensity("system")
            onSensorSizeChosen: (key, size) => full.sensorSizeChosen(key, size)
            live: full.live
            entranceSerial: full.entranceSerial
            onDiagnosticsRequested: full.diagnosticsRequested()
        }
        DiskSection {
            id: diskSection
            x: 0
            y: stack.twoColumns ? weatherSection.y + weatherSection.height : systemSection.y + systemSection.height
            width: stack.columnWidth
            open: full.has("disk")
            theme: full.theme
            feed: full.diskFeed
            config: full.config
            minimal: full.compact("disk")
            onDensityToggled: full.toggleDensity("disk")
            live: full.live
            entranceSerial: full.entranceSerial
        }
        BatterySection {
            id: batterySection
            x: stack.rightX
            y: stack.twoColumns ? systemSection.y + systemSection.height : diskSection.y + diskSection.height
            width: stack.columnWidth
            open: full.has("battery")
            theme: full.theme
            feed: full.batteryFeed
            config: full.config
            minimal: full.compact("battery")
            onDensityToggled: full.toggleDensity("battery")
            live: full.live
            entranceSerial: full.entranceSerial
        }

        VectorFrame {
            id: empty
            visible: full.sections.length === 0
            y: stack.firstY
            width: parent.width
            theme: full.theme
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: i18n("ALL SECTIONS STOWED. ENABLE ONE UNDER APPEARANCE & SECTIONS.")
                color: full.theme.tint(0.6)
                font { family: full.theme.mono; pixelSize: 11 }
                wrapMode: Text.WordWrap
            }
        }
    }
}
