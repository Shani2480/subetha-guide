import QtQuick

// The whole Guide dressed as one window of the operating system a skin
// imitates (theme.windowed): the frame in its border colour with the top
// corners rounded as that OS has them, WindowChrome across the top, and the
// window's body (the skin's card colour) holding the sections, padded.
// A skin with a console frame (frame.style "console") gets ConsoleFrame's
// cabinet instead: its rail, plaque and pillars round the same body.
// Without such a skin it is a plain column: the content and nothing else.
// Under features.barrel the whole window is bent like a CRT's glass
// (shaders/barrel.frag); input is not remapped, which the slight curve allows.
Item {
    id: win

    property QtObject theme
    property string title: ""
    default property alias content: body.data
    readonly property bool on: theme.windowed
    readonly property var spec: theme.chromeSpec || ({})
    readonly property string style: theme.chromeStyle
    // a console or scrap frame round the body instead of a title bar
    readonly property bool cabinet: on && (theme.consoleFrame || theme.scrapFrame || theme.candyFrame) && style === ""
    readonly property Item cabinetItem: theme.scrapFrame ? scrapCab : theme.candyFrame ? candyCab : cab
    // the room the frame takes round the body
    readonly property real topInset: cabinet ? cabinetItem.topHeight : chrome.height
    readonly property real sideInset: cabinet ? cabinetItem.sideWidth + 6 : border
    readonly property real bottomInset: cabinet ? cabinetItem.bottomHeight + 6 : border

    readonly property real border: !on ? 0 : spec.frameWidth !== null && spec.frameWidth !== undefined ? spec.frameWidth
                                 : ({ luna: 3, aqua: 1, aero: 5, material: 0, terminal: 1, kiroshi: 1.5, hud: 1.5 })[style] || 1
    readonly property real topRadius: !on ? 0 : spec.topRadius !== null && spec.topRadius !== undefined ? spec.topRadius
                                    : ({ luna: 8, aqua: 10, aero: 7, material: 24, terminal: 0, kiroshi: 0 })[style] || 0
    readonly property real bottomRadius: !on ? 0 : spec.bottomRadius !== null && spec.bottomRadius !== undefined ? spec.bottomRadius
                                       : ({ luna: 0, aqua: 10, aero: 7, material: 24, terminal: 0, kiroshi: 0 })[style] || 0
    readonly property real pad: !on ? 0 : style === "material" ? 12 : 8
    readonly property color frameColor: theme.osColor("chrome", "frameColor",
        ({ luna: theme.dark ? "#2A3650" : "#0046D5", aqua: theme.dark ? "#000000" : "#B4B4B4",
           aero: chrome.bottomColor, material: theme.card, terminal: theme.ink, kiroshi: theme.accent })[style] || theme.border)
    readonly property color bodyColor: theme.card

    readonly property real footerHeight: on && theme.vignettesAt("footer").length ? 56 : 0
    implicitHeight: on ? topInset + bottomInset + pad * 2 + body.childrenRect.height + footerHeight : body.childrenRect.height

    layer.enabled: on && !!theme.fx.barrel
    layer.effect: ShaderEffect {
        property real curvature: 0.035
        fragmentShader: Qt.resolvedUrl("shaders/barrel.frag.qsb")
    }

    // hud: the frame is the theme's own card outline (chamfer cuts and all) in the accent
    readonly property bool shaped: style === "hud"
    ConsoleFrame {
        id: cab
        visible: win.cabinet && win.theme.consoleFrame
        anchors.fill: parent
        theme: win.theme
    }
    CandyFrame {
        id: candyCab
        visible: win.cabinet && win.theme.candyFrame
        anchors.fill: parent
        theme: win.theme
    }
    ScrapFrame {
        id: scrapCab
        visible: win.cabinet && win.theme.scrapFrame
        anchors.fill: parent
        theme: win.theme
    }
    ThemeShapeContainer {
        visible: win.on && win.shaped
        anchors.fill: parent
        theme: win.theme
        role: "card"
        fillColor: win.bodyColor
        strokeColor: win.theme.osColor("chrome", "frameColor", win.theme.accent)
        strokeWidth: win.border
        shadowType: "none"
    }
    Rectangle {   // the frame: the border shows down the sides and along the bottom
        visible: win.on && !win.shaped && !win.cabinet
        anchors.fill: parent
        topLeftRadius: win.topRadius; topRightRadius: win.topRadius
        bottomLeftRadius: win.bottomRadius; bottomRightRadius: win.bottomRadius
        color: win.frameColor
    }
    Rectangle {   // the body
        visible: win.on && !win.shaped
        x: win.sideInset; y: win.topInset
        width: win.width - win.sideInset * 2
        height: win.height - win.topInset - win.bottomInset
        radius: win.cabinet ? 6 : 0
        border { width: win.cabinet ? 3 : 0; color: win.theme.border }
        bottomLeftRadius: win.cabinet ? 6 : Math.max(0, win.bottomRadius - win.border)
        bottomRightRadius: win.cabinet ? 6 : Math.max(0, win.bottomRadius - win.border)
        color: win.bodyColor
        SkinTexture {
            anchors.fill: parent
            kind: win.theme.fx.texture || ""
            color: win.theme.ink
        }
    }
    WindowChrome {
        id: chrome
        visible: win.on && !win.cabinet
        x: win.shaped ? win.border + win.theme.chamferCut * 0.5 : 0
        width: win.shaped ? win.width - x * 2 : win.width
        height: win.on && !win.cabinet ? implicitHeight : 0
        theme: win.theme
        title: win.title
        topRadius: win.topRadius
    }
    Column {   // the footer's characters (narrative.vignettes at "footer"), under the body
        visible: win.on
        anchors { right: parent.right; rightMargin: win.sideInset + win.pad; bottom: parent.bottom; bottomMargin: win.bottomInset + 4 }
        Repeater {
            model: win.theme.vignettesAt("footer")
            Vignette { required property var modelData; theme: win.theme; art: modelData.art; text: modelData.text; width: Math.min(implicitWidth, win.width * 0.7) }
        }
    }
    Item {
        id: body
        x: win.sideInset + win.pad
        y: win.topInset + win.pad
        width: win.width - (win.sideInset + win.pad) * 2
        height: childrenRect.height
    }
}
