import QtQuick
import QtQuick.Layouts
import "battery"
import "common"

// The power module: one pill per selected battery with live wattage and
// charge state, and the mains / power profile footer (BatteryPanel).
CollapsibleSection {
    id: section

    property QtObject theme
    property QtObject feed                // a BatteryFeed
    property var config
    property bool minimal: false          // this section's density is "compact"
    property bool live: false
    property int entranceSerial: 0

    signal densityToggled()

    ModuleCard {
        width: parent.width
        theme: section.theme
        minimal: section.minimal
        onDensityToggled: section.densityToggled()
        title: section.theme.lex("powerTitle", i18n("POWER // ENERGY CELLS"), i18n("POWER"))
        glyph: "M3 7 H19 V17 H3 Z M19 10 H21.5 V14 H19 M6 10 V14 M9 10 V14 M12 10 V14"
        // Created once the feed and settings are attached, so no binding
        // runs against a null feed while the card is being built.
        Loader {
            Layout.fillWidth: true
            active: section.feed !== null && section.config !== undefined
            sourceComponent: Component {
                BatteryPanel {
                    theme: section.theme
                    feed: section.feed
                    minimal: section.minimal
                    percentageOnly: section.config.showPercentageOnly
                    lowBlink: section.config.batteryBlink
                    showPowerRate: section.config.showPowerRate
                    live: section.live && section.open
                    entranceSerial: section.entranceSerial
                }
            }
        }
    }
}
