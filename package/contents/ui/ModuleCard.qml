import QtQuick
import QtQuick.Layouts
import "common"

// A Guide section's card: the VectorFrame with a small section label (glyph
// and title, full mode only) above the module panel, which goes in as the
// default property, and the [ - ] / [ + ] density tag on its top border.
// With a `monitorTab` the label is a link: it underlines on hover, shows an
// open-in-window arrow, and a click emits monitorRequested for that tab.
// `alertLevel` haloes the card amber or crimson (AlertGlowContainer).
// A gap below keeps it clear of the next card. Under a skin with Win32
// group bands (theme.groupBands) the card is flat and its label a GroupBand,
// with `status` to the right; a skin's icon for `iconKey` replaces the glyph.
// Under flag-tab sections (theme.flagTabs) a FlagTab on the card's top edge,
// numbered `number`, is the label in either density, and the density toggle
// sits at the right of its row. sections.numbered puts `number` before the
// title in any style, sections.lights "traffic" three window dots before it,
// and sections.gloss a gadget's sheen over the card's top.
Item {
    id: card

    property QtObject theme
    property string title: ""
    property string glyph: ""
    property string iconKey: ""
    property string tintKey: ""           // theme.sectionTint(): the skin's surface for this card
    property string status: ""            // a group band's right-hand figure or unit
    property bool minimal: false
    property string monitorTab: ""        // a System Monitor tab, or "" for a plain label
    property int alertLevel: 0            // the worst reading on the card: 0 nominal, 1 warning, 2 critical
    property bool live: false             // on screen: gates the halo's breathing
    property real gap: 8
    property int number: 0                // the section's place among those shown (a numbered FlagTab)
    default property alias body: column.data

    signal densityToggled()
    signal monitorRequested(string tab)

    implicitHeight: frame.y + frame.implicitHeight + gap
    // the title as shown: "N — TITLE" when the skin numbers its sections
    readonly property string label: theme.sectionsNumbered ? theme.sectionLabel(title, number) : title
    readonly property bool gadget: theme.gadgets

    AlertGlowContainer {
        x: frame.x; y: frame.y; width: frame.width; height: frame.height
        theme: card.theme
        role: "card"
        alertLevel: card.alertLevel
        animate: card.theme.alertMotion && card.live
        spread: 2
    }
    FlagTab {
        id: flagTab
        visible: card.theme.flagTabs
        theme: card.theme
        title: card.title
        number: card.number
        MouseArea {
            enabled: card.monitorTab !== ""
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: card.monitorRequested(card.monitorTab)
        }
    }
    VectorFrame {
        id: frame
        y: flagTab.visible ? flagTab.height : 0
        width: parent.width
        active: !card.minimal
        theme: card.theme
        padding: card.theme.groupBands ? 2 : card.minimal ? 10 : 14
        plain: card.minimal || card.theme.minimal
        flat: card.theme.groupBands
        tint: card.theme.sectionTint(card.tintKey)
        gloss: card.gadget ? card.theme.gadgetGloss : card.theme.cardGloss
        ColumnLayout {
            id: column
            width: parent.width
            spacing: card.minimal ? 8 : 10
            GadgetTitle {
                visible: card.gadget && !card.minimal
                Layout.fillWidth: true
                theme: card.theme
                text: card.label
                icon: card.theme.icon(card.iconKey)
                onCloseClicked: card.densityToggled()
            }
            GroupBand {
                visible: card.theme.groupBands
                Layout.fillWidth: true
                theme: card.theme
                title: card.label
                status: card.status
                icon: card.theme.icon(card.iconKey)
                hovered: bandLink.containsMouse
                MouseArea {
                    id: bandLink
                    enabled: card.monitorTab !== ""
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.monitorRequested(card.monitorTab)
                }
            }
            RowLayout {
                id: labelRow
                visible: !card.minimal && !card.theme.groupBands && !card.gadget && !card.theme.flagTabs
                Layout.fillWidth: true
                spacing: 8
                Row {   // traffic lights: close, minimise, zoom
                    visible: card.theme.trafficLights
                    spacing: 6
                    Repeater {
                        model: [["#FF5F56", "#E0443E"], ["#FFBD2E", "#DEA123"], ["#27C93F", "#1AAB29"]]
                        Rectangle {
                            required property var modelData
                            width: 10; height: 10; radius: 5
                            color: modelData[0]
                            border { width: 0.5; color: modelData[1] }
                        }
                    }
                }
                VectorGlyph {
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                    path: card.glyph
                    source: card.theme.icon(card.iconKey)
                    color: card.theme.accent
                    strokeWidth: 2
                }
                Text {
                    id: titleText
                    Layout.fillWidth: !link.enabled
                    Layout.maximumWidth: implicitWidth
                    Layout.minimumWidth: 0
                    text: card.label
                    color: link.containsMouse ? card.theme.accent : card.theme.ink
                    font { family: card.theme.mono; pixelSize: 11; bold: true; letterSpacing: 0.8; underline: link.containsMouse }
                    elide: Text.ElideRight
                    // the glyph, title and arrow; the free space after them stays inert
                    MouseArea {
                        id: link
                        enabled: card.monitorTab !== ""
                        x: -labelRow.spacing - 16
                        y: Math.min(0, (parent.height - 16) / 2)
                        width: parent.width + labelRow.spacing * 2 + 16 + 11
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
    DensityToggle {   // a gadget's close box does this while its title shows
        visible: !(card.gadget && !card.minimal)
        theme: card.theme
        compact: card.minimal
        onToggled: card.densityToggled()
    }
}
