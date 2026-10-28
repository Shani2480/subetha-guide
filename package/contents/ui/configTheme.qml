import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "common"

// "Appearance & Sections": the one theme every section follows (picked from
// miniature preview cards, PreviewCard.qml), and which sections the Guide
// shows. Each section's density lives on its own tab (DensityPicker.qml).
KCM.SimpleKCM {
    id: page

    property string cfg_themeMode
    property string cfg_themeModeDefault
    property var cfg_enabledSections: ["weather", "system", "disk", "battery"]
    property var cfg_enabledSectionsDefault
    property string cfg_panelDisplaySensor
    property string cfg_panelDisplaySensorDefault
    property alias cfg_showPanelIcon: panelIconCheck.checked
    property alias cfg_showPanelMeter: panelMeterCheck.checked
    property alias cfg_panelCycleInterval: cycleSpin.value

    // Panel item choices, with a sample of how each reads in the panel.
    readonly property var panelSensors: [
        { value: "weather",   text: i18n("Weather temperature"), sample: "☁ 11°" },
        { value: "cpuLoad",   text: i18n("CPU load"),            sample: i18nc("panel label", "CPU") + " 42%" },
        { value: "cpuTemp",   text: i18n("CPU temperature"),     sample: i18nc("panel label", "CPU") + " 58°C" },
        { value: "gpuTemp",   text: i18n("GPU temperature"),     sample: i18nc("panel label", "GPU") + " 62°C" },
        { value: "ramUsage",  text: i18n("Memory usage"),        sample: i18nc("panel label", "RAM") + " 44%" },
        { value: "netSpeed",  text: i18n("Network download"),    sample: i18nc("panel label", "NET") + " ↓12.4M" },
        { value: "battery",   text: i18n("Battery level"),       sample: i18nc("panel label", "BAT") + " 87%" },
        { value: "multiPill", text: i18n("Several at once"),     sample: "☁ 11° │ " + i18nc("panel label", "CPU") + " 42% │ " + i18nc("panel label", "BAT") + " 87%" }
    ]

    readonly property var sections: [
        { key: "weather", text: i18n("Weather: sky hero card, forecast drawers, Arthur and Marvin") },
        { key: "system",  text: i18n("System: CPU, memory, GPU, network and fans") },
        { key: "disk",    text: i18n("Storage: volumes, capacity and I/O throughput") },
        { key: "battery", text: i18n("Power: batteries and live wattage") }
    ]
    function enabled(key) { return (cfg_enabledSections || []).indexOf(key) >= 0 }
    // Kept in the fixed section order, whatever order they were ticked in.
    function setEnabled(key, on) {
        cfg_enabledSections = sections.map(s => s.key).filter(k => k === key ? on : enabled(k))
    }

    Kirigami.FormLayout {
        // ---- theme: three miniature cards ----
        RowLayout {
            Kirigami.FormData.label: i18n("Guide theme:")
            spacing: Kirigami.Units.largeSpacing

            PreviewCard {
                title: i18n("Movie Encyclopedia")
                cardDescription: i18n("Movie Encyclopedia: Clean cream parchment background with bold 2D graphic typography, flat shadows, and Shynola-inspired infographic colors.")
                selected: page.cfg_themeMode === "light"
                onClicked: page.cfg_themeMode = "light"
                surface: "#F5F2EB"
                MovieSchematic { anchors.fill: parent }
            }
            PreviewCard {
                title: i18n("Sub-Etha Terminal")
                cardDescription: i18n("Sub-Etha Terminal: Classic 1981 BBC green phosphor CRT display with scanlines, coordinate grids, and amber telemetry alerts.")
                selected: page.cfg_themeMode === "dark"
                onClicked: page.cfg_themeMode = "dark"
                surface: "#040806"
                CrtSchematic { anchors.fill: parent }
            }
            PreviewCard {
                title: i18n("Solar Auto")
                cardDescription: i18n("Solar Synchronization: Automatically switches to Movie Light at sunrise and Sub-Etha CRT Dark at sunset based on local coordinates.")
                selected: page.cfg_themeMode === "auto"
                onClicked: page.cfg_themeMode = "auto"
                surface: "#040806"
                Item {   // left half movie, right half CRT, sun and moon on the seam
                    anchors.fill: parent
                    Item {
                        width: parent.width / 2; height: parent.height
                        clip: true
                        MovieSchematic { width: parent.width * 2; height: parent.height }
                    }
                    Item {
                        x: parent.width / 2; width: parent.width / 2; height: parent.height
                        clip: true
                        CrtSchematic { x: -parent.width; width: parent.width * 2; height: parent.height }
                    }
                    Rectangle { x: parent.width / 2 - 1; width: 2; height: parent.height; color: "#FFBE1A" }
                    VectorGlyph {   // sun
                        x: parent.width / 2 - 30; y: parent.height - 30; width: 24; height: 24
                        path: "M8 12 A4 4 0 1 0 16 12 A4 4 0 1 0 8 12 Z M12 2 V5 M12 19 V22 M2 12 H5 M19 12 H22 M4.9 4.9 L7 7 M17 17 L19.1 19.1 M4.9 19.1 L7 17 M17 7 L19.1 4.9"
                        color: "#E8890C"; strokeWidth: 2
                    }
                    VectorGlyph {   // moon
                        x: parent.width / 2 + 6; y: parent.height - 30; width: 24; height: 24
                        path: "M15 3 A9 9 0 1 0 21 15 A7 7 0 0 1 15 3 Z"
                        color: "#00FF66"; strokeWidth: 1.8
                    }
                }
            }
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            visible: page.cfg_themeMode === "auto"
            text: i18n("Auto follows sunrise and sunset at the weather location (Weather & Location tab).")
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            text: i18n("Each section is Compact or Full on its own: pick it on the section's tab, or click the [ - ] / [ + ] tag on its card.")
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Sections")
        }
        Repeater {
            model: page.sections
            QQC2.CheckBox {
                required property var modelData
                required property int index
                Kirigami.FormData.label: index === 0 ? i18n("Show:") : ""
                text: modelData.text
                checked: page.enabled(modelData.key)
                onToggled: page.setEnabled(modelData.key, checked)
            }
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            text: i18n("A section that is switched off folds away and stops sampling.")
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }

        // ---- panel item ----
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Panel Display")
        }
        QQC2.ComboBox {
            id: panelSensorBox
            Kirigami.FormData.label: i18n("Show in panel:")
            textRole: "text"
            valueRole: "value"
            model: page.panelSensors
            currentIndex: Math.max(0, model.findIndex(m => m.value === page.cfg_panelDisplaySensor))
            onActivated: page.cfg_panelDisplaySensor = currentValue
        }
        Rectangle {   // preview of the panel item
            Kirigami.FormData.label: i18n("Preview:")
            implicitWidth: previewText.implicitWidth + (page.cfg_showPanelMeter && previewMeter.visible ? 36 : 0) + 20
            implicitHeight: 28
            radius: 4
            color: Kirigami.Theme.alternateBackgroundColor
            border { width: 1; color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.25) }
            readonly property var choice: page.panelSensors[Math.max(0, panelSensorBox.currentIndex)]
            Row {
                anchors.centerIn: parent
                spacing: 8
                QQC2.Label {
                    id: previewText
                    anchors.verticalCenter: parent.verticalCenter
                    text: page.cfg_panelCycleInterval > 0 && parent.parent.choice.value !== "multiPill"
                          ? i18n("%1  → next every %2 s", parent.parent.choice.sample, page.cfg_panelCycleInterval)
                          : parent.parent.choice.sample
                    font { family: "monospace"; bold: true }
                }
                Rectangle {
                    id: previewMeter
                    visible: page.cfg_showPanelMeter && ["weather", "netSpeed", "multiPill"].indexOf(parent.parent.choice.value) < 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24; height: 3; radius: 1
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)
                    Rectangle { width: parent.width * 0.45; height: parent.height; radius: 1; color: Kirigami.Theme.highlightColor }
                }
            }
        }
        QQC2.CheckBox {
            id: panelIconCheck
            Kirigami.FormData.label: i18n("Icon:")
            text: i18n("Show the reading's icon (weather condition, chip, battery...)")
        }
        QQC2.CheckBox {
            id: panelMeterCheck
            Kirigami.FormData.label: i18n("Meter:")
            text: i18n("Show a micro progress bar next to the figure")
        }
        QQC2.SpinBox {
            id: cycleSpin
            Kirigami.FormData.label: i18n("Cycle readings:")
            from: 0; to: 600
            textFromValue: (v) => v === 0 ? i18n("Off") : i18n("Every %1 s", v)
            valueFromText: (t) => parseInt(t) || 0
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            text: i18n("Cycling steps through the readings of the sections switched on above. Middle-click the panel item to refresh the forecast.")
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
    }

    // Movie Encyclopedia miniature: cream parchment, dark chocolate rules,
    // apricot and mustard pills with flat offset shadows.
    component MovieSchematic: Item {
        Rectangle { anchors.fill: parent; color: "#F5F2EB" }
        Rectangle { x: 10; y: 10; width: 70; height: 6; radius: 3; color: "#3B2418" }
        Rectangle { x: 10; y: 20; width: 46; height: 4; radius: 2; color: "#3B2418"; opacity: 0.5 }
        Repeater {
            model: [{ c: "#FFB38A", w: 0.85 }, { c: "#FFBE1A", w: 0.6 }]
            Item {
                required property var modelData
                required property int index
                x: 10; y: 34 + index * 26; width: parent.width - 20; height: 20
                Rectangle { x: 2; y: 2; width: parent.width; height: parent.height; radius: 10; color: "#3B2418" }
                Rectangle {
                    width: parent.width; height: parent.height; radius: 10
                    color: "#FFFFFF"; border { width: 2; color: "#3B2418" }
                    Rectangle { x: 6; y: 6; width: (parent.width - 12) * modelData.w; height: 8; radius: 4; color: modelData.c }
                }
            }
        }
    }
    // Sub-Etha terminal miniature: CRT black, phosphor grid, amber reticle.
    component CrtSchematic: Item {
        Rectangle { anchors.fill: parent; color: "#040806" }
        Repeater {   // coordinate grid
            model: 8
            Rectangle { required property int index; x: index * 20; width: 1; height: parent.height; color: "#00FF66"; opacity: 0.18 }
        }
        Repeater {
            model: 6
            Rectangle { required property int index; y: index * 20; width: parent.width; height: 1; color: "#00FF66"; opacity: 0.18 }
        }
        Rectangle { x: 10; y: 12; width: 60; height: 4; color: "#00FF66" }
        Rectangle { x: 10; y: 22; width: 84; height: 10; color: "transparent"; border { width: 1; color: "#00FF66" }
            Rectangle { x: 2; y: 2; width: 48; height: 6; color: "#00FF66" } }
        Rectangle { x: 10; y: 38; width: 84; height: 10; color: "transparent"; border { width: 1; color: "#00FF66" }
            Rectangle { x: 2; y: 2; width: 28; height: 6; color: "#FFB000" } }
        Item {   // amber targeting reticle
            x: parent.width - 44; y: parent.height - 44; width: 30; height: 30
            Rectangle { anchors.centerIn: parent; width: 22; height: 22; radius: 11; color: "transparent"; border { width: 1.5; color: "#FFB000" } }
            Rectangle { anchors.centerIn: parent; width: parent.width; height: 1.5; color: "#FFB000" }
            Rectangle { anchors.centerIn: parent; width: 1.5; height: parent.height; color: "#FFB000" }
        }
    }
}
