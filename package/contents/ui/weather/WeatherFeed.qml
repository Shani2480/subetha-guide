import QtQuick
import "code/weather.js" as Weather

// The forecast behind the weather views: Open-Meteo for the configured spot,
// refreshed every `updateMinutes` (retried a minute after a failure), plus
// the icon's "attention" pulse: a few seconds every 5 minutes, and whenever
// the condition category changes. Nothing fetches unless `running`.
Item {
    id: feed

    property bool running: true
    property real latitude: 0
    property real longitude: 0
    property string temperatureUnit: "celsius"
    property string windUnit: "kmh"
    property int updateMinutes: 30

    property var weather: null              // parsed Open-Meteo data, see code/weather.js
    property string errorText: ""
    property bool pulsing: false
    property string lastCondition: ""
    property int conditionChangeSerial: 0   // bumped when the category changes; the panel pulses on it

    readonly property bool hasData: weather !== null
    readonly property string tempText: hasData ? Math.round(weather.current.temp) + "°" : "--°"
    readonly property int currentFeelsLike: hasData ? Math.round(weather.current.feelsLike) : 0

    function refresh() {
        Weather.fetchWeather(latitude, longitude, { temperature: temperatureUnit, wind: windUnit },
            function (data) {
                var condition = data.current.condition
                // Pulse only on a category change, not on the first fetch after login.
                if (feed.lastCondition !== "" && condition !== feed.lastCondition) {
                    feed.conditionChangeSerial++
                    feed.pulsing = true
                    pulseStop.restart()
                }
                feed.lastCondition = condition
                feed.weather = data
                feed.errorText = ""
            },
            function (err) {
                feed.errorText = i18n("Weather unavailable (%1)", err)
                retryTimer.restart()
            })
    }

    // Coalesce the two coordinate changes of a location pick into one fetch.
    Timer { id: debounce; interval: 100; onTriggered: if (feed.running) feed.refresh() }
    onLatitudeChanged: debounce.restart()
    onLongitudeChanged: debounce.restart()
    onTemperatureUnitChanged: debounce.restart()
    onWindUnitChanged: debounce.restart()
    onRunningChanged: if (running && !hasData) debounce.restart()

    Timer {
        interval: Math.max(1, feed.updateMinutes) * 60 * 1000
        running: feed.running
        repeat: true
        triggeredOnStart: true
        onTriggered: feed.refresh()
    }
    Timer { id: retryTimer; interval: 60 * 1000; onTriggered: if (feed.running) feed.refresh() }

    // Play the icon animation for a few seconds every 5 minutes.
    Timer {
        interval: 5 * 60 * 1000
        running: feed.running
        repeat: true
        onTriggered: { feed.pulsing = true; pulseStop.restart() }
    }
    Timer { id: pulseStop; interval: 8000; onTriggered: feed.pulsing = false }
}
