import QtQuick

// The Guide's cover legend as a pill: mustard with a charcoal outline on the
// movie pages, an amber outline on the terminal. A skin brings its own legend
// and colours.
Rectangle {
    id: badge

    property QtObject theme
    property string text: theme.skinned ? theme.badgeText : i18n("DON'T PANIC")
    property int pixelSize: 12

    implicitWidth: label.implicitWidth + pixelSize * 1.7
    implicitHeight: label.implicitHeight + pixelSize * 0.7
    radius: theme.skinned ? Math.min(height / 2, theme.outerRadius) : height / 2
    color: theme.dark && !theme.skinned ? "transparent" : theme.badge
    visible: text !== ""
    border.width: theme.skinned ? Math.min(2, theme.borderWidth) : 2
    border.color: theme.skinned ? theme.border : theme.dark ? theme.badge : theme.ink

    Text {
        id: label
        anchors.centerIn: parent
        text: badge.text
        color: badge.theme.badgeInk
        font { family: badge.theme.sans; pixelSize: badge.pixelSize; weight: Font.Black; letterSpacing: 0.8 }
    }
}
