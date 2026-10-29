import QtQuick
import QtQuick.Layouts
import "ai"
import "ai/code/ai.js" as Ai
import "common"

// The AI module: what this month's API usage has cost against a budget, or
// which local models are loaded and how much VRAM they take (AiPanel).
CollapsibleSection {
    id: section

    property QtObject theme
    property QtObject feed                // an AiFeed
    property var config
    property bool minimal: false          // this section's density is "compact"
    property bool live: false
    property int entranceSerial: 0

    signal densityToggled()

    ModuleCard {
        iconKey: "ai"
        width: parent.width
        theme: section.theme
        minimal: section.minimal
        onDensityToggled: section.densityToggled()
        title: section.theme.lex("aiTitle", i18n("SYNAPSE TELEMETRY // %1", Ai.providerTag(section.feed ? section.feed.provider : "")),
                                i18n("AI // %1", Ai.providerTag(section.feed ? section.feed.provider : "")))
        glyph: "M9 4.5 A3 3 0 0 0 4.5 7 A3 3 0 0 0 3.5 12 A3 3 0 0 0 5.5 16.5 A3 3 0 0 0 10 19.5 V4.5 Z M14 4.5 A3 3 0 0 1 19.5 7 A3 3 0 0 1 20.5 12 A3 3 0 0 1 18.5 16.5 A3 3 0 0 1 14 19.5 Z M12 2 V22"
        Loader {
            Layout.fillWidth: true
            active: section.feed !== null && section.config !== undefined
            sourceComponent: Component {
                AiPanel {
                    theme: section.theme
                    feed: section.feed
                    minimal: section.minimal
                    endpoint: section.config.localAiEndpoint
                    live: section.live && section.open
                    entranceSerial: section.entranceSerial
                }
            }
        }
    }
}
