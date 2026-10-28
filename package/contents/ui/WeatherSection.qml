import QtQuick
import "weather"
import "common"

// The weather module: the sky hero card with temperature and feels-like, the
// hourly and weekly drawers, and Arthur and Marvin walking the forecast strip
// (full), or the one compact card (minimal). The card is a
// ThemeShapeContainer in the theme's card shape, the view drawn inside it;
// the density tag sits on its top border. Only the full view
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
        height: (section.minimal ? (view.item ? view.item.implicitHeight + card.inset : 0) : section.fullHeight) + section.gap
        ThemeShapeContainer {   // the card, in the theme's shape; the views draw none of their own
            id: card
            width: parent.width
            height: parent.height - section.gap
            visible: view.status === Loader.Ready
            theme: section.theme
            role: "card"
            readonly property bool translucent: !section.minimal && section.config !== undefined
                                                && section.config.translucentDesktopBackground
            fillColor: translucent ? Qt.rgba(theme.bg.r, theme.bg.g, theme.bg.b, theme.dark ? 0.9 : 0.93) : theme.bg
            // the border on both sides, plus whatever a flat or soft shadow's offset takes
            readonly property real inset: strokeWidth * 2 + (offsetShadow ? Math.abs(shadowOffsetY) : 0)
            padding: strokeWidth
            Loader {
                id: view
                anchors.fill: parent
                active: (section.open || section.visible) && section.feed !== null && section.config !== undefined
                sourceComponent: section.minimal ? minimalView : fullView
            }
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
            backdrop: false
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
            backdrop: false
            textureInset: Math.max(4, card.radius * 0.3, card.cut)
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
