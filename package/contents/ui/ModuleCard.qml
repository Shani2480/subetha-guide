import QtQuick
import QtQuick.Layouts
import "common"

// A Guide section's card: the VectorFrame with a small section label (glyph
// and title, full mode only) above the module panel, which goes in as the
// default property, and the [ - ] / [ + ] density tag on its top border.
// A gap below keeps it clear of the next card.
Item {
    id: card

    property QtObject theme
    property string title: ""
    property string glyph: ""
    property bool minimal: false
    property real gap: 8
    default property alias body: column.data

    signal densityToggled()

    implicitHeight: frame.implicitHeight + gap

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
                    Layout.fillWidth: true
                    text: card.title
                    color: card.theme.ink
                    font { family: card.theme.mono; pixelSize: 11; bold: true; letterSpacing: 0.8 }
                    elide: Text.ElideRight
                }
            }
        }
    }
    DensityToggle {
        theme: card.theme
        compact: card.minimal
        onToggled: card.densityToggled()
    }
}
