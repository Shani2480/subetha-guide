import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../common"

// The body of the chronometry page, without frame or header: one pill.
// Compact (36px): chronometer glyph, the short date and the digital readout
// with the zone abbreviation. Large (104px): on the left the 32px readout
// (a phosphor bloom on the CRT, a flat offset shadow on the movie pages),
// the long date, the zone name and UTC offset and, optionally, the galactic
// epoch badge (sidereal time, day and week in its tooltip); on the right the
// second / day dial over the Guide's comment on the hour. Only the shown
// density's row has height, so the pill sizes to it. Everything comes from a
// TimeEngine.
SlidingPillContainer {
    id: panel

    property QtObject engine              // a TimeEngine
    property bool minimal: false
    property bool showSeconds: true
    property bool showDate: true
    property bool showTzOffset: true
    property bool showGalactic: false

    readonly property var e: engine
    readonly property string readout: e ? e.hours + ":" + e.minutes + (showSeconds ? ":" + e.seconds : "") : "--:--"
    // The line under the dial: under stress (a critical reading or a busy
    // CPU, theme.mood) the skin's stress quip or the Guide's towel warning,
    // else the skin's nominal quip or the Guide's line for the time of day.
    readonly property bool stressed: theme.mood === "stressed"
    readonly property string quip: theme.clockQuips[stressed ? "stress" : "nominal"]
                                 || (stressed ? i18n("DON'T PANIC, BUT YOUR PROCESSOR IS CURRENTLY WONDERING WHERE ITS TOWEL IS.")
                                              : e ? e.commentary : "")
    readonly property string glyph: "M3 12 A9 9 0 1 0 21 12 A9 9 0 1 0 3 12 Z M12 7 V12 L15.5 14 M12 1 V3 M12 21 V23 M1 12 H3 M21 12 H23"

    verticalPadding: minimal ? 7 : 10
    horizontalPadding: minimal ? 12 : 14

    // ---- compact: glyph | date | readout ----
    RowLayout {
        visible: panel.minimal
        width: parent.width
        height: visible ? 20 : 0
        spacing: 8
        VectorGlyph {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            path: panel.glyph
            color: panel.theme.ink
            strokeWidth: 1.8
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: panel.showDate && panel.e ? panel.e.shortDate : ""
            color: panel.theme.tint(0.75)
            font { family: panel.theme.mono; pixelSize: 10; bold: true; letterSpacing: 0.5 }
            elide: Text.ElideRight
        }
        Text {
            text: panel.readout + (panel.e && panel.e.meridiem ? " " + panel.e.meridiem : "")
                  + (panel.showTzOffset && panel.e ? " " + panel.e.tzAbbreviation : "")
            color: panel.theme.ink
            font { family: panel.theme.mono; pixelSize: 15; bold: true }
        }
    }

    // ---- large: digital HUD | dial and comment ----
    RowLayout {
        visible: !panel.minimal
        width: parent.width
        height: visible ? 82 : 0
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2
            Item {
                Layout.fillWidth: true
                implicitHeight: digits.implicitHeight
                Text {   // flat 2D offset shadow on the movie pages
                    visible: panel.theme.flatShadow
                    x: 2; y: 2
                    text: digits.text
                    color: panel.theme.accent
                    font: digits.font
                }
                Text {
                    id: digits
                    text: panel.readout
                    color: panel.theme.ink
                    font { family: panel.theme.mono; pixelSize: 32; bold: true }
                    layer.enabled: panel.theme.dark
                    layer.effect: MultiEffect {   // phosphor bloom on the CRT
                        shadowEnabled: true
                        shadowColor: panel.theme.ink
                        shadowOpacity: 0.55
                        shadowBlur: 0.6
                        blurMax: 10
                        shadowVerticalOffset: 0
                        shadowHorizontalOffset: 0
                    }
                }
                Text {
                    visible: text !== ""
                    anchors { left: digits.right; leftMargin: 4; baseline: digits.baseline }
                    text: panel.e ? panel.e.meridiem : ""
                    color: panel.theme.ink
                    font { family: panel.theme.mono; pixelSize: 11; bold: true }
                }
            }
            Text {
                visible: panel.showDate
                Layout.fillWidth: true
                text: panel.e ? panel.e.longDate : ""
                color: panel.theme.ink
                font { family: panel.theme.mono; pixelSize: 9; bold: true; letterSpacing: 0.5 }
                elide: Text.ElideRight
            }
            RowLayout {   // a long zone name elides; the offset always shows
                visible: panel.showTzOffset
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    Layout.maximumWidth: implicitWidth
                    text: panel.e ? panel.e.tzName : ""
                    color: panel.theme.tint(0.65)
                    font { family: panel.theme.mono; pixelSize: 9 }
                    elide: Text.ElideRight
                }
                Text {
                    text: panel.e ? " · " + panel.e.utcOffset : ""
                    color: panel.theme.tint(0.65)
                    font { family: panel.theme.mono; pixelSize: 9; bold: true }
                }
                Item { Layout.fillWidth: true }
            }
            Item { Layout.fillHeight: true }
            Rectangle {   // galactic epoch badge
                visible: panel.showGalactic
                implicitWidth: epoch.implicitWidth + 12
                implicitHeight: epoch.implicitHeight + 4
                Layout.maximumWidth: parent.width
                radius: height / 2
                color: "transparent"
                border { width: 1.5; color: panel.theme.badge }
                Text {
                    id: epoch
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - 12)
                    text: panel.e ? i18n("GALACTIC EPOCH // %1", panel.e.galacticStandardTime) : ""
                    color: panel.theme.dark ? panel.theme.badge : panel.theme.ink
                    font { family: panel.theme.mono; pixelSize: 8; bold: true; letterSpacing: 0.5 }
                    elide: Text.ElideRight
                }
                HoverHandler { id: epochHover }
                SubEthaTooltip {
                    theme: panel.theme
                    shown: epochHover.hovered
                    text: panel.e ? i18n("GREENWICH SIDEREAL TIME %1\nDAY %2 · WEEK %3 · %4",
                                         panel.e.siderealTime, panel.e.dayOfYear, panel.e.weekNumber, panel.e.isoDate) : ""
                }
            }
        }

        ColumnLayout {
            Layout.preferredWidth: Math.round(panel.width * 0.4)
            Layout.maximumWidth: Math.round(panel.width * 0.4)
            Layout.fillHeight: true
            spacing: 4
            ChronoDial {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                theme: panel.theme
                secondFraction: panel.e ? panel.e.secondFraction : 0
                dayFraction: panel.e ? panel.e.dayFraction : 0
                centerText: panel.e ? i18nc("ISO week number", "W%1", panel.e.weekNumber) : ""
            }
            Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: panel.quip
                color: panel.theme.commentary
                font { family: panel.theme.mono; pixelSize: 8; bold: true }
                lineHeight: 0.9
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: 3
            }
        }
    }
}
