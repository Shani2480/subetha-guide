import QtQuick
import QtQuick.Effects

// The dark name plaque the scrap and candy frames hang at the top: the
// title in bold (a soft bloom of its own colour when `bloom`), a small
// subtitle under it, and art at both ends (`leftArt`, `rightArt`), turning
// slowly when `spin`. It sizes to its text, up to `maxWidth`.
Item {
    id: marquee

    property QtObject theme
    property string title: ""
    property string subtitle: ""
    property color plaque: "#1B1F24"
    property color textColor: "white"
    property color subtextColor: "#B0B0B0"
    property color ink: theme.border
    property bool bloom: false
    property string leftArt: ""
    property string rightArt: ""
    property real artSize: 44
    property bool spin: false
    property real maxWidth: 400
    readonly property alias plate: plateRect

    readonly property real artRoom: (leftArt ? artSize + 6 : 0) + (rightArt ? artSize + 6 : 0)
    implicitWidth: plateRect.width + artRoom
    implicitHeight: Math.max(48, artSize)

    Rectangle {
        id: plateRect
        anchors.centerIn: parent
        width: Math.min(marquee.maxWidth - marquee.artRoom, Math.max(titleText.implicitWidth, subText.implicitWidth) + 30)
        height: 48
        radius: 7
        color: marquee.plaque
        border { width: 3; color: marquee.ink }
        Text {
            id: titleText
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: subText.visible ? 5 : 13 }
            width: Math.min(implicitWidth, plateRect.width - 12)
            elide: Text.ElideRight
            text: marquee.title
            color: marquee.textColor
            font { family: marquee.theme.sans; pixelSize: 16; bold: true; letterSpacing: 0.8 }
            layer.enabled: marquee.bloom && GraphicsInfo.api !== GraphicsInfo.Software
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: titleText.color
                shadowBlur: 0.6
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
        }
        Text {
            id: subText
            visible: text !== ""
            anchors { horizontalCenter: parent.horizontalCenter; top: titleText.bottom }
            width: Math.min(implicitWidth, plateRect.width - 16)
            text: marquee.subtitle
            color: marquee.subtextColor
            elide: Text.ElideRight
            font { family: marquee.theme.sans; pixelSize: 8; bold: true; letterSpacing: 0.6 }
        }
    }
    Repeater {
        model: [marquee.leftArt, marquee.rightArt]
        Image {
            required property string modelData
            required property int index
            visible: modelData !== ""
            x: index === 0 ? plateRect.x - width - 6 : plateRect.x + plateRect.width + 6
            anchors.verticalCenter: parent.verticalCenter
            width: marquee.artSize; height: marquee.artSize
            source: modelData
            sourceSize: Qt.size(marquee.artSize * 2, marquee.artSize * 2)
            fillMode: Image.PreserveAspectFit
            NumberAnimation on rotation {
                running: marquee.spin
                from: 0; to: index === 0 ? 360 : -360
                duration: 9000
                loops: Animation.Infinite
            }
        }
    }
}
