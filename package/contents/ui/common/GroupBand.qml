import QtQuick
import QtQuick.Layouts

// A Win32 group's title (theme.groupBands): a flat band in the dialog's
// shade with the skin's icon, the title in bold caps and a status or unit to
// the right in regular weight, over a 1px rule. The skin's sections colours
// (bandColor, bandText, bandStatus, rule) replace the defaults drawn from
// its card and ink.
Item {
    id: band

    property QtObject theme
    property string title: ""
    property string status: ""
    property string icon: ""               // an image URL (theme.icon(key)), or none
    property bool hovered: false           // a linked title underlines

    readonly property var spec: theme.skin && theme.skin.sections ? theme.skin.sections : ({})
    readonly property color bandColor: theme.osColor("sections", "bandColor", Qt.darker(theme.card, theme.dark ? 0.85 : 1.04))
    readonly property color textColor: theme.osColor("sections", "bandText", theme.ink)
    readonly property color statusColor: theme.osColor("sections", "bandStatus", theme.inkSoft)
    readonly property color ruleColor: theme.osColor("sections", "rule", theme.tint(theme.dark ? 0.25 : 0.18))

    implicitHeight: Math.max(18, row.implicitHeight + 6) + 1
    implicitWidth: row.implicitWidth

    Rectangle {
        width: parent.width; height: parent.height - 1
        color: band.bandColor
    }
    RowLayout {
        id: row
        anchors { left: parent.left; right: parent.right; leftMargin: 4; rightMargin: 4; verticalCenter: parent.verticalCenter; verticalCenterOffset: -0.5 }
        spacing: 6
        Image {
            visible: band.icon !== ""
            Layout.preferredWidth: 16; Layout.preferredHeight: 16
            source: band.icon
            sourceSize: Qt.size(32, 32)
            smooth: true
        }
        Text {
            Layout.fillWidth: true
            text: band.spec.uppercase === false ? band.title : band.title.toUpperCase()
            color: band.textColor
            elide: Text.ElideRight
            font { family: band.theme.sans; pixelSize: band.spec.titleSize || 11; bold: true; underline: band.hovered }
        }
        Text {
            visible: band.status !== ""
            text: band.status
            color: band.statusColor
            font { family: band.theme.sans; pixelSize: band.spec.titleSize || 11 }
        }
    }
    Rectangle {   // the rule
        anchors.bottom: parent.bottom
        width: parent.width; height: 1
        color: band.ruleColor
    }
}
