import QtQuick

// A skin's walkers (theme.roamers), in place of Arthur and Marvin: up to three
// flat sprites in a line, the first leading, each later one `follow` px behind
// the one before. They stroll the track between minTrackX and maxTrackX and
// rest now and then; while walking each steps through its SVG `frames`, one
// frame per `stride` px travelled, so the feet keep pace with the ground.
// At either end of the track the whole line turns round, mirrored, never
// walking backwards.
//
// Per-sprite extras: `bob` lifts it on each step, `stretch` squashes and
// stretches it like a cartoon, `notes` floats music notes over it on some
// rests (an accordion break), `waves` makes it wave (a rocking hop) while the
// pointer is over the hero card. The feet stand on y = ground; the host sets
// y from that, and the track and homeX, but must not bind x.
Item {
    id: line

    property var roamers: []
    property bool running: false
    property bool hovered: false
    property color noteColor: "black"
    property real minTrackX: 0
    property real maxTrackX: 0
    property real homeX: (minTrackX + maxTrackX) / 2

    readonly property real speed: 18          // px/s
    readonly property real headroom: 14       // above the tallest sprite, for notes and hops
    readonly property real tallest: Math.max.apply(null, roamers.map(r => r.height).concat([1]))
    readonly property real ground: headroom + tallest

    property int facing: 1                    // 1 = walking right, -1 = left
    property bool walking: false
    property bool concert: false              // a rest spent playing
    property real travel: 0                   // px walked, for the frame cycle

    // Each sprite's left edge while facing right: the leader at the front.
    readonly property var offsets: {
        var xs = [], x = 0
        for (var i = roamers.length - 1; i >= 0; i--) {
            xs[i] = x
            x += roamers[i].width + (i > 0 ? roamers[i].follow : 0)
        }
        return xs
    }
    width: roamers.reduce((w, r, i) => w + r.width + (i > 0 ? r.follow : 0), 0) || 1
    height: ground

    Component.onCompleted: x = Math.max(minTrackX, Math.min(maxTrackX, homeX))
    onMaxTrackXChanged: if (x > maxTrackX) x = Math.max(minTrackX, maxTrackX)
    onMinTrackXChanged: if (x < minTrackX) x = minTrackX

    // ---- wandering: walk 3-7 s, rest 4-9 s; hovering holds them still ----
    Timer {
        id: wander
        running: line.running && !line.hovered
        interval: 4000
        onTriggered: {
            line.walking = !line.walking
            line.concert = !line.walking && Math.random() < 0.5
            interval = line.walking ? 3000 + Math.random() * 4000 : 4000 + Math.random() * 5000
            restart()
        }
    }
    onHoveredChanged: if (hovered) { walking = false; concert = false }
    onRunningChanged: if (!running) { walking = false; concert = false }

    FrameAnimation {
        running: line.running && line.walking
        onTriggered: {
            var step = line.speed * Math.min(frameTime, 0.1)
            var next = line.x + line.facing * step
            if (next >= line.maxTrackX) { next = line.maxTrackX; line.facing = -1 }
            else if (next <= line.minTrackX) { next = line.minTrackX; line.facing = 1 }
            line.x = next
            line.travel += step
        }
    }

    // ---- hover wave: a rocking hop, 0..1..0 ----
    property real wave: 0
    SequentialAnimation on wave {
        running: line.hovered && line.running
        loops: Animation.Infinite
        onRunningChanged: if (!running) line.wave = 0
        NumberAnimation { to: 1; duration: 260; easing.type: Easing.OutQuad }
        NumberAnimation { to: -1; duration: 520; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 260; easing.type: Easing.InQuad }
    }

    Item {   // the sprites, mirrored as one when walking left
        anchors.fill: parent
        transform: Scale { origin.x: line.width / 2; xScale: line.facing }

        Repeater {
            model: line.roamers
            Item {
                id: sprite
                required property var modelData
                required property int index
                readonly property real phase: line.travel / modelData.stride * Math.PI
                readonly property real bob: modelData.bob && line.walking ? Math.abs(Math.sin(phase)) * 2.5 : 0
                readonly property real squash: modelData.stretch && line.walking ? Math.sin(phase * 2) * 0.06 : 0
                readonly property real hop: modelData.waves ? Math.abs(line.wave) * 5 : index === 0 ? Math.abs(line.wave) * 2 : 0
                x: line.offsets[index] || 0
                y: line.ground - height - bob - hop
                width: modelData.width
                height: modelData.height

                Image {
                    anchors.fill: parent
                    source: !line.walking && sprite.modelData.idleFrame ? sprite.modelData.idleFrame
                          : sprite.modelData.frames[line.walking ? Math.floor(line.travel / sprite.modelData.stride) % sprite.modelData.frames.length : 0]
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    transform: [
                        Scale {
                            origin { x: sprite.width / 2; y: sprite.height }
                            xScale: 1 - sprite.squash; yScale: 1 + sprite.squash
                        },
                        Rotation {
                            origin { x: sprite.width / 2; y: sprite.height }
                            angle: sprite.modelData.waves ? line.wave * 12 : 0
                        }
                    ]
                }
            }
        }
    }

    // Music notes over a sprite with `notes` while the line rests in concert;
    // outside the mirror, so the glyphs read the right way round.
    Repeater {
        model: line.roamers.length
        Item {
            id: notes
            required property int index
            readonly property var r: line.roamers[index]
            readonly property real cx: (line.offsets[index] || 0) + r.width / 2
            visible: r.notes && line.concert && !line.walking
            x: line.facing === 1 ? cx : line.width - cx
            y: line.ground - r.height
            Repeater {
                model: ["♪", "♫"]
                Text {
                    id: note
                    required property string modelData
                    required property int index
                    text: modelData
                    color: line.noteColor
                    font { pixelSize: 11; bold: true }
                    opacity: 0
                    SequentialAnimation {
                        running: notes.visible && line.running
                        loops: Animation.Infinite
                        PauseAnimation { duration: note.index * 700 }
                        ParallelAnimation {
                            NumberAnimation { target: note; property: "y"; from: -4; to: -line.headroom - 6; duration: 1400; easing.type: Easing.OutQuad }
                            NumberAnimation { target: note; property: "x"; from: note.index ? 2 : -6; to: note.index ? 8 : -12; duration: 1400 }
                            SequentialAnimation {
                                NumberAnimation { target: note; property: "opacity"; from: 0; to: 0.9; duration: 300 }
                                NumberAnimation { target: note; property: "opacity"; to: 0; duration: 1100 }
                            }
                        }
                        PauseAnimation { duration: 700 - note.index * 700 }
                    }
                }
            }
        }
    }
}
