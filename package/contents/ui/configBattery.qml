import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "battery"

// "Power & Battery": which batteries the power section shows, and how.
KCM.SimpleKCM {
    id: page

    property string cfg_batteryDensity
    property string cfg_batteryDensityDefault

    property var cfg_selectedBatteryDevices: ["all"]
    property var cfg_selectedBatteryDevicesDefault
    property alias cfg_showPowerRate: rateCheck.checked
    property alias cfg_showPercentageOnly: percentOnlyCheck.checked
    property alias cfg_showChargingEstimate: estimateCheck.checked
    property alias cfg_alertThreshold: thresholdSpin.value
    property alias cfg_batteryBlink: blinkCheck.checked

    Kirigami.FormLayout {
        DensityPicker {
            Kirigami.FormData.label: i18n("Section density:")
            density: page.cfg_batteryDensity
            compactDescription: i18n("Compact: a slim bar per device with its percentage and wattage.")
            fullDescription: i18n("Full: expanded cards for the laptop and each peripheral, with status, live wattage, a segmented gauge and time to full / empty.")
            onPicked: density => page.cfg_batteryDensity = density
        }
        DevicePicker {
            Kirigami.FormData.label: i18n("Show:")
            selected: page.cfg_selectedBatteryDevices
            onPicked: keys => page.cfg_selectedBatteryDevices = keys
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Display")
        }
        QQC2.CheckBox {
            id: rateCheck
            Kirigami.FormData.label: i18n("Power rate:")
            text: i18n("Show live charge / drain wattage")
        }
        QQC2.CheckBox {
            id: percentOnlyCheck
            Kirigami.FormData.label: i18n("Gauges:")
            text: i18n("Show percentage only (hide the segmented bars)")
        }
        QQC2.CheckBox {
            id: estimateCheck
            Kirigami.FormData.label: i18n("Estimates:")
            text: i18n("Show time to empty / time to full")
        }
        QQC2.SpinBox {
            id: thresholdSpin
            Kirigami.FormData.label: i18n("Critical warning below:")
            from: 1; to: 50
            textFromValue: (v) => v + "%"
            valueFromText: (t) => parseInt(t)
        }
        QQC2.CheckBox {
            id: blinkCheck
            Kirigami.FormData.label: i18n("Low battery:")
            text: i18n("Blink the percentage and DEPLETION IMMINENT below the warning level")
        }
    }
}
