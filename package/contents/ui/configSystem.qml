import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as P5Support

// "System Hardware": which pills the system section shows, which GPU the GPU
// pill follows, its extras and how often it samples.
KCM.SimpleKCM {
    id: page

    property string cfg_systemDensity
    property string cfg_gpuDevice
    property string cfg_gpuDeviceDefault

    // The GPUs ksystemstats reports, listed once when the page opens.
    property var gpus: []
    readonly property var gpuChoices: [{ value: "auto", text: i18n("Automatic (first GPU)") }]
        .concat(gpus.map(g => ({ value: g.id, text: i18n("GPU %1: %2", g.id.slice(3), g.name) })))
    P5Support.DataSource {
        engine: "executable"
        connectedSources: ["kstatsviewer --list 2>/dev/null | grep -E '^gpu/gpu[0-9]+/usage '"]
        onNewData: (source, data) => {
            disconnectSource(source)
            page.gpus = String(data["stdout"] || "").split("\n")
                .map(l => l.match(/^gpu\/(gpu\d+)\/usage\s+(.*?)\s*Usage\s*$/))
                .filter(m => m).map(m => ({ id: m[1], name: m[2] }))
        }
    }
    property string cfg_systemDensityDefault

    property var cfg_visibleSensors: ["cpu", "ram", "net", "gpu"]
    property var cfg_visibleSensorsDefault
    property alias cfg_showFanSpeeds: fansCheck.checked
    property alias cfg_showFanPercent: fanPercentCheck.checked
    property alias cfg_fanMaxRpm: fanMaxSpin.value
    property alias cfg_tempColorAlerts: tempAlertsCheck.checked
    property alias cfg_tempWarnPercent: tempWarnSpin.value
    property alias cfg_tempCriticalPercent: tempCriticalSpin.value
    // The temperature bars run 30-100 °C; a threshold as % of that scale, in °C.
    function celsiusAt(percent) { return Math.round(30 + 70 * percent / 100) }
    property alias cfg_showTelemetryGraphs: graphsCheck.checked
    property alias cfg_showSystemSpecs: specsCheck.checked
    property alias cfg_systemUpdateInterval: intervalSpin.value
    property string cfg_tempUnit
    property string cfg_tempUnitDefault

    function shows(kind) { return (cfg_visibleSensors || []).indexOf(kind) >= 0 }
    function setShown(kind, on) {
        var list = (cfg_visibleSensors || []).filter(k => k !== kind)
        if (on) list.push(kind)
        cfg_visibleSensors = list
    }

    Kirigami.FormLayout {
        DensityPicker {
            Kirigami.FormData.label: i18n("Section density:")
            density: page.cfg_systemDensity
            compactDescription: i18n("Compact: condensed one-line pills (CPU load and temperature, RAM, GPU, network). No sparklines or hardware banner.")
            fullDescription: i18n("Full: expanded cards with rolling sparkline graphs, the hardware profile banner and fan speed dials.")
            onPicked: density => page.cfg_systemDensity = density
        }
        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Show:")
            text: i18n("CPU load, clock and temperature")
            checked: page.shows("cpu")
            onToggled: page.setShown("cpu", checked)
        }
        QQC2.CheckBox {
            text: i18n("Memory")
            checked: page.shows("ram")
            onToggled: page.setShown("ram", checked)
        }
        QQC2.CheckBox {
            text: i18n("GPU load, temperature and VRAM")
            checked: page.shows("gpu")
            onToggled: page.setShown("gpu", checked)
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("GPU:")
            enabled: page.shows("gpu")
            textRole: "text"
            valueRole: "value"
            model: page.gpuChoices
            // A saved GPU that is no longer present still shows, so it is not silently replaced.
            currentIndex: Math.max(0, model.findIndex(m => m.value === page.cfg_gpuDevice))
            onActivated: page.cfg_gpuDevice = currentValue
        }
        QQC2.Label {
            visible: page.gpus.length < 2
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            text: page.gpus.length === 1 ? i18n("Only one GPU is reporting on this machine.")
                                         : i18n("No GPU is reporting through the system monitor.")
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
        QQC2.CheckBox {
            text: i18n("Network throughput")
            checked: page.shows("net")
            onToggled: page.setShown("net", checked)
        }
        QQC2.CheckBox {
            id: fansCheck
            text: i18n("Cooling fans / RPM")
        }
        QQC2.CheckBox {
            id: fanPercentCheck
            Layout.leftMargin: Kirigami.Units.gridUnit
            enabled: fansCheck.checked
            text: i18n("Show fan speed as a percentage")
        }
        QQC2.SpinBox {
            id: fanMaxSpin
            Kirigami.FormData.label: i18n("Fan full speed:")
            enabled: fansCheck.checked
            from: 1000; to: 20000
            stepSize: 100
            editable: true
            textFromValue: (v) => i18n("%1 RPM", v)
            valueFromText: (t) => parseInt(t)
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Temperature alerts")
        }
        QQC2.CheckBox {
            id: tempAlertsCheck
            Kirigami.FormData.label: i18n("Colours:")
            text: i18n("Change the CPU / GPU temperature colour as it heats up")
        }
        QQC2.SpinBox {
            id: tempWarnSpin
            Kirigami.FormData.label: i18n("Warning (orange) from:")
            enabled: tempAlertsCheck.checked
            from: 50; to: 99
            textFromValue: (v) => i18n("%1% of range (%2 °C)", v, page.celsiusAt(v))
            valueFromText: (t) => parseInt(t)
            onValueModified: if (tempCriticalSpin.value < value) tempCriticalSpin.value = value
        }
        QQC2.SpinBox {
            id: tempCriticalSpin
            Kirigami.FormData.label: i18n("Critical (red, pulsing) from:")
            enabled: tempAlertsCheck.checked
            from: tempWarnSpin.value; to: 100
            textFromValue: (v) => i18n("%1% of range (%2 °C)", v, page.celsiusAt(v))
            valueFromText: (t) => parseInt(t)
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            text: i18n("The bars run from 30 °C to 100 °C. At the critical level the pill's border pulses too and the panel icon asks for attention. With colours off the temperature keeps its normal amber.")
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Full mode extras")
        }
        QQC2.CheckBox {
            id: graphsCheck
            Kirigami.FormData.label: i18n("Graphs:")
            text: i18n("Rolling sparklines in each pill")
        }
        QQC2.CheckBox {
            id: specsCheck
            Kirigami.FormData.label: i18n("Host profile:")
            text: i18n("Show CPU, GPU, memory and OS banner")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Sampling")
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Temperature:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18n("Celsius (°C)"), value: "C" },
                { text: i18n("Fahrenheit (°F)"), value: "F" }
            ]
            currentIndex: Math.max(0, model.findIndex(m => m.value === page.cfg_tempUnit))
            onActivated: page.cfg_tempUnit = currentValue
        }
        QQC2.SpinBox {
            id: intervalSpin
            Kirigami.FormData.label: i18n("Update every:")
            from: 500; to: 10000
            stepSize: 500
            textFromValue: (v) => i18n("%1 s", (v / 1000).toFixed(1))
            valueFromText: (t) => Math.round(parseFloat(t) * 1000)
        }
    }
}
