import QtQuick
import "code/ai.js" as Ai

// The data behind the AI section. Cloud providers (anthropic, openai) are
// read from their Admin API reports every `pollMinutes`: month-to-date and
// today's spend from the cost report, tokens per hour over the last day
// from the usage report, and for Anthropic the busiest model's configured
// rate limits against its latest minute of input. The reports lag a few
// minutes behind real traffic. Local servers (ollama, openwebui) are asked
// which models are loaded (/api/ps) every 5 s while shown, every 30 s for
// the panel. Requests go out only while `running`; the key is sent to the
// provider's own host, or to `endpoint` for Open WebUI.
Item {
    id: feed

    property bool running: false
    property bool live: false             // on screen: local servers poll fast
    property string provider: "anthropic" // anthropic | openai | ollama | openwebui
    property string apiKey: ""
    property string endpoint: "http://localhost:11434"
    property real budget: 20              // USD a month
    property int pollMinutes: 5
    property real vramTotal: 0            // the GPU's VRAM in bytes (SystemFeed), the local meter's scale

    readonly property bool cloud: provider === "anthropic" || provider === "openai"
    readonly property bool needsKey: cloud || provider === "openwebui"

    // "idle" (nothing fetched yet), "ok", "nokey", "denied" (key rejected),
    // "offline" (no answer), "error"
    property string status: "idle"
    property string errorText: ""
    property var updated: null            // Date of the last good answer

    // cloud
    property real spentMonth: 0           // USD, this calendar month (UTC)
    property real spentToday: 0
    property real tokensToday: 0
    property var tokenHistory: []         // tokens per hour, oldest first (24)
    property string model: ""             // the most-used model of the last day, or the loaded one
    property real inputLimit: 0           // ITPM of that model's rate limit group, 0: unknown
    property real requestLimit: 0         // RPM
    property real lastMinuteInput: 0      // input tokens counted toward ITPM in the latest minute reported
    readonly property real inputRemaining: inputLimit > 0 ? Math.max(0, inputLimit - lastMinuteInput) : -1
    readonly property real budgetFraction: budget > 0 ? spentMonth / budget : 0

    // local
    property var loaded: []               // [{ name, vram, size, context, expires }], largest first
    property var vramHistory: []          // GB in VRAM, oldest first (24)
    readonly property var topModel: loaded.length ? loaded[0] : null
    readonly property real vramUsed: loaded.reduce((s, m) => s + m.vram, 0)
    readonly property real vramFraction: vramTotal > 0 ? vramUsed / vramTotal : 0

    // The meter: budget spent, or the GPU's VRAM taken by models.
    readonly property real fraction: cloud ? budgetFraction : vramFraction
    readonly property bool anyCritical: cloud && status === "ok" && budgetFraction >= 1
    readonly property string commentary: Ai.commentary(fraction, !cloud, loaded.length > 0)

    readonly property string anthropicBase: "https://api.anthropic.com/v1/organizations/"
    readonly property string openaiBase: "https://api.openai.com/v1/organization/"
    readonly property string localBase: endpoint.replace(/\/+$/, "") + (provider === "openwebui" ? "/ollama" : "")

    function request(url, headers, done) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 0) { done(null, "offline"); return }
            if (xhr.status === 401 || xhr.status === 403) { done(null, "denied"); return }
            if (xhr.status < 200 || xhr.status >= 300) { done(null, "error", xhr.status); return }
            try { done(JSON.parse(xhr.responseText), "ok") } catch (e) { done(null, "error", "JSON") }
        }
        xhr.open("GET", url)
        for (var k in headers) xhr.setRequestHeader(k, headers[k])
        xhr.send()
    }
    function fail(kind, detail) {
        feed.status = kind
        feed.errorText = kind === "error" ? String(detail || "") : ""
    }
    function succeed() { feed.status = "ok"; feed.errorText = ""; feed.updated = new Date() }

    function refresh() {
        if (!feed.running) return
        if (feed.needsKey && feed.apiKey.trim() === "") { fail("nokey"); return }
        if (feed.provider === "anthropic") fetchAnthropic()
        else if (feed.provider === "openai") fetchOpenai()
        else fetchLocal()
    }

    function fetchAnthropic() {
        var h = { "x-api-key": feed.apiKey.trim(), "anthropic-version": "2023-06-01" }
        var now = new Date()
        request(anthropicBase + "cost_report?bucket_width=1d&limit=31&starting_at=" + Ai.iso(Ai.monthStart(now)), h,
            (json, kind, detail) => {
                if (!json) { fail(kind, detail); return }
                var c = Ai.anthropicCost(json.data, now)
                feed.spentMonth = c.month; feed.spentToday = c.today
                succeed()
            })
        var hourStart = Ai.floorTo(new Date(now.getTime() - 23 * 3600000), 3600000)
        request(anthropicBase + "usage_report/messages?bucket_width=1h&limit=24&group_by[]=model&starting_at=" + Ai.iso(hourStart), h,
            (json, kind) => {
                if (!json) return
                var u = Ai.hourly(json.data, Ai.anthropicTokens, now)
                feed.tokenHistory = u.history; feed.tokensToday = u.today
                if (u.model !== feed.model) { feed.model = u.model; feed.inputLimit = 0; feed.requestLimit = 0 }
                if (feed.model) fetchAnthropicLimits(h)
            })
        // The latest minute reported, for the ITPM headroom.
        var minuteStart = Ai.floorTo(new Date(now.getTime() - 10 * 60000), 60000)
        request(anthropicBase + "usage_report/messages?bucket_width=1m&limit=10&starting_at=" + Ai.iso(minuteStart), h,
            (json, kind) => {
                if (!json) return
                var buckets = (json.data || []).filter(b => (b.results || []).length)
                var last = buckets.length ? buckets[buckets.length - 1] : null
                feed.lastMinuteInput = last ? last.results.reduce((s, r) => s + Ai.anthropicRateInput(r), 0) : 0
            })
    }
    function fetchAnthropicLimits(h) {
        request(anthropicBase + "rate_limits?model=" + encodeURIComponent(feed.model), h, (json, kind) => {
            if (!json) return
            var entry = (json.data || [])[0]
            var limits = entry ? entry.limits || [] : []
            var of = type => { var l = limits.find(l => l.type === type); return l ? Ai.num(l.value) : 0 }
            feed.inputLimit = of("input_tokens_per_minute")
            feed.requestLimit = of("requests_per_minute")
        })
    }

    function fetchOpenai() {
        var h = { "Authorization": "Bearer " + feed.apiKey.trim() }
        var now = new Date()
        var monthUnix = Math.floor(Ai.monthStart(now).getTime() / 1000)
        request(openaiBase + "costs?bucket_width=1d&limit=31&start_time=" + monthUnix, h, (json, kind, detail) => {
            if (!json) { fail(kind, detail); return }
            var c = Ai.openaiCost(json.data, now)
            feed.spentMonth = c.month; feed.spentToday = c.today
            succeed()
        })
        var hourUnix = Math.floor(Ai.floorTo(new Date(now.getTime() - 23 * 3600000), 3600000).getTime() / 1000)
        request(openaiBase + "usage/completions?bucket_width=1h&limit=24&group_by=model&start_time=" + hourUnix, h, (json, kind) => {
            if (!json) return
            var u = Ai.hourly(json.data, Ai.openaiTokens, now)
            feed.tokenHistory = u.history; feed.tokensToday = u.today; feed.model = u.model
        })
        feed.inputLimit = 0; feed.requestLimit = 0      // not readable organisation-wide
    }

    function fetchLocal() {
        var h = feed.provider === "openwebui" && feed.apiKey.trim() !== "" ? { "Authorization": "Bearer " + feed.apiKey.trim() } : {}
        request(localBase + "/api/ps", h, (json, kind, detail) => {
            if (!json) { fail(kind, detail); feed.loaded = []; return }
            feed.loaded = Ai.loadedModels(json)
            feed.model = feed.topModel ? feed.topModel.name : ""
            feed.vramHistory = feed.vramHistory.concat([feed.vramUsed / 1073741824]).slice(-24)
            succeed()
        })
    }

    // A change of provider, key or endpoint starts over.
    function reset() {
        feed.status = "idle"; feed.errorText = ""; feed.updated = null
        feed.spentMonth = 0; feed.spentToday = 0; feed.tokensToday = 0; feed.tokenHistory = []; feed.model = ""
        feed.inputLimit = 0; feed.requestLimit = 0; feed.lastMinuteInput = 0; feed.loaded = []; feed.vramHistory = []
        Qt.callLater(refresh)
    }
    onProviderChanged: reset()
    onApiKeyChanged: reset()
    onEndpointChanged: reset()
    onRunningChanged: if (feed.running) Qt.callLater(refresh)

    Timer {
        interval: feed.cloud ? Math.max(1, feed.pollMinutes) * 60000 : feed.live ? 5000 : 30000
        repeat: true
        running: feed.running
        onTriggered: feed.refresh()
    }
}
