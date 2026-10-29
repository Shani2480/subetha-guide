import QtQuick
import QtQuick.Layouts
import "common"

// The Guide's card: one header (title, location or host, DON'T PANIC) over
// the enabled sections, stacked in a fixed order: clock, weather, system,
// storage, power, AI. A section switched off folds to nothing and the ones below
// slide up. At the wide step (740) the clock spans the card and the sections
// below it flow into two columns, weather, storage and AI on the left, system
// and power on the right. On the desktop the
// whole stack snaps to the layout steps (SnapFrame) and scrolls when taller.
// Each section is full or compact on its own (config.<key>Density, flipped by
// the tag on its card); a section that changes density animates its height
// (CollapsibleSection) and the ones below and beside slide with it. The
// header folds away only while every shown section is compact. Under a skin
// that imitates an operating system, the whole stack sits in that OS's window
// (GuideWindow) and its title bar replaces the header. A skin's footer
// (SkinFooter) runs along the bottom.
SnapFrame {
    id: full

    property bool desktop: false
    property var sections: []
    property string subtitle: ""
    property bool live: false
    property var config
    property QtObject timeEngine
    property QtObject weatherFeed
    property QtObject systemFeed
    property var systemSensors: []
    property QtObject diskFeed
    property QtObject batteryFeed
    property QtObject aiFeed
    property QtObject alerts              // an AlertManager

    signal locationChosen(string name, real latitude, real longitude)
    signal densityChosen(string key, string density)
    signal sensorSizeChosen(string key, string size)
    signal configureRequested()
    signal monitorRequested(string tab)   // a System Monitor tab

    function has(key) { return sections.indexOf(key) >= 0 }
    function compact(key) { return !!config && config[key + "Density"] === "compact" }
    function toggleDensity(key) { densityChosen(key, compact(key) ? "full" : "compact") }
    // a section's place among those shown, top to bottom (a skin's numbered flag tabs)
    function number(key) {
        return ["clock", "weather", "system", "disk", "battery", "ai"].filter(has).indexOf(key) + 1
    }
    property int entranceSerial: 0        // bumped each time the view opens: the pills cascade in again
    onLiveChanged: if (live) entranceSerial++

    snapping: desktop
    contentHeight: window.height
    Layout.preferredWidth: desktop ? theme.colWidthStandard : 400

    GuideWindow {
        id: window
        width: parent.width
        theme: full.theme
        title: full.theme.lex("appTitle", i18n("THE SUB-ETHA GUIDE"), i18n("SYSTEM GUIDE"))
        Item {
            id: stack
            readonly property real gap: 8
            readonly property bool twoColumns: width >= full.theme.colWidthWide - full.theme.margin * 2 - 1 - (window.border + window.pad) * 2
            readonly property real columnWidth: twoColumns ? (width - gap) / 2 : width
            readonly property real rightX: twoColumns ? columnWidth + gap : 0
            // Room above the first cards for the density tags on their top borders.
            readonly property real topY: header.height + (header.open ? 0 : 6)
            // The columns start below the clock, which runs the full width.
            readonly property real firstY: clockSection.y + clockSection.height
            width: parent.width
            readonly property real sectionsBottom: Math.max(diskSection.y + diskSection.height, batterySection.y + batterySection.height,
                                                            aiSection.y + aiSection.height, empty.visible ? empty.y + empty.height : 0)
            height: sectionsBottom + footer.height

            CollapsibleSection {
                id: header
                width: parent.width
                open: !full.theme.minimal && !full.theme.windowed
                Column {
                    width: parent.width
                    VectorFrame {
                        width: parent.width
                        theme: full.theme
                        padding: 14
                        chassis: true
                        GuideHeader {
                            width: parent.width
                            theme: full.theme
                            title: full.theme.lex("appTitle", i18n("THE SUB-ETHA GUIDE"), i18n("SYSTEM GUIDE"))
                            subtitle: full.theme.skinned ? full.theme.lex("appSubtitle", "", "") ? full.theme.lex("appSubtitle", "", "") + " // " + full.subtitle : full.subtitle
                                                         : i18n("MOSTLY HARMLESS // %1", full.subtitle)
                        }
                    }
                    Item { width: 1; height: stack.gap }
                }
            }

            ClockSection {
                id: clockSection
                number: full.number("clock")
                y: stack.topY
                width: parent.width
                open: full.has("clock")
                theme: full.theme
                engine: full.timeEngine
                config: full.config
                minimal: full.compact("clock")
                onDensityToggled: full.toggleDensity("clock")
                live: full.live
                entranceSerial: full.entranceSerial
            }
            WeatherSection {
                id: weatherSection
                number: full.number("weather")
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
                number: full.number("system")
                x: stack.rightX
                y: stack.twoColumns ? stack.firstY : weatherSection.y + weatherSection.height
                width: stack.columnWidth
                open: full.has("system")
                theme: full.theme
                feed: full.systemFeed
                config: full.config
                sensors: full.systemSensors
                alerts: full.alerts
                minimal: full.compact("system")
                onDensityToggled: full.toggleDensity("system")
                onSensorSizeChosen: (key, size) => full.sensorSizeChosen(key, size)
                live: full.live
                entranceSerial: full.entranceSerial
                onMonitorRequested: tab => full.monitorRequested(tab)
            }
            DiskSection {
                id: diskSection
                number: full.number("disk")
                x: 0
                y: stack.twoColumns ? weatherSection.y + weatherSection.height : systemSection.y + systemSection.height
                width: stack.columnWidth
                open: full.has("disk")
                theme: full.theme
                feed: full.diskFeed
                alerts: full.alerts
                config: full.config
                minimal: full.compact("disk")
                onDensityToggled: full.toggleDensity("disk")
                onMonitorRequested: tab => full.monitorRequested(tab)
                live: full.live
                entranceSerial: full.entranceSerial
            }
            BatterySection {
                id: batterySection
                number: full.number("battery")
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
            AiSection {
                id: aiSection
                number: full.number("ai")
                x: 0
                y: stack.twoColumns ? diskSection.y + diskSection.height : batterySection.y + batterySection.height
                width: stack.columnWidth
                open: full.has("ai")
                theme: full.theme
                feed: full.aiFeed
                config: full.config
                minimal: full.compact("ai")
                onDensityToggled: full.toggleDensity("ai")
                live: full.live
                entranceSerial: full.entranceSerial
            }

            SkinFooter {   // a skin's mark, label and motto along the bottom
                id: footer
                y: stack.sectionsBottom
                width: parent.width
                height: implicitHeight
                theme: full.theme
            }
            VectorFrame {
                id: empty
                visible: full.sections.length === 0
                y: stack.topY
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
}
