.pragma library
.import "../../common/i18n.js" as T

// Translated strings go through common/i18n.js (see there).
function i18n() { return T.tr("i18n", Array.prototype.slice.call(arguments)) }
function i18nc() { return T.tr("i18nc", Array.prototype.slice.call(arguments)) }

// Parsing and formatting for the AI section: the Anthropic and OpenAI Admin
// API cost and usage reports, Ollama's /api/ps, and the money, token and
// countdown readouts. Pure functions; AiFeed does the requests.

function num(v) { var n = Number(v); return isFinite(n) ? n : 0 }

// Midnight UTC on the first of this month, and of the next (when budgets and
// the API's spend caps reset).
function monthStart(now) { return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)) }
function nextMonthStart(now) { return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1)) }
function dayStart(now) { return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate())) }
// RFC 3339 without milliseconds, floored to the minute or hour.
function iso(d) { return d.toISOString().replace(/\.\d{3}Z$/, "Z") }
function floorTo(d, ms) { return new Date(Math.floor(d.getTime() / ms) * ms) }

// ---- Anthropic (api.anthropic.com/v1/organizations/...) ----

// Tokens in one usage_report result: every input kind plus output.
function anthropicTokens(r) {
    var cc = r.cache_creation || {}
    return num(r.uncached_input_tokens) + num(r.cache_read_input_tokens) + num(r.output_tokens)
         + num(cc.ephemeral_5m_input_tokens) + num(cc.ephemeral_1h_input_tokens)
}
// The input tokens that count toward ITPM (cache reads don't).
function anthropicRateInput(r) {
    var cc = r.cache_creation || {}
    return num(r.uncached_input_tokens) + num(cc.ephemeral_5m_input_tokens) + num(cc.ephemeral_1h_input_tokens)
}
// cost_report buckets (oldest first) -> { month, today } in USD. Amounts are
// decimal strings in cents.
function anthropicCost(data, now) {
    var today = dayStart(now).getTime(), month = 0, day = 0
    ;(data || []).forEach(b => {
        var cents = (b.results || []).reduce((s, r) => s + num(r.amount), 0)
        month += cents
        if (Date.parse(b.starting_at) >= today) day += cents
    })
    return { month: month / 100, today: day / 100 }
}

// ---- OpenAI (api.openai.com/v1/organization/...) ----

function openaiCost(data, now) {
    var today = dayStart(now).getTime() / 1000, month = 0, day = 0
    ;(data || []).forEach(b => {
        var usd = (b.results || []).reduce((s, r) => s + num(r.amount ? r.amount.value : 0), 0)
        month += usd
        if (num(b.start_time) >= today) day += usd
    })
    return { month: month, today: day }
}
function openaiTokens(r) { return num(r.input_tokens) + num(r.output_tokens) }

// Hourly usage buckets -> { history: tokens per hour (oldest first), total,
// model: the one with the most tokens }.
function hourly(data, tokensOf, now) {
    var history = [], perModel = {}, total = 0, today = dayStart(now).getTime()
    ;(data || []).forEach(b => {
        var sum = 0
        ;(b.results || []).forEach(r => {
            var t = tokensOf(r)
            sum += t
            if (r.model) perModel[r.model] = (perModel[r.model] || 0) + t
        })
        history.push(sum)
        var start = b.starting_at ? Date.parse(b.starting_at) : num(b.start_time) * 1000
        if (start >= today) total += sum
    })
    var model = Object.keys(perModel).sort((a, b) => perModel[b] - perModel[a])[0] || ""
    return { history: history, today: total, model: model }
}

// ---- Ollama / Open WebUI (/api/ps) ----

// The loaded models, largest VRAM share first: { name, vram, size, context, expires }.
function loadedModels(json) {
    return ((json && json.models) || []).map(m => ({
        name: String(m.name || m.model || ""),
        vram: num(m.size_vram),
        size: num(m.size),
        context: num(m.context_length),
        expires: m.expires_at ? Date.parse(m.expires_at) : NaN
    })).sort((a, b) => b.vram - a.vram)
}

// ---- readouts ----

function usd(v) {
    v = num(v)
    return "$" + (v >= 1000 ? String(Math.round(v)).replace(/\B(?=(\d{3})+(?!\d))/g, ",") : v.toFixed(2))
}
// 128400 -> "128k", 2.5e6 -> "2.5M"
function tokens(v) {
    v = num(v)
    return v >= 1e9 ? (v / 1e9).toFixed(1) + "B" : v >= 1e6 ? (v / 1e6).toFixed(1) + "M"
         : v >= 1e3 ? Math.round(v / 1e3) + "k" : String(Math.round(v))
}
function gb(bytes) { return (num(bytes) / 1073741824).toFixed(1) + " GB" }

// Milliseconds -> "4D 12H", "3H 20M", "45M"
function countdown(ms) {
    var m = Math.max(0, Math.round(ms / 60000)), d = Math.floor(m / 1440), h = Math.floor(m % 1440 / 60)
    return d > 0 ? i18nc("days and hours", "%1D %2H", d, h) : h > 0 ? i18nc("hours and minutes", "%1H %2M", h, m % 60)
         : i18nc("minutes", "%1M", m)
}

// "claude-opus-5-5" -> "CLAUDE OPUS 5.5", "qwen2.5-coder:32b" -> "QWEN2.5-CODER:32B"
function modelLabel(id) {
    if (!id) return ""
    var s = String(id)
    var claude = s.match(/^claude-([a-z]+)-(\d+)(?:-(\d))?(?:-\d{8})?$/)
    if (claude) return ("claude " + claude[1] + " " + claude[2] + (claude[3] ? "." + claude[3] : "")).toUpperCase()
    return s.toUpperCase()
}

function providerTag(provider) {
    return provider === "anthropic" ? "ANTHROPIC" : provider === "openai" ? "OPENAI"
         : provider === "openwebui" ? "OPEN WEBUI" : "OLLAMA"
}
// The short name in the compact pill: CLAUDE, OPENAI, OLLAMA, WEBUI.
function providerShort(provider) {
    return provider === "anthropic" ? "CLAUDE" : provider === "openai" ? "OPENAI"
         : provider === "openwebui" ? "WEBUI" : "OLLAMA"
}

// The Guide's own line, by how hard the meter is pushed.
function commentary(fraction, local, busy) {
    if (fraction >= 1) return i18n("BUDGET EXCEEDED. THE BUGBLATTER BEAST OF TRAAL HAS EATEN YOUR CREDITS.")
    if (fraction >= 0.85) return i18n("CREDITS RUNNING LOW. DON'T PANIC. PANIC SLIGHTLY.")
    if (local && !busy) return i18n("NO MODEL IN MEMORY. DEEP THOUGHT IS TAKING A TEA BREAK.")
    return i18n("DEEP THOUGHT CURRENTLY COMPUTING THE ULTIMATE QUESTION.")
}
