import QtQuick
import QtQuick.Layouts
import "code/ai.js" as Ai
import "../common"

// The body of the AI section, without frame or header. Minimal: one pill,
// "CLAUDE: $4.20 / $20.00 (21%) · 1.9M ITPM FREE" (or the loaded local model,
// its VRAM and context) over a slim two-layer meter. Full: the skin's quip
// (or the Guide's), then a pill with the big budget or VRAM percentage, the
// meter and today / month / reset on the left, and the model badge with a
// 24-point sparkline of tokens per hour (VRAM for a local server) on the
// right. The meter's front layer is the budget spent or the VRAM taken; the
// faint layer behind it is the burn: the latest minute's share of the
// input rate limit, or the loaded models' full size against the VRAM.
ColumnLayout {
    id: panel

    property QtObject theme
    property QtObject feed                // an AiFeed
    property bool minimal: false
    property bool live: false
    property int entranceSerial: 0
    property string endpoint: ""

    readonly property bool cloud: feed ? feed.cloud : true
    readonly property bool ready: !!feed && (feed.status === "ok" || feed.updated !== null)
    readonly property real fraction: feed ? feed.fraction : 0
    readonly property real burn: !feed ? 0 : cloud ? (feed.inputLimit > 0 ? feed.lastMinuteInput / feed.inputLimit : 0)
                                : feed.vramTotal > 0 ? feed.loaded.reduce((s, m) => s + m.size, 0) / feed.vramTotal : 0
    readonly property color meterColor: fraction >= 0.85 ? theme.low : fraction >= 0.5 ? theme.mid : theme.high
    readonly property string percentText: Math.round(fraction * 100) + "%"

    // The month's reset counts down while on screen.
    property var now: new Date()
    Timer { interval: 60000; repeat: true; running: panel.live; onTriggered: panel.now = new Date() }
    onLiveChanged: if (live) now = new Date()
    readonly property string resetText: Ai.countdown(Ai.nextMonthStart(now).getTime() - now.getTime())

    readonly property string statusText: !feed ? ""
        : feed.status === "nokey" ? (feed.provider === "openwebui"
              ? i18n("ADD YOUR OPEN WEBUI API KEY UNDER AI TELEMETRY.")
              : i18n("ADD AN ADMIN API KEY UNDER AI TELEMETRY. THE COST REPORTS NEED ONE."))
        : feed.status === "denied" ? (cloud
              ? i18n("KEY REJECTED. THE COST AND USAGE REPORTS NEED AN ADMIN KEY, NOT A REGULAR ONE.")
              : i18n("KEY REJECTED BY %1.", panel.endpoint))
        : feed.status === "offline" ? (cloud ? i18n("NO SUB-ETHA SIGNAL. THE PROVIDER IS NOT ANSWERING.")
                                              : i18n("NO INFERENCE SERVER AT %1.", panel.endpoint))
        : feed.status === "error" ? i18n("REPORT FAILED (%1). TRYING AGAIN SHORTLY.", feed.errorText)
        : feed.status === "idle" ? i18n("ESTABLISHING SYNAPSE LINK…") : ""
    readonly property string quip: fraction >= 0.85 || !theme.aiQuip ? (feed ? feed.commentary : "") : theme.aiQuip

    readonly property string modelText: !feed ? "" : cloud ? Ai.modelLabel(feed.model) || i18n("NO TRAFFIC TODAY")
                                      : feed.topModel ? Ai.modelLabel(feed.topModel.name) : i18n("NO MODEL LOADED")
    readonly property string pillText: {
        if (!feed) return ""
        var head = Ai.providerShort(feed.provider) + ": "
        if (cloud) {
            var tail = feed.inputRemaining >= 0 ? i18n("%1 ITPM FREE", Ai.tokens(feed.inputRemaining))
                                                : i18n("%1 TOKENS TODAY", Ai.tokens(feed.tokensToday))
            return head + Ai.usd(feed.spentMonth) + " / " + Ai.usd(feed.budget) + " (" + percentText + ") · " + tail
        }
        if (!feed.topModel) return head + i18n("NO MODEL LOADED")
        return head + modelText + " · " + i18n("%1 VRAM", Ai.gb(feed.vramUsed))
             + (feed.topModel.context > 0 ? " · " + i18n("CTX %1", Ai.tokens(feed.topModel.context)) : "")
    }

    spacing: minimal ? 8 : 10

    Text {
        visible: !panel.minimal
        Layout.fillWidth: true
        text: panel.quip
        color: panel.theme.commentary
        font { family: panel.theme.mono; pixelSize: 12; bold: true }
        wrapMode: Text.WordWrap
    }
    Rectangle {
        visible: !panel.minimal
        Layout.fillWidth: true
        implicitHeight: 2
        color: panel.theme.dark ? panel.theme.tint(0.35) : panel.theme.ink
    }

    Text {   // setup and connection trouble
        visible: panel.statusText !== "" && (panel.feed.status !== "idle" || !panel.ready)
        Layout.fillWidth: true
        text: panel.statusText
        color: panel.feed && panel.feed.status === "idle" ? panel.theme.tint(0.6) : panel.theme.alert
        font { family: panel.theme.mono; pixelSize: 11; bold: true }
        wrapMode: Text.WordWrap
    }

    // A two-layer meter: the burn as a faint wash, the reading solid in front.
    component Meter: Item {
        id: meter
        property real value: 0
        property real wash: 0
        implicitHeight: 6
        ThemeShapeContainer {
            anchors.fill: parent
            theme: panel.theme
            role: "gauge"
            fillColor: panel.theme.gaugeTrack.a > 0 ? panel.theme.gaugeTrack : panel.theme.tint(panel.theme.dark ? 0.12 : 0.1)
            strokeWidth: 0
        }
        ThemeShapeContainer {
            visible: meter.wash > 0
            width: Math.max(height, parent.width * Math.min(1, meter.wash)); height: parent.height
            theme: panel.theme
            role: "gauge"
            fillColor: Qt.rgba(panel.meterColor.r, panel.meterColor.g, panel.meterColor.b, 0.3)
            strokeWidth: 0
        }
        ThemeShapeContainer {
            visible: meter.value > 0
            width: Math.max(height, parent.width * Math.min(1, meter.value)); height: parent.height
            theme: panel.theme
            role: "gauge"
            fillColor: panel.meterColor
            strokeWidth: 0
            Behavior on width { enabled: panel.live; NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }
    }

    // ---- minimal: one line over a slim meter ----
    SlidingPillContainer {
        visible: panel.minimal && panel.ready
        Layout.fillWidth: true
        theme: panel.theme
        live: panel.live
        entranceSerial: panel.entranceSerial
        critical: panel.feed && panel.feed.anyCritical
        verticalPadding: 7
        horizontalPadding: 12
        ColumnLayout {
            width: parent.width
            spacing: 5
            Text {
                Layout.fillWidth: true
                text: panel.pillText
                color: panel.theme.ink
                font { family: panel.theme.mono; pixelSize: 11; bold: true }
                elide: Text.ElideRight
            }
            Meter {
                Layout.fillWidth: true
                Layout.bottomMargin: 1
                implicitHeight: 3
                value: panel.fraction
                wash: panel.burn
            }
        }
    }

    // ---- full: meter on the left, model and sparkline on the right ----
    SlidingPillContainer {
        visible: !panel.minimal && panel.ready
        Layout.fillWidth: true
        theme: panel.theme
        live: panel.live
        entranceSerial: panel.entranceSerial
        critical: panel.feed && panel.feed.anyCritical
        RowLayout {
            width: parent.width
            spacing: 12

            ColumnLayout {   // left: the big percentage, the meter, the breakdown
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                spacing: 4
                RowLayout {
                    spacing: 6
                    Text {
                        text: panel.percentText
                        color: panel.fraction >= 0.85 ? panel.theme.alert : panel.theme.ink
                        font { family: panel.theme.mono; pixelSize: 26; bold: true }
                    }
                    Text {
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 5
                        text: !panel.feed ? "" : panel.cloud ? i18n("OF %1", Ai.usd(panel.feed.budget))
                            : panel.feed.vramTotal > 0 ? i18n("OF %1 VRAM", Ai.gb(panel.feed.vramTotal)) : i18n("VRAM")
                        color: panel.theme.tint(0.6)
                        font { family: panel.theme.mono; pixelSize: 10; bold: true }
                    }
                }
                Meter {
                    Layout.fillWidth: true
                    implicitHeight: 8
                    value: panel.fraction
                    wash: panel.burn
                }
                Text {
                    Layout.fillWidth: true
                    text: !panel.feed ? ""
                        : panel.cloud ? i18n("TODAY: %1 · MTD: %2 · RESET: IN %3", Ai.usd(panel.feed.spentToday),
                                             Ai.usd(panel.feed.spentMonth), panel.resetText)
                        : panel.feed.topModel ? i18n("MODEL %1 · IN VRAM %2", Ai.gb(panel.feed.topModel.size), Ai.gb(panel.feed.topModel.vram))
                                           + (isFinite(panel.feed.topModel.expires)
                                              ? " · " + i18n("UNLOADS IN %1", Ai.countdown(panel.feed.topModel.expires - panel.now.getTime())) : "")
                        : i18n("%1 MODELS IN MEMORY", 0)
                    color: panel.theme.tint(0.7)
                    font { family: panel.theme.mono; pixelSize: 9; bold: true }
                    wrapMode: Text.WordWrap
                }
            }

            ColumnLayout {   // right: the model, the sparkline, the rate
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                spacing: 4
                ThemeShapeContainer {   // model badge
                    Layout.maximumWidth: parent.width
                    implicitWidth: badgeText.implicitWidth + 14
                    implicitHeight: badgeText.implicitHeight + 6
                    theme: panel.theme
                    role: "pill"
                    // drawn like DON'T PANIC: outlined on the built-in terminal
                    fillColor: panel.theme.dark && !panel.theme.skinned ? "transparent" : panel.theme.badge
                    strokeColor: panel.theme.badge
                    strokeWidth: panel.theme.dark && !panel.theme.skinned ? 1.5 : 1
                    cornerBrackets: false
                    shadowType: "none"
                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, parent.width - 14)
                        text: (!panel.cloud && panel.feed && panel.feed.topModel ? i18nc("a local model", "LOCAL") + " " : "") + panel.modelText
                        color: panel.theme.badgeInk
                        font { family: panel.theme.mono; pixelSize: 9; bold: true; letterSpacing: 0.6 }
                        elide: Text.ElideRight
                    }
                }
                SparklineGraph {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    readonly property var raw: !panel.feed ? [] : panel.cloud ? panel.feed.tokenHistory : panel.feed.vramHistory
                    readonly property real peak: !panel.cloud && panel.feed && panel.feed.vramTotal > 0
                                                 ? panel.feed.vramTotal / 1073741824 : Math.max.apply(null, raw.concat([1]))
                    historyData: raw.map(v => v / peak)
                    capacity: 24
                    strokeColor: panel.theme.sparkline.a > 0 ? panel.theme.sparkline : panel.theme.cool
                    fillColor: panel.theme.sparkline.a > 0 && panel.theme.sparklineFill.a > 0 ? panel.theme.sparklineFill
                             : Qt.rgba(strokeColor.r, strokeColor.g, strokeColor.b, 0.18)
                    lineWidth: panel.theme.sparkline.a > 0 ? panel.theme.sparklineWidth : 1.5
                    stepped: panel.theme.sparklineStepped
                }
                Text {
                    Layout.fillWidth: true
                    text: !panel.feed ? ""
                        : panel.cloud ? i18n("%1 TOKENS TODAY", Ai.tokens(panel.feed.tokensToday))
                                        + (panel.feed.inputLimit > 0 ? " · " + i18n("ITPM %1 / %2", Ai.tokens(panel.feed.inputRemaining), Ai.tokens(panel.feed.inputLimit)) : "")
                        : panel.feed.topModel && panel.feed.topModel.context > 0 ? i18n("CONTEXT WINDOW %1 TOKENS", Ai.tokens(panel.feed.topModel.context))
                        : i18n("VRAM, LAST 2 MINUTES")
                    color: panel.theme.tint(0.7)
                    font { family: panel.theme.mono; pixelSize: 9; bold: true }
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
