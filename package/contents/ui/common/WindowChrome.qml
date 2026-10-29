import QtQuick
import QtQuick.Shapes

// The title bar of the operating system a skin imitates (theme.chromeStyle),
// across the top of GuideWindow. It is ornament: the buttons draw that OS's
// minimize, maximize and close but do nothing, since Plasma owns the widget.
//   luna      Windows XP: a royal-blue gradient with a white specular line,
//             the app icon and a bold title with a dark-blue shadow, the
//             skin's mark, then square 3D buttons, blue, blue and red
//   aqua      macOS: red, yellow and green lights on the left, the title centred
//   aero      Windows Vista: tinted glass with a diagonal gloss over its top
//             third and the joined caption buttons hanging from the top edge
//   material  a tonal surface with the title, no buttons
//   terminal  "[ TITLE ]" and "[_][▫][X]" in the mono font over a rule
//   kiroshi   a chamfered accent tab holding the title, cut-corner buttons
//   hud       a flat tactical strip: the skin's badge, the title in bold
//             sans over a small muted subtitle, flat ≡ – ✕ in the accent
// A skin's chrome colours (titleTop, titleBottom, titleText, titleShadow,
// buttonFace, buttonGlyph, closeFace, closeGlyph) replace each style's own.
Item {
    id: bar

    property QtObject theme
    property string title: ""
    property real topRadius: 0

    readonly property string style: theme.chromeStyle
    readonly property var spec: theme.chromeSpec || ({})
    function c(key, fallback) { return theme.osColor("chrome", key, fallback) }
    readonly property bool dark: theme.dark
    readonly property var defaults: ({
        luna:     { top: dark ? "#3D4E70" : "#0058EE", bottom: dark ? "#2A3650" : "#2E8BFA", text: "#FFFFFF", shadow: dark ? "#10141E" : "#0A246A",
                    face: dark ? "#4D6595" : "#2F6FF2", glyph: "#FFFFFF", close: "#E0471F", closeGlyph: "#FFFFFF" },
        aqua:     { top: dark ? "#3A3A3C" : "#EEEEEE", bottom: dark ? "#2C2C2E" : "#DCDCDC", text: dark ? "#E8E8EA" : "#2B2B2B", shadow: "transparent",
                    face: "#FEBC2E", glyph: "#5A3A00", close: "#FF5F57", closeGlyph: "#6E0B06" },
        aero:     { top: dark ? "#C0263A4A" : "#C8A9D8E6", bottom: dark ? "#C0142430" : "#C06AAFC6", text: dark ? "#FFFFFF" : "#0B1A24",
                    shadow: dark ? "#80000000" : "#A0FFFFFF", face: dark ? "#40FFFFFF" : "#60FFFFFF", glyph: dark ? "#FFFFFF" : "#18323F",
                    close: "#D0402C", closeGlyph: "#FFFFFF" },
        material: { top: theme.card, bottom: theme.card, text: theme.ink, shadow: "transparent",
                    face: theme.tint(0.1), glyph: theme.ink, close: theme.tint(0.1), closeGlyph: theme.ink },
        terminal: { top: theme.bg, bottom: theme.bg, text: theme.ink, shadow: "transparent",
                    face: "transparent", glyph: theme.ink, close: "transparent", closeGlyph: theme.ink },
        kiroshi:  { top: theme.bg, bottom: theme.bg, text: theme.bg, shadow: "transparent",
                    face: theme.cool, glyph: theme.bg, close: theme.red, closeGlyph: theme.bg },
        hud:      { top: theme.card, bottom: theme.card, text: theme.ink, shadow: "transparent",
                    face: "transparent", glyph: theme.accent, close: "transparent", closeGlyph: theme.accent }
    })
    readonly property var d: defaults[style] || defaults.material
    readonly property color topColor: c("titleTop", d.top)
    readonly property color bottomColor: c("titleBottom", d.bottom)
    readonly property color textColor: c("titleText", d.text)
    readonly property color shadowColor: c("titleShadow", d.shadow)
    readonly property color faceColor: c("buttonFace", d.face)
    readonly property color glyphColor: c("buttonGlyph", d.glyph)
    readonly property color closeColor: c("closeFace", d.close)
    readonly property color closeGlyphColor: c("closeGlyph", d.closeGlyph)
    readonly property string appIcon: theme.icon("app")
    readonly property string logo: spec.logo || ""
    readonly property bool centred: spec.titleAlign === "center"
    readonly property bool bold: spec.titleBold !== false

    implicitHeight: spec.titleHeight || ({ luna: 30, aqua: 28, aero: 30, material: 40, terminal: 22, kiroshi: 26, hud: 42 })[style] || 28

    // ---- the bar's face ----
    Rectangle {
        anchors.fill: parent
        visible: bar.style !== "kiroshi"
        topLeftRadius: bar.topRadius
        topRightRadius: bar.topRadius
        gradient: Gradient {
            GradientStop { position: 0; color: bar.topColor }
            GradientStop { position: 1; color: bar.bottomColor }
        }
        Rectangle {   // luna and aqua: the white specular line along the top
            visible: bar.style === "luna" || bar.style === "aqua"
            x: bar.topRadius * 0.6; y: 1
            width: parent.width - x * 2; height: 1
            color: "white"
            opacity: bar.style === "luna" ? (bar.dark ? 0.25 : 0.55) : (bar.dark ? 0.12 : 0.8)
        }
        Rectangle {   // aero: the diagonal gloss over the top third
            visible: bar.style === "aero"
            anchors.fill: parent
            topLeftRadius: bar.topRadius
            topRightRadius: bar.topRadius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#00FFFFFF" }
                GradientStop { position: 0.3; color: bar.dark ? "#30FFFFFF" : "#70FFFFFF" }
                GradientStop { position: 0.55; color: "#00FFFFFF" }
            }
            Rectangle {
                width: parent.width; height: parent.height * 0.42
                topLeftRadius: bar.topRadius
                topRightRadius: bar.topRadius
                color: "white"
                opacity: bar.dark ? 0.08 : 0.22
            }
        }
        Rectangle {   // aqua, material and terminal: the rule under the bar
            visible: bar.style === "aqua" || bar.style === "terminal" || bar.style === "hud"
            anchors.bottom: parent.bottom
            width: parent.width; height: bar.style === "hud" ? 1.5 : 1
            color: bar.style === "terminal" ? bar.textColor : bar.style === "hud" ? bar.theme.accent : bar.dark ? "#000000" : "#B8B8B8"
            opacity: bar.style === "terminal" ? 0.6 : 1
        }
    }

    // ---- kiroshi: a chamfered accent tab for the title ----
    Shape {
        visible: bar.style === "kiroshi"
        width: titleRow.implicitWidth + 34; height: parent.height
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: bar.theme.accent
            PathSvg {
                path: "M 0 0 H " + (titleRow.implicitWidth + 34) + " L " + (titleRow.implicitWidth + 34 - bar.height * 0.6) + " " + bar.height + " H 0 Z"
            }
        }
    }
    Rectangle {   // kiroshi: the rule the tab hangs from, in the cool accent
        visible: bar.style === "kiroshi"
        anchors.bottom: parent.bottom
        width: parent.width; height: 1.5
        color: bar.theme.cool
    }

    // ---- aqua: the traffic lights ----
    Row {
        id: lights
        visible: bar.style === "aqua"
        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
        spacing: 8
        Repeater {
            model: [bar.closeColor, bar.faceColor, bar.c("buttonZoom", "#28C840")]
            Rectangle {
                required property color modelData
                width: 12; height: 12; radius: 6
                color: modelData
                border { width: 0.5; color: Qt.darker(modelData, 1.25) }
                Rectangle {   // the jelly's highlight
                    x: 3; y: 1.5; width: 6; height: 3.5; radius: 2
                    color: "white"; opacity: 0.35
                }
            }
        }
    }

    // ---- the icon and title ----
    Row {
        id: titleRow
        anchors.verticalCenter: parent.verticalCenter
        x: bar.centred ? (bar.width - implicitWidth) / 2
           : bar.style === "aqua" ? lights.x + lights.width + 14
           : bar.style === "material" ? 16 : 8
        spacing: 6
        Image {   // hud: the brand badge
            visible: bar.style === "hud" && !!bar.spec.badge
            anchors.verticalCenter: parent.verticalCenter
            width: 26; height: 26
            source: bar.spec.badge || ""
            sourceSize: Qt.size(52, 52)
            fillMode: Image.PreserveAspectFit
        }
        Image {
            visible: bar.appIcon !== "" && bar.style !== "terminal" && bar.style !== "kiroshi" && bar.style !== "hud"
            anchors.verticalCenter: parent.verticalCenter
            width: 16; height: 16
            source: bar.appIcon
            sourceSize: Qt.size(32, 32)
            smooth: true
        }
        Item {
            width: Math.max(label.implicitWidth, sub.visible ? sub.implicitWidth : 0)
            height: label.implicitHeight + (sub.visible ? sub.implicitHeight : 0)
            anchors.verticalCenter: parent.verticalCenter
            Text {   // a second, muted line under the title
                id: sub
                visible: !!bar.spec.subtitle
                y: label.implicitHeight
                text: (bar.spec.subtitle || "").toUpperCase()
                color: bar.theme.inkSoft
                font { family: bar.theme.sans; pixelSize: 8; letterSpacing: 1 }
            }
            Text {   // the luna and aero title's soft shadow
                visible: bar.shadowColor.a > 0
                x: bar.style === "aero" ? 0 : 1; y: 1
                text: label.text
                color: bar.shadowColor
                font: label.font
                opacity: bar.style === "aero" ? 0.9 : 0.75
            }
            Text {
                id: label
                text: bar.style === "terminal" ? "[ " + bar.title + " ]" : bar.title
                color: bar.textColor
                font {
                    family: bar.style === "terminal" || bar.style === "kiroshi" ? bar.theme.mono : bar.theme.sans
                    pixelSize: bar.style === "material" ? 15 : bar.style === "hud" ? 14 : 13
                    bold: bar.bold && bar.style !== "material"
                    weight: bar.style === "material" ? Font.Medium : (bar.bold ? Font.Bold : Font.Normal)
                    letterSpacing: bar.style === "kiroshi" ? 1.2 : 0
                    capitalization: bar.style === "kiroshi" ? Font.AllUppercase : Font.MixedCase
                }
            }
        }
    }

    // ---- the buttons, right ----
    Row {
        id: buttons
        anchors { right: parent.right; rightMargin: bar.style === "aero" ? 6 : 5 }
        y: bar.style === "aero" ? 0 : (parent.height - height) / 2
        spacing: bar.style === "luna" ? 2 : bar.style === "aero" ? 0 : 4
        visible: bar.style !== "aqua" && bar.style !== "material"

        Image {   // the skin's own mark, before the buttons
            visible: bar.logo !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: 18; height: 18
            source: bar.logo
            sourceSize: Qt.size(36, 36)
        }
        Item { visible: bar.logo !== ""; width: 6; height: 1 }

        Repeater {
            model: ["min", "max", "close"]
            Item {
                id: button
                required property string modelData
                readonly property bool close: modelData === "close"
                width: bar.style === "luna" ? 21 : bar.style === "aero" ? (close ? 42 : 26)
                     : bar.style === "terminal" ? glyphText.implicitWidth : bar.style === "hud" ? 14 : 16
                height: bar.style === "luna" ? 21 : bar.style === "aero" ? 19 : bar.style === "terminal" ? glyphText.implicitHeight : 14

                // luna: a 3D square, white rim, glossy face
                Rectangle {
                    visible: bar.style === "luna"
                    anchors.fill: parent
                    radius: 3
                    border { width: 1; color: "white" }
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.lighter(button.close ? bar.closeColor : bar.faceColor, 1.35) }
                        GradientStop { position: 0.45; color: button.close ? bar.closeColor : bar.faceColor }
                        GradientStop { position: 1; color: Qt.darker(button.close ? bar.closeColor : bar.faceColor, 1.2) }
                    }
                }
                // aero: joined glass caption buttons, rounded where the group ends
                Rectangle {
                    visible: bar.style === "aero"
                    anchors.fill: parent
                    bottomLeftRadius: button.modelData === "min" ? 4 : 0
                    bottomRightRadius: button.close ? 4 : 0
                    border { width: 1; color: bar.dark ? "#60000000" : "#80304A58" }
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.lighter(button.close ? bar.closeColor : bar.faceColor, 1.3) }
                        GradientStop { position: 0.5; color: button.close ? bar.closeColor : bar.faceColor }
                        GradientStop { position: 1; color: Qt.darker(button.close ? bar.closeColor : bar.faceColor, 1.1) }
                    }
                    Rectangle {   // the glass's upper half
                        x: 1; y: 1; width: parent.width - 2; height: parent.height * 0.45
                        color: "white"; opacity: 0.25
                    }
                }
                // kiroshi: a cut-corner chip
                Shape {
                    visible: bar.style === "kiroshi"
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeWidth: 0; strokeColor: "transparent"
                        fillColor: button.close ? bar.closeColor : bar.faceColor
                        PathSvg { path: "M 0 0 H " + (button.width - 4) + " L " + button.width + " 4 V " + button.height + " H 4 L 0 " + (button.height - 4) + " Z" }
                    }
                }

                // the glyph
                Text {
                    id: glyphText
                    visible: bar.style === "terminal"
                    text: button.modelData === "min" ? "[_]" : button.modelData === "max" ? "[▫]" : "[X]"
                    color: bar.glyphColor
                    font { family: bar.theme.mono; pixelSize: 12 }
                }
                Shape {
                    visible: bar.style !== "terminal"
                    anchors.centerIn: parent
                    width: 10; height: 10
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: button.close ? bar.closeGlyphColor : bar.glyphColor
                        strokeWidth: bar.style === "luna" ? (button.close ? 2.2 : 2) : 1.5
                        fillColor: "transparent"
                        capStyle: ShapePath.SquareCap
                        PathSvg {
                            path: bar.style === "hud" && button.modelData === "min" ? "M 1 2 H 9 M 1 5 H 9 M 1 8 H 9"
                                : bar.style === "hud" && button.modelData === "max" ? "M 1 5 H 9"
                                : button.modelData === "min" ? "M 1 9 H 7"
                                : button.modelData === "max" ? "M 1 1 H 9 V 9 H 1 Z M 1 2.5 H 9"
                                : "M 1.5 1.5 L 8.5 8.5 M 8.5 1.5 L 1.5 8.5"
                        }
                    }
                }
            }
        }
    }
}
