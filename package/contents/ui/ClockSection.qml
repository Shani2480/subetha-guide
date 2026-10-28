import QtQuick
import QtQuick.Layouts
import "clock"
import "common"

// The chronometry module: local time, date and zone in one pill, slim in
// compact density, the full chronometer with its dial when large
// (ClockPanel). The clock itself is the shared TimeEngine.
CollapsibleSection {
    id: section

    property QtObject theme
    property QtObject engine              // a TimeEngine
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
        title: section.theme.lex("clockTitle", i18n("CHRONOMETRY // SECTOR ZZ9"), i18n("CLOCK"))
        glyph: "M3 12 A9 9 0 1 0 21 12 A9 9 0 1 0 3 12 Z M12 7 V12 L15.5 14 M12 1 V3 M12 21 V23 M1 12 H3 M21 12 H23"
        Loader {
            Layout.fillWidth: true
            active: section.engine !== null && section.config !== undefined
            sourceComponent: Component {
                ClockPanel {
                    theme: section.theme
                    engine: section.engine
                    minimal: section.minimal
                    showSeconds: section.config.showSeconds
                    showDate: section.config.showDate
                    showTzOffset: section.config.showTzOffset
                    showGalactic: section.config.showGalacticSiderealTime
                    live: section.live && section.open
                    entranceSerial: section.entranceSerial
                }
            }
        }
    }
}
