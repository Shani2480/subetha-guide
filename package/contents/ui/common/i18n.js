.pragma library

// Translation for the .pragma library helpers (weather.js, system.js,
// disk.js, power.js). A library has no QML context, so KDE's i18n() is out
// of reach there; main.qml hands over a translator once at start-up
// (install) and the helpers' own i18n / i18nc / i18np shims forward to it.
// Until then, or where nothing installed one, the English text comes back
// with its %1..%n filled in.

var translator = null      // function (kind, args) -> string, kind: "i18n" | "i18nc" | "i18np"

function install(fn) { translator = fn; return true }

function fill(text, args) {
    return String(text).replace(/%(\d+)/g, function (m, n) {
        var v = args[Number(n) - 1]
        return v === undefined ? m : String(v)
    })
}

function tr(kind, args) {
    if (translator) return translator(kind, args)
    if (kind === "i18nc") return fill(args[1], args.slice(2))
    if (kind === "i18np") return fill(Number(args[2]) === 1 ? args[0] : args[1], args.slice(2))
    return fill(args[0], args.slice(1))
}
