import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import "system/code/system.js" as Sys
import "weather"
import "system"
import "disk"
import "battery"
import "clock"
import "ai"
import "common"
import "common/i18n.js" as I18n

// The Sub-Etha Guide: time, weather, compute, storage and power in one card. Each
// module's feed runs only while its section is switched on (and, for the
// live ones, while the card is on screen and the session unlocked); the
// views get everything as properties.
PlasmoidItem {
    id: root

    // Hands the widget's translations to the JS helpers (common/i18n.js).
    // First binding of the root, so it runs before any helper text is built.
    readonly property bool translatorInstalled: I18n.install(function (kind, a) {
        const n = a.length
        if (kind === "i18nc")
            return n <= 2 ? i18nc(a[0], a[1]) : n === 3 ? i18nc(a[0], a[1], a[2])
                 : n === 4 ? i18nc(a[0], a[1], a[2], a[3]) : i18nc(a[0], a[1], a[2], a[3], a[4])
        if (kind === "i18np")
            return n <= 3 ? i18np(a[0], a[1], a[2]) : n === 4 ? i18np(a[0], a[1], a[2], a[3])
                 : i18np(a[0], a[1], a[2], a[3], a[4])
        return n <= 1 ? i18n(a[0]) : n === 2 ? i18n(a[0], a[1]) : n === 3 ? i18n(a[0], a[1], a[2])
             : i18n(a[0], a[1], a[2], a[3])
    })

    readonly property bool onDesktop: Plasmoid.location === PlasmaCore.Types.Desktop
                                   || Plasmoid.location === PlasmaCore.Types.Floating
                                   || Plasmoid.formFactor === PlasmaCore.Types.Planar
                                   || Plasmoid.formFactor === PlasmaCore.Types.MediaCenter
    readonly property bool shown: expanded || onDesktop || previewing
    property bool previewing: false       // the panel item's hover card is open
    readonly property var cfg: Plasmoid.configuration
    // The clock and the AI section have switches of their own (showClockSection,
    // showAiSection); the clock always leads and the AI section comes last.
    readonly property var sections: (cfg.showClockSection ? ["clock"] : []).concat(cfg.enabledSections)
                                    .concat(cfg.showAiSection ? ["ai"] : [])
    function has(key) { return sections.indexOf(key) >= 0 }
    // Each section is "full" or "compact" on its own (cfg.<key>Density).
    function compact(key) { return !!cfg && cfg[key + "Density"] === "compact" }
    readonly property bool allCompact: sections.length > 0 && sections.every(k => compact(k))
    // The old all-or-nothing displayMode "minimal" becomes every section compact, once.
    Component.onCompleted: {
        if (cfg.displayMode === "minimal") {
            ["weather", "system", "disk", "battery"].forEach(k => cfg[k + "Density"] = "compact")
            cfg.displayMode = "full"
        }
        // The old temperature thresholds, % of a 30-100 °C scale, become °C
        // for both chips, once: a changed pair carries over, then resets.
        if (cfg.tempWarnPercent !== 80 || cfg.tempCriticalPercent !== 90) {
            var warn = Math.round(Sys.tempAt(cfg.tempWarnPercent)), crit = Math.round(Sys.tempAt(cfg.tempCriticalPercent))
            cfg.cpuTempWarnThreshold = cfg.gpuTempWarnThreshold = warn
            cfg.cpuTempCritThreshold = cfg.gpuTempCritThreshold = crit
            cfg.tempWarnPercent = 80
            cfg.tempCriticalPercent = 90
        }
    }

    SessionLock { id: lock; watching: (root.shown && (root.has("system") || root.has("battery"))) || !root.onDesktop }
    readonly property bool live: shown && !lock.locked

    // ---- panel item ----
    // The readings the panel shows keep their feeds running while the popup
    // is closed, even for a section switched off in the popup.
    readonly property bool panelOn: !onDesktop && !lock.locked
    function panelNeeds(key) { return panelOn && panelReadings.keys.indexOf(key) >= 0 }
    PanelReadings {
        id: panelReadings
        sensor: root.cfg.panelDisplaySensor
        cycleSeconds: root.cfg.panelCycleInterval
        running: root.panelOn
        sections: root.sections
        tempUnit: root.cfg.tempUnit
        alerts: alertManager
        weatherFeed: weatherData
        systemFeed: systemData
        batteryFeed: powerData
        aiFeed: aiData
        timeEngine: clock
        clockSeconds: root.cfg.showSeconds
    }

    // ---- feeds ----
    TimeEngine {
        id: clock
        running: (root.has("clock") && root.live) || root.panelNeeds("clock")
        use24h: root.cfg.timeFormat24h
    }
    WeatherFeed {
        id: weatherData
        running: root.has("weather") || root.panelNeeds("weather")
        latitude: root.cfg.latitude
        longitude: root.cfg.longitude
        temperatureUnit: root.cfg.temperatureUnit
        windUnit: root.cfg.windSpeedUnit
        updateMinutes: root.cfg.updateIntervalMinutes
    }
    readonly property var systemSensors: cfg.visibleSensors.filter(k => k !== "fans").concat(cfg.showFanSpeeds ? ["fans"] : [])
    SystemFeed {
        id: systemData
        sensors: root.systemSensors
        interval: Math.max(500, root.cfg.systemUpdateInterval)
        live: root.live && (root.has("system") || root.previewing)
        panelKinds: root.panelOn ? panelReadings.keys : []
        gpuChoice: root.cfg.gpuDevice
        wantSpecs: root.cfg.showSystemSpecs
    }
    DiskFeed {
        id: diskData
        running: root.has("disk")
        fast: root.shown
        selected: root.cfg.selectedMountPoints
        hideRemovable: root.cfg.hideRemovableDisks
        showBoot: root.cfg.showBootPartitions
        threshold: root.cfg.warningThreshold
    }
    BatteryFeed {
        id: powerData
        running: root.has("battery") || root.panelNeeds("battery")
        selected: root.cfg.selectedBatteryDevices
        threshold: root.cfg.alertThreshold
        showEstimate: root.cfg.showChargingEstimate
        wantRate: root.cfg.showPowerRate
        live: root.live && (root.has("battery") || root.previewing)
    }
    AiFeed {
        id: aiData
        running: root.has("ai") || root.panelNeeds("aiUsage")
        live: root.live && (root.has("ai") || root.previewing)
        provider: root.cfg.aiProvider
        apiKey: root.cfg.aiApiKey
        endpoint: root.cfg.localAiEndpoint
        budget: root.cfg.aiMonthlyBudget
        pollMinutes: root.cfg.aiPollMinutes
        vramTotal: systemData.vramTotal
    }

    // ---- alerts ----
    // Every reading judged against the thresholds: the pills, cards, panel
    // item and its hover card all read their warning / critical levels here.
    AlertManager {
        id: alertManager
        enabled: root.cfg.tempColorAlerts
        animate: root.cfg.enablePulsingAnimations
        cpuTempWarn: root.cfg.cpuTempWarnThreshold
        cpuTempCrit: root.cfg.cpuTempCritThreshold
        gpuTempWarn: root.cfg.gpuTempWarnThreshold
        gpuTempCrit: root.cfg.gpuTempCritThreshold
        cpuLoadCrit: root.cfg.cpuLoadCritThreshold
        gpuLoadCrit: root.cfg.gpuLoadCritThreshold
        ramLoadCrit: root.cfg.ramLoadCritThreshold
        tempUnit: root.cfg.tempUnit
        system: systemData
        disk: root.has("disk") ? diskData : null
    }

    // The header names the place the forecast is for, or else this machine.
    property string hostName: ""
    P5Support.DataSource {
        engine: "executable"
        connectedSources: ["cat /proc/sys/kernel/hostname"]
        onNewData: (source, data) => { root.hostName = String(data["stdout"] || "").trim(); disconnectSource(source) }
    }

    // ---- process & service diagnostics ----
    // Opens the fullest monitor on hand, in this order: the Sub-Etha System
    // Monitor (a separate project, installed as subetha-monitor), KDE's
    // System Monitor, KSysGuard. With none installed, Discover opens on System
    // Monitor's page. The Sub-Etha monitor opens on `tab`, or, already open,
    // switches to it. Launched detached (setsid -f), so the shell returns at
    // once and the app outlives the widget.
    function launchCommand(tab) {
        return "m=$(command -v subetha-monitor || echo \"$HOME/.local/bin/subetha-monitor\");"
            + " if [ -x \"$m\" ]; then setsid -f \"$m\" --tab=" + tab + " >/dev/null 2>&1; echo subetha-monitor;"
            + " elif command -v plasma-systemmonitor >/dev/null; then setsid -f plasma-systemmonitor >/dev/null 2>&1; echo plasma-systemmonitor;"
            + " elif command -v ksysguard >/dev/null; then setsid -f ksysguard >/dev/null 2>&1; echo ksysguard;"
            + " else echo none; fi"
    }
    P5Support.DataSource {
        id: launcher
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source)
            if (String(data["stdout"]).trim() === "none") Qt.openUrlExternally("appstream://org.kde.plasma-systemmonitor")
        }
    }
    // tab: overview | sensors | processes | services | network | disks
    function openDiagnostics(tab) {
        var command = launchCommand(tab || "processes")
        if (launcher.connectedSources.indexOf(command) < 0) launcher.connectSource(command)
    }
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Open Sub-Etha Process Diagnostics")
            icon.name: "utilities-system-monitor"
            onTriggered: root.openDiagnostics("overview")
        }
    ]

    // ---- theme ----
    SkinEngine { id: skinEngine; activeSkin: root.cfg.activeSkin }
    // The skin and light / dark / auto, kept the same as the Sub-Etha System Monitor's.
    ThemeSync {
        skin: root.cfg.activeSkin
        mode: root.cfg.themeMode
        onReceived: (skin, mode) => {
            if (root.cfg.activeSkin !== skin) root.cfg.activeSkin = skin
            if (root.cfg.themeMode !== mode) root.cfg.themeMode = mode
        }
    }
    SubEthaTheme {
        id: guide
        mode: root.cfg.themeMode
        latitude: root.cfg.latitude
        longitude: root.cfg.longitude
        systemDark: { var c = Kirigami.Theme.backgroundColor; return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b < 0.5 }
        minimal: root.allCompact
        skin: skinEngine.style
        mood: root.anyCritical || systemData.cpuUsage > 85 ? "stressed" : "idle"
        live: root.live
        alertMotion: alertManager.animate
        meterA: Math.max(systemData.cpuUsage, systemData.gpuUsage) / 100
        meterB: Math.max(0, Math.min(1, (systemData.hottest - Sys.TEMP_MIN) / (Sys.TEMP_MAX - Sys.TEMP_MIN)))
    }
    onExpandedChanged: if (root.expanded) guide.refresh()

    readonly property bool anyCritical: (has("disk") && diskData.anyCritical) || (has("battery") && powerData.anyCritical)
                                      || (has("ai") && aiData.anyCritical)
                                      || (has("system") && (alertManager.cpu === 2 || alertManager.gpu === 2 || alertManager.ram === 2))

    // ---- representations ----
    preferredRepresentation: onDesktop ? fullRepresentation : compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground   // every section draws its own paper / CRT surface
    Plasmoid.status: anyCritical ? PlasmaCore.Types.NeedsAttentionStatus : PlasmaCore.Types.ActiveStatus
    hideOnWindowDeactivate: true
    // In a panel the themed hover card (PanelHoverPopup) replaces Plasma's tooltip.
    toolTipMainText: onDesktop ? i18n("The Sub-Etha Guide") : ""
    toolTipSubText: !onDesktop ? "" : [
        has("weather") && weatherData.hasData ? (root.cfg.locationName || "") + "  " + weatherData.tempText : "",
        systemData.cpuUsage > 0 || systemData.cpuTemp > 0
            ? i18n("CPU %1% · %2", Math.round(systemData.cpuUsage), Sys.temp(systemData.cpuTemp, root.cfg.tempUnit)) : "",
        systemData.hasGpu && systemData.gpuTemp > 0
            ? i18n("GPU %1% · %2", Math.round(systemData.gpuUsage), Sys.temp(systemData.gpuTemp, root.cfg.tempUnit)) : "",
        systemData.memTotal > 0 ? i18n("RAM %1 / %2", Sys.gb(systemData.memUsed), Sys.gb(systemData.memTotal)) : "",
        has("disk") && diskData.panelVolume ? i18n("Disk %1% used", diskData.panelVolume.usedPercentage) : "",
        has("battery") && powerData.panelDevice ? i18n("Battery %1%", powerData.panelDevice.percent) : "",
        has("ai") && aiData.status === "ok" ? (aiData.cloud ? i18n("AI %1 of %2 this month", "$" + aiData.spentMonth.toFixed(2), "$" + aiData.budget.toFixed(2))
                                                            : aiData.model ? i18n("AI %1 loaded", aiData.model) : "") : ""
    ].filter(s => s !== "").join("\n") || i18n("Don't Panic.")

    compactRepresentation: CompactRepresentation {
        dark: guide.dark
        readings: panelReadings.shown
        showIcon: root.cfg.showPanelIcon
        showMeter: root.cfg.showPanelMeter
        weather: weatherData.weather
        iconStyle: root.cfg.iconStyle
        vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        onClicked: mouse => { if (mouse.button === Qt.LeftButton) root.expanded = !root.expanded }
        onRefreshRequested: weatherData.refresh()
        theme: guide
        expanded: root.expanded
        alerts: alertManager
        offPanelCritical: panelReadings.offPanelCritical
        animate: alertManager.animate && root.panelOn
        popupLocation: Plasmoid.location
        preview: panelPreview
        onPreviewOpenChanged: root.previewing = previewOpen
    }

    // The panel hover card: the large card of each reading the panel item
    // shows (weather as the compact card when it shares the space).
    function systemKind(key) {
        return key === "gpuTemp" ? "gpu" : key === "ramUsage" ? "ram" : key === "netSpeed" ? "net" : "cpu"
    }
    Component {
        id: panelPreview
        Column {
            width: parent ? parent.width : 356
            spacing: 8
            Repeater {
                model: panelReadings.shownKeys
                Loader {
                    required property string modelData
                    width: parent.width
                    sourceComponent: modelData === "weather" ? weatherPreview
                                   : modelData === "clock" ? clockPreview
                                   : modelData === "battery" ? batteryPreview
                                   : modelData === "aiUsage" ? aiPreview : systemPreview
                    property string key: modelData
                }
            }
        }
    }
    Component {
        id: weatherPreview
        WeatherSection {
            width: parent ? parent.width : 356
            theme: guide
            feed: weatherData
            config: root.cfg
            minimal: panelReadings.shownKeys.length > 1
            live: root.previewing
            gap: 0
            toggleVisible: false
        }
    }
    Component {
        id: clockPreview
        ClockPanel {
            width: parent ? parent.width : 356
            theme: guide
            engine: clock
            showSeconds: root.cfg.showSeconds
            showDate: root.cfg.showDate
            showTzOffset: root.cfg.showTzOffset
            showGalactic: root.cfg.showGalacticSiderealTime
            live: root.previewing
        }
    }
    Component {
        id: systemPreview
        SystemPanel {
            width: parent ? parent.width : 356
            theme: guide
            telemetry: systemData
            sensors: [root.systemKind(parent ? parent.key : "cpuLoad")]
            tempUnit: root.cfg.tempUnit
            showFanPercent: root.cfg.showFanPercent
            fanMaxRpm: root.cfg.fanMaxRpm
            alerts: alertManager
            interval: systemData.interval
            showGraphs: true
            showSpecs: false
            sizes: ({ cpu: "large", ram: "large", gpu: "large", net: "large", fans: "large" })
            sizeTogglesShown: false
            bare: true
            live: root.previewing
        }
    }
    Component {
        id: batteryPreview
        BatteryPanel {
            width: parent ? parent.width : 356
            theme: guide
            feed: powerData
            percentageOnly: root.cfg.showPercentageOnly
            lowBlink: root.cfg.batteryBlink
            showPowerRate: root.cfg.showPowerRate
            live: root.previewing
        }
    }

    Component {
        id: aiPreview
        AiPanel {
            width: parent ? parent.width : 356
            theme: guide
            feed: aiData
            endpoint: root.cfg.localAiEndpoint
            live: root.previewing
        }
    }

    fullRepresentation: FullRepresentation {
        theme: guide
        desktop: root.onDesktop
        sections: root.sections
        subtitle: (root.has("weather") && root.cfg.locationName.trim() !== ""
                   ? root.cfg.locationName.trim().toUpperCase() : i18n("HOST %1", root.hostName.toUpperCase()))
        live: root.live && visible && Window.window !== null && Window.window.visible
        config: root.cfg
        timeEngine: clock
        weatherFeed: weatherData
        systemFeed: systemData
        systemSensors: root.systemSensors
        diskFeed: diskData
        batteryFeed: powerData
        aiFeed: aiData
        alerts: alertManager
        onLocationChosen: (name, latitude, longitude) => {
            root.cfg.locationName = name
            root.cfg.latitude = latitude
            root.cfg.longitude = longitude
        }
        onDensityChosen: (key, density) => root.cfg[key + "Density"] = density
        onSensorSizeChosen: (key, size) => root.cfg[key + "SensorSize"] = size
        onConfigureRequested: Plasmoid.internalAction("configure").trigger()
        onMonitorRequested: tab => root.openDiagnostics(tab)
    }
}
