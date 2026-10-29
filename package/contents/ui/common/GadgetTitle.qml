import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

// A Vista Sidebar gadget's title (theme.sectionStyle "gadget"): the skin's
// icon, the title in white bold caps over a black shadow, and at the right
// the settings gear and the red bevelled close box. The gear is ornament;
// the close box folds the section to compact (closeClicked).
Item {
    id: title

    property QtObject theme
    property string text: ""
    property string icon: ""
    signal closeClicked()

    readonly property var spec: theme.skin && theme.skin.sections ? theme.skin.sections : ({})
    implicitHeight: 20

    RowLayout {
        anchors.fill: parent
        spacing: 6
        Image {
            visible: title.icon !== ""
            Layout.preferredWidth: 16; Layout.preferredHeight: 16
            source: title.icon
            sourceSize: Qt.size(32, 32)
        }
        Item {
            Layout.fillWidth: true
            implicitHeight: label.implicitHeight
            Text {
                x: 1; y: 1
                width: parent.width
                text: label.text
                font: label.font
                color: "#000000"
                opacity: 0.8
                elide: Text.ElideRight
            }
            Text {
                id: label
                width: parent.width
                text: title.text.toUpperCase()
                color: title.theme.osColor("sections", "bandText", "#FFFFFF")
                elide: Text.ElideRight
                font { family: title.theme.sans; pixelSize: 11; bold: true; letterSpacing: 0.4 }
            }
        }
        Item {   // the settings gear
            Layout.preferredWidth: 14; Layout.preferredHeight: 14
            Image {
                visible: !!title.spec.gear
                anchors.fill: parent
                source: title.spec.gear || ""
                sourceSize: Qt.size(28, 28)
            }
            Shape {
                visible: !title.spec.gear
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "#E8F4F8"; strokeWidth: 1.6; fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathSvg { path: "M 7 4.5 A 2.5 2.5 0 1 0 7 9.5 A 2.5 2.5 0 1 0 7 4.5 Z M 7 1 V 3 M 7 11 V 13 M 1 7 H 3 M 11 7 H 13 M 2.8 2.8 L 4.2 4.2 M 9.8 9.8 L 11.2 11.2 M 2.8 11.2 L 4.2 9.8 M 9.8 4.2 L 11.2 2.8" }
                }
            }
        }
        Item {   // the close box, which folds the section
            Layout.preferredWidth: 14; Layout.preferredHeight: 14
            Image {
                visible: !!title.spec.close
                anchors.fill: parent
                source: title.spec.close || ""
                sourceSize: Qt.size(28, 28)
            }
            Rectangle {
                visible: !title.spec.close
                anchors.fill: parent
                radius: 3
                border { width: 1; color: "#5A0E08" }
                gradient: Gradient {
                    GradientStop { position: 0; color: "#F08A70" }
                    GradientStop { position: 0.5; color: "#D0402C" }
                    GradientStop { position: 1; color: "#A02818" }
                }
                Text { anchors.centerIn: parent; text: "✕"; color: "white"; font { pixelSize: 9; bold: true } }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: title.closeClicked()
            }
        }
    }
}
