import QtQuick

// Windows Task Manager's graph paper (theme.taskGraphs): a plain background
// with light horizontal and vertical guides every 12px, under the thin
// unfilled history lines. The skin's controls graphBackground and graphGrid
// replace the defaults: black with dark green on a dark variant, white with
// pale grey on a light one.
Rectangle {
    id: grid

    property QtObject theme
    property int cell: 12

    color: theme.osColor("controls", "graphBackground", theme.dark ? "#000000" : "#FFFFFF")
    border { width: 1; color: theme.tint(0.3) }
    readonly property color line: theme.osColor("controls", "graphGrid", theme.dark ? "#008040" : "#D8D8D8")
    clip: true
    Repeater {
        model: Math.max(0, Math.floor(grid.height / grid.cell))
        Rectangle { required property int index; y: (index + 1) * grid.cell; width: grid.width; height: 1; color: grid.line }
    }
    Repeater {
        model: Math.max(0, Math.floor(grid.width / grid.cell))
        Rectangle { required property int index; x: (index + 1) * grid.cell; width: 1; height: grid.height; color: grid.line }
    }
}
