import QtQuick
import "weather"
import "common"

// The weather module: the sky hero card with temperature and feels-like, the
// hourly and weekly drawers, and Arthur and Marvin walking the forecast strip
// (full), or the one compact card (minimal). The card is the weather view's
// own frame; the density tag sits on its top border. Only the full view
// carries the characters, so in compact nobody walks and no ground line is
// laid out. Nothing is instantiated, so no animation timer runs, while the
// section is switched off and folded away.
CollapsibleSection {
    id: section

    property QtObject theme
    property QtObject feed                // a WeatherFeed
    property var config
    property bool minimal: false          // this section's density is "compact"
    property bool live: false
    property real gap: 8
    property bool toggleVisible: true     // the density tag (off in the panel's hover card)

    signal locationChosen(string name, real latitude, real longitude)
    signal configureRequested()
    signal densityToggled()

    readonly property string themeStyle: theme.dark ? "terminalDark" : "movieLight"
    // Tall enough for the full tier (hero, hourly strip with the characters'
    // ground line, 7-day row); the view lays itself out inside it.
    readonly property real fullHeight: theme.rowHeightFull

    Item {
        width: parent.width
        height: (section.minimal ? (view.item ? view.item.implicitHeight : 0) : section.fullHeight) + section.gap
        Loader {
            id: view
            width: parent.width
            height: parent.height - section.gap
            active: (section.open || section.visible) && section.feed !== null && section.config !== undefined
            sourceComponent: section.minimal ? minimalView : fullView
        }
        DensityToggle {
            visible: section.toggleVisible
            theme: section.theme
            compact: section.minimal
            onToggled: section.densityToggled()
        }
    }

    Component {
        id: minimalView
        MinimalView {
            weather: section.feed.weather
            errorText: section.feed.errorText
            tempText: section.feed.tempText
            currentFeelsLike: section.feed.currentFeelsLike
            locationName: section.config.locationName.trim()
            iconStyle: section.config.iconStyle
            themeStyle: section.themeStyle
            skin: section.theme.skinned ? section.theme : null
            desktopMode: true
            translucent: false
            live: section.live && section.open
        }
    }
    Component {
        id: fullView
        FullView {
            weather: section.feed.weather
            errorText: section.feed.errorText
            currentFeelsLike: section.feed.currentFeelsLike
            locationName: section.config.locationName.trim()
            iconStyle: section.config.iconStyle
            themeStyle: section.themeStyle
            skin: section.theme.skinned ? section.theme : null
            desktopMode: true
            translucent: section.config.translucentDesktopBackground
            ambientAnimations: section.config.enableBackgroundAnimations
            showCharacter: section.config.showWeatherCharacter
            showBadge: false
            active: section.live && section.open
            onRefreshRequested: section.feed.refresh()
            onConfigureRequested: section.configureRequested()
            onLocationChosen: (name, latitude, longitude) => section.locationChosen(name, latitude, longitude)
        }
    }
}
