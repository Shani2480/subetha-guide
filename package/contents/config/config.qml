import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Appearance & Sections")
        icon: "preferences-desktop-theme"
        source: "configTheme.qml"
    }
    ConfigCategory {
        name: i18n("Clock & Chronometry")
        icon: "preferences-system-time"
        source: "configClock.qml"
    }
    ConfigCategory {
        name: i18n("Weather & Location")
        icon: "weather-clouds"
        source: "configWeather.qml"
    }
    ConfigCategory {
        name: i18n("System Hardware")
        icon: "utilities-system-monitor"
        source: "configSystem.qml"
    }
    ConfigCategory {
        name: i18n("Disks & Storage")
        icon: "drive-harddisk"
        source: "configDisk.qml"
    }
    ConfigCategory {
        name: i18n("Power & Battery")
        icon: "battery-charging"
        source: "configBattery.qml"
    }
}
