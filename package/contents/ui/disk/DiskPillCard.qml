import QtQuick
import QtQuick.Layouts
import "code/disk.js" as Disk
import "../common"

// One volume as a Guide drawer pill. Full: storage glyph, name and mount,
// filesystem badge, the big used percentage with the configured figure
// (free / used / both), a line of live read/write throughput, and a
// segmented capacity gauge along the bottom. Minimal: label, mount, figure
// and a slim meter. At the warning threshold the border pulses and CRITICAL
// QUOTA EXCEEDED flashes.
SlidingPillContainer {
    id: card
    tint: theme.sectionTint("disk")

    property bool minimal: false
    property string volumeLabel: ""
    property string volumeMount: ""
    property int volumeExtraMounts: 0
    property string volumeFs: ""
    property string volumeKind: "ssd"     // nvme ssd hdd usb network
    property double total: 0
    property double used: 0
    property double available: 0
    property int percent: 0
    property double readBps: 0
    property double writeBps: 0
    property bool showIo: false           // the volume has a block device to count I/O on
    property bool showThroughput: true    // showIoThroughput
    property bool isCritical: false
    property string storageUnit: "auto"
    property string valueFormat: "free"
    readonly property string valueText: Disk.valueText({ usedPercentage: percent, usedBytes: used,
                                                          totalBytes: total, availableBytes: available },
                                                        storageUnit, valueFormat)

    critical: isCritical
    verticalPadding: minimal ? 7 : 10
    horizontalPadding: minimal ? 12 : 14

    // Gauge fill: green / mustard while there is room, amber / coral when
    // filling up, alert red past the critical line.
    readonly property color fillColor: isCritical ? theme.alert
                                     : percent >= 75 ? (theme.dark ? theme.amber : theme.coral)
                                     : (theme.dark ? theme.phosphor : theme.mustard)

    readonly property color readColor: theme.dark ? theme.cyan : theme.teal
    readonly property color writeColor: theme.dark ? theme.amber : theme.coral
    readonly property bool heavyIo: readBps + writeBps > 50e6

    // CRITICAL QUOTA EXCEEDED blinks on and off while on screen.
    property real flash: 1
    SequentialAnimation on flash {
        running: card.isCritical && card.live && card.theme.alertMotion
        loops: Animation.Infinite
        onRunningChanged: if (!running) card.flash = 1
        PauseAnimation { duration: 700 }
        NumberAnimation { to: 0.15; duration: 120 }
        PauseAnimation { duration: 280 }
        NumberAnimation { to: 1; duration: 120 }
    }

    readonly property var glyphs: ({
        nvme: "M2 8 H20 V16 H2 Z M20 10.5 H22 V13.5 H20 M5 10.5 H9 V13.5 H5 Z M11 10.5 H15 V13.5 H11 Z M4 16 V17.5 M7 16 V17.5 M10 16 V17.5 M13 16 V17.5 M16 16 V17.5",
        ssd: "M4 3 H20 V21 H4 Z M7 6 H17 V12 H7 Z M7 16 H12 M15.5 16 H17",
        hdd: "M4 3 H20 V21 H4 Z M7.5 11 A4.5 4.5 0 1 0 16.5 11 A4.5 4.5 0 1 0 7.5 11 Z M11 11 A1 1 0 1 0 13 11 A1 1 0 1 0 11 11 Z M17.5 18.5 L13 12.5",
        usb: "M2 8.5 H14 V15.5 H2 Z M14 9.5 H21.5 V14.5 H14 M16.8 11 V12 M18.8 11 V12 M5 12 H9",
        network: "M3 12 A9 9 0 1 0 21 12 A9 9 0 1 0 3 12 Z M3 12 H21 M12 3 C8 7 8 17 12 21 M12 3 C16 7 16 17 12 21"
    })

    ColumnLayout {
        width: parent.width
        spacing: card.minimal ? 5 : 8

        // ---- minimal: label, used / total ----
        RowLayout {
            visible: card.minimal
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: card.volumeLabel
                color: card.isCritical ? card.alertInk : card.theme.ink
                font { family: card.theme.sans; pixelSize: 12; bold: true; letterSpacing: 0.4 }
            }
            Text {
                Layout.fillWidth: true
                text: card.volumeMount
                color: card.theme.tint(0.5)
                font { family: card.theme.mono; pixelSize: 10 }
                elide: Text.ElideMiddle
            }
            Text {
                text: card.valueText
                color: card.theme.tint(0.8)
                font { family: card.theme.mono; pixelSize: 11; bold: true }
            }
        }

        // ---- full: glyph, name, badges, percentage ----
        RowLayout {
            visible: !card.minimal
            Layout.fillWidth: true
            spacing: 12

            VectorGlyph {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                path: card.glyphs[card.volumeKind] || card.glyphs.ssd
                source: card.theme.icon("disk")
                color: card.theme.ink
                strokeWidth: card.theme.stroke(1.5, 1.8)
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0   // shrinks (the label elides) so the figures on the right stay inside
                spacing: 3
                Text {
                    Layout.fillWidth: true
                    text: card.volumeLabel + "  [" + card.volumeMount + "]"
                    color: card.theme.ink
                    font { family: card.theme.sans; pixelSize: 13; bold: true; letterSpacing: 0.4 }
                    elide: Text.ElideRight
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 6
                    Rectangle {   // filesystem badge
                        implicitWidth: fsText.implicitWidth + 10
                        implicitHeight: fsText.implicitHeight + 4
                        radius: card.theme.skinned ? Math.min(height / 2, card.theme.pillRadius) : card.theme.dark ? 0 : height / 2
                        color: "transparent"
                        border.width: card.theme.skinned ? Math.min(1.5, card.theme.borderWidth) : card.theme.dark ? 1 : 1.5
                        border.color: card.theme.cool
                        Text {
                            id: fsText
                            anchors.centerIn: parent
                            text: card.volumeFs.toUpperCase()
                            color: card.theme.cool
                            font { family: card.theme.mono; pixelSize: 9; bold: true }
                        }
                    }
                    Rectangle {   // shrinks with the column, its text eliding, rather than running into the figures
                        visible: card.isCritical
                        opacity: card.flash
                        Layout.fillWidth: true
                        Layout.maximumWidth: implicitWidth
                        Layout.minimumWidth: 0
                        implicitWidth: warnText.implicitWidth + 10
                        implicitHeight: warnText.implicitHeight + 4
                        radius: card.theme.skinned ? Math.min(height / 2, card.theme.pillRadius) : card.theme.dark ? 0 : height / 2
                        color: card.alertInk
                        Text {
                            id: warnText
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, parent.width - 10)
                            elide: Text.ElideRight
                            text: i18n("CRITICAL QUOTA EXCEEDED")
                            color: card.theme.dark ? card.theme.bg : "#FFFFFF"
                            font { family: card.theme.mono; pixelSize: 9; bold: true }
                        }
                    }
                    Text {
                        visible: !card.isCritical && card.volumeExtraMounts > 0
                        Layout.fillWidth: true
                        text: i18np("+%1 MOUNT", "+%1 MOUNTS", card.volumeExtraMounts)
                        color: card.theme.tint(0.5)
                        font { family: card.theme.mono; pixelSize: 9 }
                        elide: Text.ElideRight
                    }
                    Item { Layout.fillWidth: true; visible: card.isCritical || card.volumeExtraMounts === 0 }
                }
            }
            Image {   // the skin's hero illustration, in the row's free space
                visible: source != ""
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 56; Layout.preferredHeight: 36
                source: card.theme.art("disk")
                sourceSize: Qt.size(112, 72)
                fillMode: Image.PreserveAspectFit
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 1
                Text {
                    Layout.alignment: Qt.AlignRight
                    text: card.percent + "%"
                    color: card.isCritical ? card.alertInk : card.theme.ink
                    font { family: card.theme.mono; pixelSize: 24; bold: true }
                }
                Text {
                    Layout.alignment: Qt.AlignRight
                    text: card.valueText
                    color: card.theme.tint(0.7)
                    font { family: card.theme.mono; pixelSize: 10; bold: true }
                }
            }
        }

        // Live throughput: an activity LED that pulses past 50 MB/s,
        // then read (down arrow) and write (up arrow) rates.
        RowLayout {
            visible: !card.minimal && card.showIo && card.showThroughput
            Layout.fillWidth: true
            spacing: 4
            Rectangle {
                id: activity
                implicitWidth: 7; implicitHeight: 7
                Layout.rightMargin: 2
                radius: card.theme.skinned ? Math.min(3.5, card.theme.pillRadius) : card.theme.dark ? 0 : 3.5
                readonly property bool busy: card.readBps + card.writeBps >= 1000
                color: busy ? (card.writeBps > card.readBps ? card.writeColor : card.readColor) : "transparent"
                border.width: 1
                border.color: busy ? color : card.theme.tint(0.4)
                SequentialAnimation on opacity {
                    running: card.heavyIo && card.live
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) activity.opacity = 1
                    NumberAnimation { to: 0.2; duration: 220; easing.type: Easing.InQuad }
                    NumberAnimation { to: 1; duration: 220; easing.type: Easing.OutQuad }
                }
            }
            VectorGlyph {
                Layout.preferredWidth: 10; Layout.preferredHeight: 10
                path: "M12 4 V19 M6.5 13.5 L12 19 L17.5 13.5"
                source: card.theme.icon("netDown")
                color: card.readColor
                strokeWidth: 2.6
            }
            Text {
                text: i18nc("disk read rate", "R: %1", Disk.rate(card.readBps))
                color: card.readBps >= 1000 ? card.readColor : card.theme.tint(0.55)
                font { family: card.theme.mono; pixelSize: 9; bold: card.readBps >= 1000 }
            }
            VectorGlyph {
                Layout.leftMargin: 4
                Layout.preferredWidth: 10; Layout.preferredHeight: 10
                path: "M12 20 V5 M6.5 10.5 L12 5 L17.5 10.5"
                source: card.theme.icon("netUp")
                color: card.writeColor
                strokeWidth: 2.6
            }
            Text {
                text: i18nc("disk write rate", "W: %1", Disk.rate(card.writeBps))
                color: card.writeBps >= 1000 ? card.writeColor : card.theme.tint(0.55)
                font { family: card.theme.mono; pixelSize: 9; bold: card.writeBps >= 1000 }
            }
        }

        // ---- segmented capacity gauge ----
        DynamicMetricGauge {
            id: gauge
            Layout.fillWidth: true
            Layout.preferredHeight: card.minimal ? 6 : 9
            Layout.bottomMargin: 2
            theme: card.theme
            shape: card.theme.skinned ? card.theme.gaugeShape : "segmented"
            segments: card.minimal ? 20 : 24
            value: Math.round(card.percent / 100 * segments) / segments
            fillColor: card.fillColor
            outlined: false
            live: card.theme.live
        }
    }
}
