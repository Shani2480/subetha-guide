.pragma library

// Sunrise and sunset for a latitude/longitude, from the sunrise equation
// (NOAA's simplified solar position, good to a minute or two). Used by the
// "auto" theme mode: the cream movie pages by day, the CRT terminal by night.

var RAD = Math.PI / 180

function julian(date) { return date.getTime() / 86400000 + 2440587.5 }
function fromJulian(j) { return new Date((j - 2440587.5) * 86400000) }

// { rise: Date, set: Date } for the local calendar day of `date`, or
// { polar: "day" | "night" } when the sun does not cross the horizon.
function sunTimes(date, lat, lon) {
    var noon = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 12)
    var n = Math.round(julian(noon) - 2451545.0009 + lon / 360)
    var jStar = 2451545.0009 - lon / 360 + n
    var m = (357.5291 + 0.98560028 * (jStar - 2451545)) % 360
    var c = 1.9148 * Math.sin(m * RAD) + 0.02 * Math.sin(2 * m * RAD) + 0.0003 * Math.sin(3 * m * RAD)
    var lambda = (m + c + 180 + 102.9372) % 360
    var transit = jStar + 0.0053 * Math.sin(m * RAD) - 0.0069 * Math.sin(2 * lambda * RAD)
    var decl = Math.asin(Math.sin(lambda * RAD) * Math.sin(23.44 * RAD))
    var cosH = (Math.sin(-0.83 * RAD) - Math.sin(lat * RAD) * Math.sin(decl))
             / (Math.cos(lat * RAD) * Math.cos(decl))
    if (cosH < -1) return { polar: "day" }
    if (cosH > 1) return { polar: "night" }
    var h = Math.acos(cosH) / RAD / 360
    return { rise: fromJulian(transit - h), set: fromJulian(transit + h) }
}

// { day: bool, next: Date } — whether the sun is up at `now`, and when that
// next changes. During a polar day or night `next` is six hours out, so the
// widget simply checks again.
function daylight(now, lat, lon) {
    var today = sunTimes(now, lat, lon)
    if (today.polar)
        return { day: today.polar === "day", next: new Date(now.getTime() + 6 * 3600000) }
    if (now < today.rise) return { day: false, next: today.rise }
    if (now < today.set) return { day: true, next: today.set }
    var tomorrow = sunTimes(new Date(now.getTime() + 86400000), lat, lon)
    return { day: false, next: tomorrow.polar ? new Date(now.getTime() + 6 * 3600000) : tomorrow.rise }
}
