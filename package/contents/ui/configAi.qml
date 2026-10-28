import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// "AI Telemetry": where the AI section reads from (a cloud provider's Admin
// API cost and usage reports, or a local inference server's loaded models),
// the key, the monthly budget and how often the reports are fetched.
KCM.SimpleKCM {
    id: page

    property string cfg_aiDensity
    property string cfg_aiDensityDefault
    property string cfg_aiProvider
    property string cfg_aiProviderDefault
    property alias cfg_aiApiKey: keyField.text
    property alias cfg_localAiEndpoint: endpointField.text
    property real cfg_aiMonthlyBudget
    property real cfg_aiMonthlyBudgetDefault
    property alias cfg_aiPollMinutes: pollSpin.value

    readonly property bool cloud: cfg_aiProvider === "anthropic" || cfg_aiProvider === "openai"

    readonly property var providers: [
        { value: "anthropic", text: i18n("Anthropic (Claude API)") },
        { value: "openai",    text: i18n("OpenAI") },
        { value: "ollama",    text: i18n("Ollama (local)") },
        { value: "openwebui", text: i18n("Open WebUI (local)") }
    ]

    Kirigami.FormLayout {
        DensityPicker {
            Kirigami.FormData.label: i18n("Section density:")
            density: page.cfg_aiDensity
            compactDescription: i18n("Compact: one pill with the month's spend against the budget (or the loaded model and its VRAM) over a slim meter.")
            fullDescription: i18n("Full: the big percentage, a two-layer meter, today / month / reset, the model badge, a 24-hour sparkline and the Guide's comment.")
            onPicked: density => page.cfg_aiDensity = density
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            text: i18n("Switch the AI section on or off under Appearance & Sections.")
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Source")
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Provider:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 14
            textRole: "text"
            valueRole: "value"
            model: page.providers
            currentIndex: Math.max(0, model.findIndex(m => m.value === page.cfg_aiProvider))
            onActivated: page.cfg_aiProvider = currentValue
        }
        Kirigami.PasswordField {
            id: keyField
            Kirigami.FormData.label: page.cloud ? i18n("Admin API key:") : i18n("API key:")
            visible: page.cfg_aiProvider !== "ollama"
            Layout.preferredWidth: Kirigami.Units.gridUnit * 18
            placeholderText: page.cfg_aiProvider === "anthropic" ? "sk-ant-admin01-…"
                           : page.cfg_aiProvider === "openai" ? "sk-admin-…" : ""
        }
        QQC2.Label {
            visible: page.cfg_aiProvider !== "ollama"
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            text: page.cfg_aiProvider === "anthropic"
                ? i18n("The cost and usage reports need an Admin API key, made by an organisation admin in the Claude Console (Settings > Admin keys). Regular API keys are refused, and individual accounts have no Admin API.")
                : page.cfg_aiProvider === "openai"
                ? i18n("The cost and usage reports need an Admin key from the OpenAI platform (Organization settings > Admin keys). Project keys are refused.")
                : i18n("Your Open WebUI API key (Settings > Account). It is sent only to the endpoint below.")
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
        Kirigami.InlineMessage {
            visible: page.cloud
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            Layout.fillWidth: true
            type: Kirigami.MessageType.Warning
            text: i18n("The key is stored unencrypted in Plasma's widget settings (~/.config/plasma-org.kde.plasma.desktop-appletsrc), and an Admin key can manage the whole organisation. Make one just for this widget, and revoke it if this account is shared.")
        }
        QQC2.TextField {
            id: endpointField
            Kirigami.FormData.label: i18n("Endpoint:")
            visible: !page.cloud
            Layout.preferredWidth: Kirigami.Units.gridUnit * 18
            placeholderText: "http://localhost:11434"
        }
        QQC2.Label {
            visible: !page.cloud
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            text: page.cfg_aiProvider === "openwebui"
                ? i18n("Open WebUI's address, such as http://localhost:3000. The widget asks its Ollama proxy which models are loaded.")
                : i18n("Ollama's address. The widget asks which models are loaded (/api/ps): their size, the share in VRAM and the context window. Ollama doesn't report generation speed there.")
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }

        Kirigami.Separator {
            visible: page.cloud
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Budget")
        }
        QQC2.SpinBox {
            visible: page.cloud
            Kirigami.FormData.label: i18n("Monthly budget:")
            from: 1
            to: 100000
            stepSize: 5
            editable: true
            value: Math.round(page.cfg_aiMonthlyBudget)
            textFromValue: (v, locale) => "$" + v
            valueFromText: (text, locale) => parseInt(text.replace(/[^0-9]/g, "")) || 1
            onValueModified: page.cfg_aiMonthlyBudget = value
        }
        QQC2.SpinBox {
            id: pollSpin
            visible: page.cloud
            Kirigami.FormData.label: i18n("Fetch reports every:")
            from: 1
            to: 60
            textFromValue: (v, locale) => i18np("%1 minute", "%1 minutes", v)
            valueFromText: (text, locale) => parseInt(text) || 5
        }
        QQC2.Label {
            visible: page.cloud
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            text: i18n("The month runs in UTC, like the provider's billing. Reports trail live traffic by about five minutes.")
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
    }
}
