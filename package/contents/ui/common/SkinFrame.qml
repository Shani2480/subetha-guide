import QtQuick

// A bitmap skin's card outline (sections.frame, theme.cardFrame): the
// picture nine-sliced so its corners, and a tab painted into one, keep their
// shape while the edges between them stretch to the card's size. It is laid
// out at the image's own pixels and scaled down by `spec.scale` as one piece,
// so a 2x image stays sharp on a 2x screen.
Item {
    id: skinFrame

    property var spec: null               // theme.cardFrame
    property string source: ""

    visible: !!spec && source !== "" && picture.status === BorderImage.Ready

    BorderImage {
        id: picture
        readonly property real s: skinFrame.spec ? skinFrame.spec.scale : 1
        width: skinFrame.width / s
        height: skinFrame.height / s
        scale: s
        transformOrigin: Item.TopLeft
        source: skinFrame.spec ? skinFrame.source : ""
        asynchronous: true
        cache: true
        smooth: true
        border {
            left: skinFrame.spec ? skinFrame.spec.border[0] : 0
            top: skinFrame.spec ? skinFrame.spec.border[1] : 0
            right: skinFrame.spec ? skinFrame.spec.border[2] : 0
            bottom: skinFrame.spec ? skinFrame.spec.border[3] : 0
        }
        horizontalTileMode: BorderImage.Stretch
        verticalTileMode: BorderImage.Stretch
    }
}
