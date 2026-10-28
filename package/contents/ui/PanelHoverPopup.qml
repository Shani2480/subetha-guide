import QtQuick
import org.kde.plasma.core as PlasmaCore
import "common"

// The panel item's hover card: a frameless tooltip window beside the panel
// drawn in the Guide's own theme (VectorFrame: CRT black with phosphor
// outline and amber reticles, or cream paper with a charcoal outline and
// flat shadow) under a "SUB-ETHA SENSOR TELEMETRY" header, holding the
// large card of whatever the panel item shows (`content`). The window
// reports `hovered` so the panel item keeps it open while the pointer
// crosses over to it.
PlasmaCore.Dialog {
    id: popup

    property QtObject theme
    property Component content
    readonly property bool hovered: cardHover.hovered

    type: PlasmaCore.Dialog.Tooltip
    flags: Qt.ToolTip | Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
    backgroundHints: PlasmaCore.Dialog.NoBackground
    hideOnWindowDeactivate: false

    mainItem: Item {
        width: 380
        height: frame.implicitHeight
        HoverHandler { id: cardHover }
        VectorFrame {
            id: frame
            width: parent.width
            theme: popup.theme
            plain: false
            padding: 12
            Column {
                width: parent.width
                spacing: 8
                Text {
                    width: parent.width
                    text: i18n("SUB-ETHA SENSOR TELEMETRY")
                    color: popup.theme.accent
                    font { family: popup.theme.mono; pixelSize: 10; bold: true; letterSpacing: 1 }
                    leftPadding: 10   // clear of the corner reticle
                }
                Loader {
                    width: parent.width
                    active: popup.visible
                    sourceComponent: popup.content
                }
            }
        }
    }
}
