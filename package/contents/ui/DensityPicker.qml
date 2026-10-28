import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// A section's density picked from two miniature cards (PreviewCard.qml):
// Compact, a slim low-profile strip, and Full, the expanded dashboard. Each
// config tab passes its own descriptions; `picked` carries "compact" or "full".
RowLayout {
    id: picker

    property string density: "full"
    property string compactDescription: ""
    property string fullDescription: ""

    signal picked(string density)

    spacing: Kirigami.Units.largeSpacing
    readonly property color ink: Kirigami.Theme.textColor
    readonly property color accent: Kirigami.Theme.highlightColor

    PreviewCard {
        title: i18n("Compact")
        cardDescription: picker.compactDescription
        selected: picker.density === "compact"
        onClicked: picker.picked("compact")
        Column {   // two slim pills
            anchors.centerIn: parent
            spacing: 8
            Repeater {
                model: [0.7, 0.4]
                Rectangle {
                    required property real modelData
                    width: 104; height: 24; radius: 8
                    color: "transparent"
                    border { width: 1.5; color: picker.ink }
                    Rectangle { x: 8; y: 6; width: 10; height: 10; radius: 2; color: "transparent"; border { width: 1.5; color: picker.ink } }
                    Rectangle { x: 24; y: 8; width: 40; height: 3; radius: 1.5; color: picker.ink; opacity: 0.7 }
                    Rectangle { x: 24; y: 15; width: 72 * modelData; height: 3; radius: 1.5; color: picker.accent }
                }
            }
        }
    }
    PreviewCard {
        title: i18n("Full")
        cardDescription: picker.fullDescription
        selected: picker.density === "full"
        onClicked: picker.picked("full")
        Item {   // section label over two tall pills with readouts and a sparkline
            anchors { fill: parent; margins: 8 }
            Rectangle { x: 2; y: 2; width: 10; height: 8; radius: 2; color: "transparent"; border { width: 1.2; color: picker.accent } }
            Rectangle { x: 16; y: 4; width: 50; height: 4; radius: 2; color: picker.ink; opacity: 0.8 }
            Repeater {
                model: 2
                Rectangle {
                    required property int index
                    y: 16 + index * 36; width: parent.width; height: 32; radius: 6
                    color: "transparent"; border { width: 1.2; color: picker.ink }
                    Rectangle { x: 6; y: 6; width: 34; height: 4; radius: 2; color: picker.ink; opacity: 0.7 }
                    Rectangle { x: parent.width - 30; y: 5; width: 24; height: 6; radius: 2; color: picker.ink }
                    Row {   // sparkline bars
                        x: 6; y: 14
                        spacing: 2
                        Repeater {
                            model: [5, 8, 6, 10, 7, 12, 9, 13, 8, 11, 14, 10, 12, 9, 13, 11, 8, 12, 10, 14, 12, 9, 11, 13, 10, 12, 14, 11]
                            Rectangle {
                                required property int modelData
                                y: 14 - modelData
                                width: 2; height: modelData
                                color: picker.accent
                                opacity: 0.8
                            }
                        }
                    }
                }
            }
        }
    }
}
