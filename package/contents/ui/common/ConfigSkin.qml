import QtQuick
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

// The active skin as the settings pages see it: the pages are KDE forms and
// keep the system look, but the pieces they draw themselves (previews, the
// store's terminal, sample readouts) follow the skin's fonts and colours,
// and under a skin none of their wording borrows the Guide's lore.
QtObject {
    id: look

    property string activeSkin: Plasmoid.configuration.activeSkin || ""
    readonly property bool skinned: theme.skinned
    readonly property string mono: skinned ? theme.mono : "monospace"
    readonly property string sans: skinned ? theme.sans : Kirigami.Theme.defaultFont.family

    // The Guide's line, or the plain one under a skin.
    function say(h2g2, neutral) { return skinned ? neutral : h2g2 }

    property SkinEngine engine: SkinEngine { activeSkin: look.activeSkin }
    property SubEthaTheme theme: SubEthaTheme {
        mode: Plasmoid.configuration.themeMode || "auto"
        latitude: Plasmoid.configuration.latitude || 0
        longitude: Plasmoid.configuration.longitude || 0
        systemDark: { var c = Kirigami.Theme.backgroundColor; return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b < 0.5 }
        skin: look.activeSkin ? look.engine.style : null
    }
}
