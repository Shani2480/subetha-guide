import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// The "minimal" display mode: one low-profile card with the location, the
// animated condition icon, temperature, feels-like and today's high / low.
// No characters, commentary, grid, raster or forecast drawer.
Rectangle {
    id: view

    property var weather: null
    property string errorText: ""
    property string tempText: "--°"
    property int currentFeelsLike: 0
    property string locationName: ""
    property string iconStyle: "wireframe"
    property string themeStyle: "movieLight"
    property QtObject skin: null            // as FullView.skin
    property bool desktopMode: false
    property bool translucent: true
    property bool live: false               // on screen; the icon animates only then
    property bool backdrop: true            // as FullView.backdrop

    // Same palette as FullView's three Guide themes.
    readonly property bool light: skin ? !(skin.fx.crtScanlines || skin.fx.phosphorDecay) : themeStyle === "movieLight"
    readonly property bool neon: themeStyle === "improbability"
    readonly property color bg:      skin ? skin.bg : light ? "#F5F2EB" : neon ? "#0A0612" : "#040806"
    readonly property color ink:     skin ? skin.ink : light ? "#1B2028" : neon ? "#FF2BD6" : "#00FF66"
    readonly property color accent:  skin ? skin.accent : light ? "#FF6B4A" : neon ? "#00E5FF" : "#FFB000"
    readonly property color cool:    skin ? skin.cool : light ? "#26A69A" : "#00E5FF"
    readonly property string fontFamily: skin ? skin.sans : light ? Qt.application.font.family : "monospace"
    function tint(a) { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    readonly property string cardIconStyle: light
        ? (iconStyle === "white" ? "black" : iconStyle === "solid-white" ? "solid-black" : iconStyle)
        : (iconStyle === "black" ? "white" : iconStyle === "solid-black" ? "solid-white" : iconStyle)
    readonly property var iconPalette: skin
        ? ({ outline: ink, sun: skin.mustard, precip: cool, bolt: skin.mustard, boltCore: skin.alert, bg: bg, solid: light })
        : ({ outline: ink, sun: light ? accent : (neon ? "#FFE65C" : "#FFB000"), precip: cool,
             bolt: light ? "#FFBE1A" : "#FFB000", boltCore: light ? "#E53935" : "#FF3333",
             bg: bg, solid: light })

    readonly property var today: weather && weather.daily && weather.daily.length ? weather.daily[0] : null

    implicitWidth: Kirigami.Units.gridUnit * 16
    implicitHeight: content.implicitHeight + 28
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.minimumWidth: Kirigami.Units.gridUnit * 12
    Layout.minimumHeight: implicitHeight

    radius: skin ? skin.outerRadius : 16   // SubEthaTheme.outerRadius
    color: !backdrop ? "transparent" : !desktopMode ? Qt.rgba(bg.r, bg.g, bg.b, light ? 0.97 : 0.94)
         : translucent ? Qt.rgba(bg.r, bg.g, bg.b, light ? 0.93 : 0.9) : bg
    border.width: backdrop ? (skin ? skin.borderWidth : light ? 2 : 1.5) : 0
    border.color: skin ? skin.border : light ? ink : tint(0.5)

    RowLayout {
        id: content
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 16 }
        spacing: 14

        WeatherIcon {
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56
            Layout.alignment: Qt.AlignVCenter
            condition: view.weather ? view.weather.current.condition : "cloudy"
            code: view.weather ? view.weather.current.code : -1
            isDay: view.weather ? view.weather.current.isDay : true
            iconStyle: view.cardIconStyle
            palette: view.iconPalette
            running: view.live
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: view.errorText !== "" ? view.errorText : view.locationName.toUpperCase()
                color: view.errorText !== "" ? view.accent : view.tint(0.75)
                font { family: view.fontFamily; pixelSize: 11; bold: true; letterSpacing: 0.8 }
                elide: Text.ElideRight
            }
            RowLayout {
                spacing: 10
                Text {
                    text: view.tempText
                    color: view.ink
                    font { family: view.fontFamily; pixelSize: 34; bold: true }
                }
                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1
                    Text {
                        text: view.weather ? i18n("FEELS LIKE %1°", view.currentFeelsLike) : ""
                        color: view.cool
                        font { family: view.fontFamily; pixelSize: 10; bold: true }
                    }
                    Text {
                        visible: view.today !== null
                        text: view.today ? i18nc("high and low temperature", "H %1° · L %2°", Math.round(view.today.max), Math.round(view.today.min)) : ""
                        color: view.tint(0.8)
                        font { family: view.fontFamily; pixelSize: 11; bold: true }
                    }
                }
            }
        }
    }
}
