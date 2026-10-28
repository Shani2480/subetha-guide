import QtQuick
import QtQuick.Layouts
import "../common"

// SUB-ETHA HOST PROFILE: the machine's processor, graphics, memory and
// kernel / OS in monospace, inside a thin border with a flat 2D shadow.
// `specs` is Sys.parseSpecs output, or null while it is being read.
Item {
    id: banner

    property QtObject theme
    property var specs: null

    implicitHeight: box.implicitHeight + 2

    Rectangle {   // flat offset shadow
        x: 2; y: 2
        width: box.width; height: box.height
        radius: box.radius
        color: banner.theme.dark ? banner.theme.tint(0.12) : banner.theme.ink
        opacity: banner.theme.dark ? 1 : 0.85
    }
    Rectangle {
        id: box
        width: parent.width - 2
        implicitHeight: rows.implicitHeight + 16
        radius: banner.theme.pillRadius
        color: banner.theme.card
        border.width: 1
        border.color: banner.theme.tint(banner.theme.dark ? 0.4 : 0.55)

        ColumnLayout {
            id: rows
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8; leftMargin: 12; rightMargin: 12 }
            spacing: 3
            Text {
                Layout.fillWidth: true
                Layout.bottomMargin: 2
                text: banner.theme.lex("hostProfile", i18n("SUB-ETHA HOST PROFILE // COMPUTATIONAL FABRIC"), i18n("HOST PROFILE"))
                color: banner.theme.accent
                font { family: banner.theme.mono; pixelSize: 10; bold: true; letterSpacing: 0.5 }
                elide: Text.ElideRight
            }
            Repeater {
                model: [
                    { label: i18n("PROCESSOR"), key: "processor" },
                    { label: "GPU",       key: "gpu" },
                    { label: i18n("MEMORY"),    key: "memory" },
                    { label: i18n("KERNEL/OS"), key: "system" }
                ]
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        Layout.preferredWidth: 66
                        text: modelData.label
                        color: banner.theme.tint(0.6)
                        font { family: banner.theme.mono; pixelSize: 10; bold: true }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: banner.specs ? banner.specs[modelData.key] : i18n("READING...")
                        color: banner.theme.ink
                        font { family: banner.theme.mono; pixelSize: 10 }
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
