import QtQuick
import QtQuick.Effects

// A bitmap skin's picture behind every card (skin.backdrop): the variant's
// own image, fitted as the skin asks and clipped to `radius` so it keeps
// inside a rounded window. Decoded once, off the UI thread, at its own size,
// so the sections folding and sliding never reload it.
Item {
    id: drop

    property QtObject theme
    property real radius: 0

    readonly property var spec: theme ? theme.backdrop : null
    visible: !!spec && picture.status === Image.Ready

    Image {
        id: picture
        anchors.fill: parent
        source: drop.theme ? drop.theme.backdropSource : ""
        asynchronous: true
        cache: true
        smooth: true
        opacity: drop.spec ? drop.spec.opacity : 1
        fillMode: !drop.spec ? Image.PreserveAspectCrop
                : ({ cover: Image.PreserveAspectCrop, contain: Image.PreserveAspectFit,
                     tile: Image.Tile, stretch: Image.Stretch })[drop.spec.fit]
        verticalAlignment: !drop.spec ? Image.AlignVCenter
                         : ({ top: Image.AlignTop, center: Image.AlignVCenter, bottom: Image.AlignBottom })[drop.spec.align]

        layer.enabled: drop.radius > 0
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }
    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle { anchors.fill: parent; radius: drop.radius; antialiasing: true }
    }
}
