import QtQuick

// A surface texture a skin asks for (features.texture), painted once per
// size under a frame's content: "carbon" a 2x2 twill weave, "brushed" fine
// horizontal streaks, "noise" a faint speckle. Seeded, so it never shimmers
// between repaints.
Canvas {
    id: tex

    property string kind: ""
    property color color: "white"
    property real strength: 0.06

    visible: kind !== ""
    renderStrategy: Canvas.Cooperative
    onKindChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        if (kind === "") return
        var c = tex.color, a = tex.strength
        var rgba = k => "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + k + ")"
        if (kind === "carbon") {
            var s = 6                                              // one weave cell
            for (var y = 0; y < height; y += s)
                for (var x = 0; x < width; x += s) {
                    var odd = ((x / s) + (y / s)) % 2 === 1
                    var g = ctx.createLinearGradient(x, y, odd ? x + s : x, odd ? y : y + s)
                    g.addColorStop(0, rgba(a * 1.6))
                    g.addColorStop(0.5, rgba(a * 0.3))
                    g.addColorStop(1, rgba(0))
                    ctx.fillStyle = g
                    ctx.fillRect(x, y, s - 1, s - 1)
                }
        } else if (kind === "brushed") {
            var seed = 7
            for (var row = 0; row < height; row++) {
                seed = (seed * 9301 + 49297) % 233280
                ctx.fillStyle = rgba(a * (seed / 233280))
                ctx.fillRect(0, row, width, 1)
            }
        } else {
            var n = 11
            for (var i = 0; i < width * height / 18; i++) {
                n = (n * 9301 + 49297) % 233280
                var px = n % Math.max(1, Math.floor(width))
                n = (n * 9301 + 49297) % 233280
                ctx.fillStyle = rgba(a * 1.5)
                ctx.fillRect(px, n % Math.max(1, Math.floor(height)), 1, 1)
            }
        }
    }
}
