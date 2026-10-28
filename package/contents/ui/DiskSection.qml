import QtQuick
import QtQuick.Layouts
import "disk"
import "common"

// The storage module: filtered volume pills with live I/O throughput and
// segmented capacity gauges (DiskPanel). The card's title and a
// double-clicked pill open the System Monitor's Disks tab.
CollapsibleSection {
    id: section

    property QtObject theme
    property QtObject feed                // a DiskFeed
    property QtObject alerts              // an AlertManager
    property var config
    property bool minimal: false          // this section's density is "compact"
    property bool live: false
    property int entranceSerial: 0

    signal densityToggled()
    signal monitorRequested(string tab)

    ModuleCard {
        width: parent.width
        theme: section.theme
        minimal: section.minimal
        onDensityToggled: section.densityToggled()
        monitorTab: "disks"
        alertLevel: section.alerts ? section.alerts.disks : 0
        live: section.live && section.open
        onMonitorRequested: tab => section.monitorRequested(tab)
        title: i18n("STORAGE // SECTOR ZZ9")
        glyph: "M4 3 H20 V21 H4 Z M7.5 11 A4.5 4.5 0 1 0 16.5 11 A4.5 4.5 0 1 0 7.5 11 Z M11 11 A1 1 0 1 0 13 11 A1 1 0 1 0 11 11 Z M17.5 18.5 L13 12.5"
        // Created once the feed and settings are attached, so no binding
        // runs against a null feed while the card is being built.
        Loader {
            Layout.fillWidth: true
            active: section.feed !== null && section.config !== undefined
            sourceComponent: Component {
                DiskPanel {
                    theme: section.theme
                    feed: section.feed
                    minimal: section.minimal
                    storageUnit: section.config.storageUnit
                    valueFormat: section.config.valueFormat
                    showIoThroughput: section.config.showIoThroughput
                    monitorLinks: true
                    onMonitorRequested: tab => section.monitorRequested(tab)
                    live: section.live && section.open
                    entranceSerial: section.entranceSerial
                }
            }
        }
    }
}
