import QtQuick
import QtQuick.Layouts
import "common"

// A Guide section's card: the VectorFrame with a small section label (glyph
// and title, full mode only) above the module panel, which goes in as the
// default property, and the [ - ] / [ + ] density tag on its top border.
// With a `monitorTab` the label is a link: it underlines on hover, shows an
// open-in-window arrow, and a click emits monitorRequested for that tab.
// `alertLevel` haloes the card amber or crimson (AlertGlowContainer).
// A gap below keeps it clear of the next card.
Item {
    id: card

    property QtObject theme
    property string title: ""
    property string glyph: ""
    property bool minimal: false
    property string monitorTab: ""        // a System Monitor tab, or "" for a plain label
    property int alertLevel: 0            // the worst reading on the card: 0 nominal, 1 warning, 2 critical
    property bool live: false             // on screen: gates the halo's breathing
    property real gap: 8
    default property alias body: column.data

    signal densityToggled()
    signal monitorRequested(string tab)

    implicitHeight: frame.implicitHeight + gap

    AlertGlowContainer {
        x: frame.x; y: frame.y; width: frame.width; height: frame.height
        theme: card.theme
        role: "card"
        alertLevel: card.alertLevel
        animate: card.theme.alertMotion && card.live
        spread: 2
    }
    VectorFrame {
        id: frame
        width: parent.width
        theme: card.theme
        padding: card.minimal ? 10 : 14
        plain: card.minimal || card.theme.minimal
        ColumnLayout {
            id: column
            width: parent.width
            spacing: card.minimal ? 8 : 10
            RowLayout {
                id: label
                visible: !card.minimal
                Layout.fillWidth: true
                spacing: 8
                VectorGlyph {
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                    path: card.glyph
                    color: card.theme.accent
                    strokeWidth: 2
                }
                Text {
                    id: titleText
                    Layout.fillWidth: !link.enabled
                    Layout.maximumWidth: implicitWidth
                    Layout.minimumWidth: 0
                    text: card.title
                    color: link.containsMouse ? card.theme.accent : card.theme.ink
                    font { family: card.theme.mono; pixelSize: 11; bold: true; letterSpacing: 0.8; underline: link.containsMouse }
                    elide: Text.ElideRight
                    // the glyph, title and arrow; the free space after them stays inert
                    MouseArea {
                        id: link
                        enabled: card.monitorTab !== ""
                        x: -label.spacing - 16
                        y: Math.min(0, (parent.height - 16) / 2)
                        width: parent.width + label.spacing * 2 + 16 + 11
                        height: Math.max(parent.height, 16)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.monitorRequested(card.monitorTab)
                        SubEthaTooltip {
                            theme: card.theme
                            shown: link.containsMouse
                            text: i18n("OPEN IN SYSTEM MONITOR")
                        }
                    }
                }
                VectorGlyph {   // open in a window: a box with an arrow leaving it
                    visible: link.enabled
                    Layout.preferredWidth: 11
                    Layout.preferredHeight: 11
                    path: "M10 5 H5 V19 H19 V14 M13 4 H20 V11 M20 4 L11 13"
                    color: link.containsMouse ? card.theme.accent : card.theme.tint(0.55)
                    strokeWidth: 2.2
                }
                Item { visible: link.enabled; Layout.fillWidth: true }
            }
        }
    }
    DensityToggle {
        theme: card.theme
        compact: card.minimal
        onToggled: card.densityToggled()
    }
}
