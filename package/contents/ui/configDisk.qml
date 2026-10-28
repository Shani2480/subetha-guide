import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "disk"

// "Disks & Storage": which volumes the storage section shows, and in which
// figures.
KCM.SimpleKCM {
    id: page

    property string cfg_diskDensity
    property string cfg_diskDensityDefault

    property var cfg_selectedMountPoints: ["/"]
    property var cfg_selectedMountPointsDefault
    property string cfg_storageUnit
    property string cfg_storageUnitDefault
    property string cfg_valueFormat
    property string cfg_valueFormatDefault
    property alias cfg_showIoThroughput: ioCheck.checked
    property alias cfg_hideRemovableDisks: removableCheck.checked
    property alias cfg_showBootPartitions: bootCheck.checked
    property alias cfg_warningThreshold: thresholdSpin.value

    Kirigami.FormLayout {
        DensityPicker {
            Kirigami.FormData.label: i18n("Section density:")
            density: page.cfg_diskDensity
            compactDescription: i18n("Compact: one slim pill per volume with its label, figure and capacity bar.")
            fullDescription: i18n("Full: expanded drive cards with live read / write speeds, filesystem badge, mount point and a segmented gauge.")
            onPicked: density => page.cfg_diskDensity = density
        }
        VolumePicker {
            Kirigami.FormData.label: i18n("Show:")
            selected: page.cfg_selectedMountPoints
            showBoot: page.cfg_showBootPartitions
            onPicked: keys => page.cfg_selectedMountPoints = keys
        }
        QQC2.CheckBox {
            id: removableCheck
            Kirigami.FormData.label: i18n("Removable:")
            text: i18n("Hide USB and external drives")
        }
        QQC2.CheckBox {
            id: bootCheck
            Kirigami.FormData.label: i18n("System:")
            text: i18n("Show boot and EFI partitions")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Display")
        }
        QQC2.CheckBox {
            id: ioCheck
            Kirigami.FormData.label: i18n("Throughput:")
            text: i18n("Show live read / write speeds")
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Figure:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18n("Free space"), value: "free" },
                { text: i18n("Used space"), value: "used" },
                { text: i18n("Used / total"), value: "both" }
            ]
            currentIndex: Math.max(0, model.findIndex(m => m.value === page.cfg_valueFormat))
            onActivated: page.cfg_valueFormat = currentValue
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Unit:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18n("Automatic"), value: "auto" },
                { text: i18n("Gigabytes (GB)"), value: "GB" },
                { text: i18n("Terabytes (TB)"), value: "TB" },
                { text: i18n("Percent"), value: "percent" }
            ]
            currentIndex: Math.max(0, model.findIndex(m => m.value === page.cfg_storageUnit))
            onActivated: page.cfg_storageUnit = currentValue
        }
        QQC2.SpinBox {
            id: thresholdSpin
            Kirigami.FormData.label: i18n("Warning at:")
            from: 50; to: 99
            textFromValue: (v) => i18n("%1% used", v)
            valueFromText: (t) => parseInt(t)
        }
    }
}
