import QtQuick

// A mounting screw in each corner of a panel (sections.screws): a domed
// steel head with a slot, each turned its own way.
Item {
    id: screws

    property real inset: 6
    property real size: 7
    property color ink: "#3A3A3A"

    Repeater {
        model: [[0, 0, 20], [1, 0, -35], [0, 1, 70], [1, 1, 5]]
        Rectangle {
            required property var modelData
            x: modelData[0] ? screws.width - screws.inset - width : screws.inset
            y: modelData[1] ? screws.height - screws.inset - height : screws.inset
            width: screws.size; height: width; radius: width / 2
            border { width: 1; color: screws.ink }
            gradient: Gradient {
                GradientStop { position: 0; color: "#F2F2F2" }
                GradientStop { position: 1; color: "#8C8C8C" }
            }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.7; height: 1.2
                color: screws.ink
                rotation: parent.modelData[2]
            }
        }
    }
}
