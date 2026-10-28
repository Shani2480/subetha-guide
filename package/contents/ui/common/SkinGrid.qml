import QtQuick

// A skin's coordinate grid, in its own colour: 24px cells with a heavier
// line every fourth, so it never borrows the Guide's grid art. One 96px tile
// is built as an SVG and tiled, uploaded once rather than painted per resize.
Image {
    id: grid

    property color color: "white"
    property real cell: 24

    readonly property int tile: cell * 4
    readonly property string hex: "#" + [color.r, color.g, color.b]
                                  .map(c => ("0" + Math.round(c * 255).toString(16)).slice(-2)).join("")
    source: {
        var lines = ""
        for (var i = 0; i < 4; i++) {
            var at = i * grid.cell + 0.5, w = i === 0 ? 1 : 0.5, a = i === 0 ? 1 : 0.55
            lines += "<path d='M" + at + " 0V" + grid.tile + "M0 " + at + "H" + grid.tile
                   + "' stroke='" + grid.hex + "' stroke-width='" + w + "' stroke-opacity='" + a + "'/>"
        }
        return "data:image/svg+xml;utf8," + encodeURIComponent("<svg xmlns='http://www.w3.org/2000/svg' width='" + grid.tile
               + "' height='" + grid.tile + "' fill='none'>" + lines + "</svg>")
    }
    sourceSize: Qt.size(tile, tile)
    fillMode: Image.Tile
    smooth: false
}
