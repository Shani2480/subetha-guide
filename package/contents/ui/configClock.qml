import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// "Clock & Chronometry": the clock section's density, picked from two
// miniature cards like the other sections' (PreviewCard.qml), and how the
// time reads, in the section and in the panel.
KCM.SimpleKCM {
    id: page

    property string cfg_clockDensity
    property string cfg_clockDensityDefault

    property alias cfg_timeFormat24h: format24Check.checked
    property alias cfg_showSeconds: secondsCheck.checked
    property alias cfg_showDate: dateCheck.checked
    property alias cfg_showTzOffset: tzCheck.checked
    property alias cfg_showGalacticSiderealTime: galacticCheck.checked

    readonly property color ink: Kirigami.Theme.textColor
    readonly property color accent: Kirigami.Theme.highlightColor
    // The schematics show the time as it is set below.
    readonly property string sampleTime: (format24Check.checked ? "13:59" : "01:59") + (secondsCheck.checked ? ":42" : "")
                                         + (format24Check.checked ? "" : " PM")

    Kirigami.FormLayout {
        RowLayout {
            Kirigami.FormData.label: i18n("Section density:")
            spacing: Kirigami.Units.largeSpacing

            PreviewCard {
                title: i18n("Compact")
                cardDescription: i18n("Compact: one slim pill with the date and the digital readout.")
                selected: page.cfg_clockDensity === "compact"
                onClicked: page.cfg_clockDensity = "compact"
                Rectangle {   // a single slim pill: glyph, date bar, time
                    anchors.centerIn: parent
                    width: 124; height: 26; radius: 8
                    color: "transparent"
                    border { width: 1.5; color: page.ink }
                    Rectangle { x: 7; y: 7; width: 12; height: 12; radius: 6; color: "transparent"; border { width: 1.5; color: page.ink } }
                    Rectangle { x: 25; y: 11; width: 30; height: 3; radius: 1.5; color: page.ink; opacity: 0.5 }
                    QQC2.Label {
                        anchors { right: parent.right; rightMargin: 7; verticalCenter: parent.verticalCenter }
                        text: page.sampleTime
                        font { family: "monospace"; pixelSize: 9; bold: true }
                    }
                }
            }
            PreviewCard {
                title: i18n("Large")
                cardDescription: i18n("Large: the 32px chronometer with the full date, time zone and UTC offset, a second / day dial and the Guide's comment on the hour.")
                selected: page.cfg_clockDensity === "full"
                onClicked: page.cfg_clockDensity = "full"
                Item {   // section label over the large pill: digits and lines left, rings right
                    anchors { fill: parent; margins: 8 }
                    Rectangle { x: 2; y: 2; width: 10; height: 8; radius: 2; color: "transparent"; border { width: 1.2; color: page.accent } }
                    Rectangle { x: 16; y: 4; width: 50; height: 4; radius: 2; color: page.ink; opacity: 0.8 }
                    Rectangle {
                        y: 16; width: parent.width; height: parent.height - 16; radius: 6
                        color: "transparent"; border { width: 1.2; color: page.ink }
                        QQC2.Label {
                            x: 6; y: 6
                            text: page.sampleTime.replace(" PM", "")
                            font { family: "monospace"; pixelSize: 13; bold: true }
                        }
                        Rectangle { x: 6; y: 28; width: 54; height: 3; radius: 1.5; color: page.ink; opacity: 0.7 }
                        Rectangle { x: 6; y: 35; width: 42; height: 3; radius: 1.5; color: page.ink; opacity: 0.45 }
                        Rectangle { x: 6; y: 43; width: 38; height: 7; radius: 3.5; color: "transparent"; border { width: 1; color: page.accent } }
                        Rectangle {   // the dial: outer and inner rings
                            x: parent.width - 34; y: 8; width: 26; height: 26; radius: 13
                            color: "transparent"; border { width: 2; color: page.ink }
                            Rectangle { anchors.centerIn: parent; width: 14; height: 14; radius: 7; color: "transparent"; border { width: 2; color: page.accent } }
                        }
                        Rectangle { x: parent.width - 38; y: 40; width: 34; height: 2; radius: 1; color: page.accent; opacity: 0.8 }
                        Rectangle { x: parent.width - 36; y: 45; width: 30; height: 2; radius: 1; color: page.accent; opacity: 0.8 }
                    }
                }
            }
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            text: i18n("Switch the clock on or off under Appearance & Sections, or flip its density with the [ - ] / [ + ] tag on its card.")
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Time")
        }
        QQC2.CheckBox {
            id: format24Check
            Kirigami.FormData.label: i18n("Format:")
            text: i18n("24-hour clock")
        }
        QQC2.CheckBox {
            id: secondsCheck
            Kirigami.FormData.label: i18n("Seconds:")
            text: i18n("Show seconds (in the section and the panel)")
        }
        QQC2.CheckBox {
            id: dateCheck
            Kirigami.FormData.label: i18n("Date:")
            text: i18n("Show the weekday and date")
        }
        QQC2.CheckBox {
            id: tzCheck
            Kirigami.FormData.label: i18n("Time zone:")
            text: i18n("Show the zone and its UTC offset")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Galactic Chronometry")
        }
        QQC2.CheckBox {
            id: galacticCheck
            Kirigami.FormData.label: i18n("Epoch badge:")
            text: i18n("Show the Guide's stardate and Greenwich sidereal time (Large density)")
        }
    }
}
