import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.notification
import org.kde.plasma.plasmoid
import "common"

// "Theme Store": community skins from the GitHub registry (skins/registry.json,
// built by tools/package_skins.sh), installed with contents/tools/skin_installer.sh
// into ~/.local/share/subetha/themes/<id>/. Applying one writes activeSkin
// straight to the widget's configuration rather than through a cfg_ property,
// so the Guide repaints at once instead of waiting for Apply.
KCM.ScrollViewKCM {
    id: page

    readonly property string registryUrl: "https://raw.githubusercontent.com/Shani2480/subetha-guide/main/skins/registry.json"

    property var remoteSkins: []
    property string registryState: "loading"     // loading | ready | offline
    property string workingId: ""        // the skin being downloaded
    readonly property string activeSkin: Plasmoid.configuration.activeSkin

    readonly property ConfigSkin look: ConfigSkin {}   // the drawn pieces follow the active skin
    readonly property color termBg: look.skinned ? look.theme.bg : "#040806"
    readonly property color termInk: look.skinned ? look.theme.ink : "#00FF66"
    readonly property color termWarn: look.skinned ? look.theme.accent : "#FFB000"

    SkinEngine {
        id: skinEngine
        activeSkin: page.activeSkin
        onFinished: (action, skinId, ok, message) => {
            if (action !== "install") return
            page.workingId = ""
            var skin = page.remoteSkins.find(s => s.id === skinId)
            var name = skin ? skin.name : skinId
            notice.title = ok ? i18n("Skin installed") : i18n("Skin install failed")
            notice.text = ok ? i18n("%1 is ready to apply.", name) : i18n("%1: %2", name, message || i18n("unknown error"))
            notice.iconName = ok ? "get-hot-new-stuff" : "dialog-error"
            notice.sendEvent()
            // An update to the skin in use: the widget's own SkinEngine reloads on
            // an activeSkin change, so nudge it.
            if (ok && skinId === page.activeSkin) {
                Plasmoid.configuration.activeSkin = ""
                Plasmoid.configuration.activeSkin = skinId
            }
        }
    }
    Notification {
        id: notice
        componentName: "plasma_workspace"
        eventId: "notification"
    }

    function fetchRegistry() {
        registryState = "loading"
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            try {
                if (xhr.status !== 200) throw new Error(xhr.status)
                var registry = JSON.parse(xhr.responseText)
                remoteSkins = (registry.skins || []).filter(s => s && s.id && s.tarballUrl)
                registryState = "ready"
            } catch (e) {
                registryState = "offline"
            }
        }
        xhr.open("GET", registryUrl + "?t=" + Date.now())   // past GitHub's raw-file cache
        xhr.send()
    }
    Component.onCompleted: fetchRegistry()

    function apply(id) { Plasmoid.configuration.activeSkin = id }
    function install(skin) {
        workingId = skin.id
        skinEngine.install(skin.tarballUrl, skin.id, skin.sha256 || "")
    }
    function remove(id) {
        if (id === activeSkin) apply("")
        skinEngine.remove(id)
    }
    // update | active | apply | install
    function actionFor(skin) {
        if (!skinEngine.installed(skin.id)) return "install"
        if (skinEngine.compareVersions(skinEngine.installedVersion(skin.id), skin.version) < 0) return "update"
        return skin.id === activeSkin ? "active" : "apply"
    }

    header: RowLayout {
        spacing: Kirigami.Units.smallSpacing
        QQC2.Label {
            Layout.fillWidth: true
            text: page.activeSkin === ""
                  ? i18n("Using the built-in palette.")
                  : i18n("Active skin: %1", (skinEngine.active && skinEngine.active.name) || page.activeSkin)
            elide: Text.ElideRight
        }
        QQC2.Button {
            visible: page.activeSkin !== ""
            text: i18n("Use Built-in Palette")
            icon.name: "edit-undo"
            onClicked: page.apply("")
        }
        QQC2.Button {
            text: i18n("Refresh")
            icon.name: "view-refresh"
            enabled: page.registryState !== "loading"
            onClicked: page.fetchRegistry()
        }
    }

    view: GridView {
        id: grid
        model: page.registryState === "ready" ? page.remoteSkins : []
        readonly property int columns: Math.max(1, Math.floor(width / (Kirigami.Units.gridUnit * 15)))
        cellWidth: Math.floor(width / columns)
        cellHeight: Kirigami.Units.gridUnit * 19

        delegate: Item {
            id: cell
            required property var modelData
            readonly property string action: page.actionFor(modelData)
            readonly property bool working: page.workingId === modelData.id
            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
                anchors { fill: parent; margins: Kirigami.Units.smallSpacing }
                radius: 10
                color: Kirigami.Theme.backgroundColor
                border.width: 2
                border.color: cell.action === "active" ? Kirigami.Theme.highlightColor
                            : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.25)

                ColumnLayout {
                    anchors { fill: parent; margins: Kirigami.Units.largeSpacing }
                    spacing: Kirigami.Units.smallSpacing

                    Rectangle {   // preview
                        Layout.fillWidth: true
                        Layout.preferredHeight: width * 10 / 16
                        radius: 6
                        color: page.termBg
                        clip: true
                        Image {
                            id: preview
                            anchors.fill: parent
                            source: cell.modelData.previewUrl || ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        QQC2.Label {
                            anchors.centerIn: parent
                            visible: preview.status !== Image.Ready
                            text: preview.status === Image.Loading ? i18n("RECEIVING…") : i18n("NO PREVIEW")
                            color: page.termInk
                            font { family: look.mono; bold: true }
                        }
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: cell.modelData.name || cell.modelData.id
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: i18n("v%1 · by %2", cell.modelData.version || "?", cell.modelData.author || i18n("unknown"))
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        elide: Text.ElideRight
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: cell.modelData.description || ""
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                        font: Kirigami.Theme.smallFont
                    }
                    QQC2.ProgressBar {
                        Layout.fillWidth: true
                        visible: cell.working
                        indeterminate: true
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        QQC2.Button {
                            Layout.fillWidth: true
                            enabled: !cell.working && !skinEngine.busy && cell.action !== "active"
                            icon.name: cell.working ? "" : cell.action === "active" ? "checkmark"
                                     : cell.action === "apply" ? "dialog-ok-apply" : cell.action === "update" ? "update-none" : "download"
                            text: cell.working ? i18n("Downloading%1", ".".repeat(dots.count + 1))
                                : cell.action === "active" ? i18n("Active")
                                : cell.action === "apply" ? i18n("Apply Theme")
                                : cell.action === "update" ? i18n("Update")
                                : i18n("Download & Install")
                            onClicked: cell.action === "apply" ? page.apply(cell.modelData.id) : page.install(cell.modelData)
                            Timer {
                                id: dots
                                property int count: 0
                                running: cell.working
                                repeat: true
                                interval: 400
                                onTriggered: count = (count + 1) % 3
                            }
                        }
                        QQC2.ToolButton {
                            visible: cell.action !== "install" && !cell.working
                            enabled: !skinEngine.busy
                            icon.name: "edit-delete-remove"
                            onClicked: page.remove(cell.modelData.id)
                            QQC2.ToolTip.text: i18n("Remove this skin")
                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                        }
                    }
                }
            }
        }

        // Loading, offline and empty: a CRT readout over the empty grid.
        Rectangle {
            id: panel
            visible: page.registryState !== "ready" || page.remoteSkins.length === 0
            anchors.centerIn: parent
            width: Math.min(parent.width - Kirigami.Units.gridUnit * 2, Kirigami.Units.gridUnit * 26)
            height: readout.implicitHeight + Kirigami.Units.gridUnit * 3
            radius: 10
            color: page.termBg
            border { width: 2; color: page.registryState === "offline" ? page.termWarn : page.termInk }
            clip: true

            Image {
                visible: !look.skinned || look.theme.fx.crtScanlines
                anchors.fill: parent
                source: Qt.resolvedUrl("common/scanlines.svg")
                sourceSize: Qt.size(4, 2)
                fillMode: Image.Tile
                smooth: false
                opacity: 0.15
            }
            Rectangle {   // the sweep
                visible: page.registryState === "loading"
                width: parent.width
                height: 3
                color: page.termInk
                opacity: 0.6
                NumberAnimation on y {
                    running: page.registryState === "loading"
                    from: 0; to: panel.height
                    loops: Animation.Infinite
                    duration: 1400
                }
            }
            ColumnLayout {
                id: readout
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.gridUnit * 2
                spacing: Kirigami.Units.largeSpacing
                QQC2.Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: page.registryState === "offline" ? page.termWarn : page.termInk
                    font { family: look.mono; bold: true }
                    text: page.registryState === "loading"
                          ? look.say(i18n("SCANNING SUB-ETHA SKIN REGISTRY%1", cursor.on ? " ▮" : "  "), i18n("SCANNING SKIN REGISTRY%1", cursor.on ? " ▮" : "  "))
                        : page.registryState === "offline"
                          ? look.say(i18n("UNABLE TO CONTACT SUB-ETHA SKIN REGISTRY. CHECK NETWORK CONNECTION."), i18n("UNABLE TO CONTACT THE SKIN REGISTRY. CHECK NETWORK CONNECTION."))
                        : i18n("NO SKINS IN THE REGISTRY YET.")
                    Timer {
                        id: cursor
                        property bool on: true
                        running: page.registryState === "loading"
                        repeat: true
                        interval: 500
                        onTriggered: on = !on
                    }
                }
                QQC2.Button {
                    Layout.alignment: Qt.AlignHCenter
                    visible: page.registryState === "offline"
                    text: i18n("Retry")
                    icon.name: "view-refresh"
                    onClicked: page.fetchRegistry()
                }
            }
        }
    }
}
