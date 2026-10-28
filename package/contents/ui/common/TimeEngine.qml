import QtQuick

// The one clock every time view reads: a single 500 ms timer (only while
// `running`) that republishes the fields below when the second changes, so
// the clock pill, the large chronometer and the panel item never run timers
// of their own. Names of days and months come from the system locale; the
// zone abbreviation, offset and name from Qt's time zone data.
QtObject {
    id: engine

    property bool running: false
    property bool use24h: true

    property var now: new Date()
    readonly property int hour: now.getHours()
    readonly property int minute: now.getMinutes()
    readonly property int second: now.getSeconds()

    function pad(n) { return n < 10 ? "0" + n : String(n) }
    // Padded strings; in 12-hour mode `hours` runs 12, 01 .. 11 and `meridiem` says AM / PM.
    readonly property string hours: pad(use24h ? hour : (hour % 12 || 12))
    readonly property string minutes: pad(minute)
    readonly property string seconds: pad(second)
    readonly property string meridiem: use24h ? "" : (hour < 12 ? Qt.locale().amText : Qt.locale().pmText).toUpperCase()

    // WEDNESDAY, 28 OCT 2026 / WED, 28 OCT 2026 / WEDNESDAY · 28 OCTOBER 2026
    function dayName(format) { return Qt.locale().dayName(now.getDay(), format).toUpperCase().replace(/\.$/, "") }
    function monthName(format) { return Qt.locale().monthName(now.getMonth(), format).toUpperCase().replace(/\.$/, "") }
    readonly property string dateString: dayName(Locale.LongFormat) + ", " + now.getDate() + " "
                                         + monthName(Locale.ShortFormat) + " " + now.getFullYear()
    readonly property string shortDate: dayName(Locale.ShortFormat) + ", " + now.getDate() + " "
                                        + monthName(Locale.ShortFormat) + " " + now.getFullYear()
    readonly property string longDate: dayName(Locale.LongFormat) + " · " + now.getDate() + " "
                                       + monthName(Locale.LongFormat) + " " + now.getFullYear()
    readonly property string isoDate: now.getFullYear() + "-" + pad(now.getMonth() + 1) + "-" + pad(now.getDate())

    readonly property string tzAbbreviation: Qt.formatDateTime(now, "t")        // CET
    readonly property string tzName: Qt.formatDateTime(now, "tttt").toUpperCase()  // CENTRAL EUROPEAN STANDARD TIME
    readonly property string utcOffset: "UTC" + Qt.formatDateTime(now, "ttt")    // UTC+01:00
    readonly property string tzOffset: utcOffset + " / " + tzAbbreviation        // UTC+01:00 / CET

    readonly property int dayOfYear: Math.round((new Date(now.getFullYear(), now.getMonth(), now.getDate())
                                                 - new Date(now.getFullYear(), 0, 1)) / 86400000) + 1
    // ISO 8601: the week holding the year's first Thursday is week 1.
    readonly property int weekNumber: {
        var d = new Date(Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()))
        d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7))
        return Math.ceil(((d - Date.UTC(d.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7)
    }

    // Lore: the Guide's epoch is 42, and the stardate is the month and day after it.
    readonly property string galacticStandardTime: "42." + pad(now.getMonth() + 1) + pad(now.getDate())
    // Real Greenwich mean sidereal time, HH:MM, from days since J2000.0.
    readonly property string siderealTime: {
        var days = (now.getTime() - Date.UTC(2000, 0, 1, 12)) / 86400000
        var h = ((18.697374558 + 24.06570982441908 * days) % 24 + 24) % 24
        return pad(Math.floor(h)) + ":" + pad(Math.floor(h * 60) % 60)
    }

    // 0..1 through the minute and through the day, for the dials.
    readonly property real secondFraction: second / 60
    readonly property real dayFraction: (hour * 3600 + minute * 60 + second) / 86400

    // The time of day as the Guide sees it.
    readonly property string commentary: hour >= 5 && hour < 12 ? i18n("LOCAL STAR ASCENDING. TEA EXTRACTION RECOMMENDED.")
                                       : hour >= 12 && hour < 18 ? i18n("SOLAR ZENITH. TOWEL PLACEMENT NOMINAL.")
                                       : hour >= 18 && hour < 23 ? i18n("PLANETARY ROTATION COOLING. MOSTLY HARMLESS.")
                                       : i18n("DARK HOURS DETECTED. TIME IS AN ILLUSION. LUNCHTIME DOUBLY SO.")

    function tick() {
        var d = new Date()
        if (Math.floor(d.getTime() / 1000) !== Math.floor(now.getTime() / 1000)) now = d
    }
    onRunningChanged: if (running) tick()
    property Timer timer: Timer {
        interval: 500
        repeat: true
        running: engine.running
        triggeredOnStart: true
        onTriggered: engine.tick()
    }
}
