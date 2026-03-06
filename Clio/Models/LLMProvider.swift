import Foundation

enum LLMProvider: String, Codable, CaseIterable, Identifiable {
    case openai
    case claude
    case gemini
    case grok
    case ollama

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: "OpenAI"
        case .claude: "Claude"
        case .gemini: "Gemini"
        case .grok: "Grok"
        case .ollama: "Ollama"
        }
    }

    var companyName: String {
        switch self {
        case .openai: "OpenAI (ChatGPT)"
        case .claude: "Anthropic (Claude)"
        case .gemini: "Google (Gemini)"
        case .grok: "xAI (Grok)"
        case .ollama: "Local (Ollama)"
        }
    }

    var iconName: String {
        switch self {
        case .openai: "brain"
        case .claude: "sparkle"
        case .gemini: "wand.and.stars"
        case .grok: "bolt.fill"
        case .ollama: "desktopcomputer"
        }
    }

    var keychainKey: String {
        rawValue
    }

    var requiresAPIKey: Bool {
        self != .ollama
    }

    var apiKeyPlaceholder: String {
        switch self {
        case .openai: "sk-..."
        case .claude: "sk-ant-..."
        case .gemini: "AIza..."
        case .grok: "xai-..."
        case .ollama: ""
        }
    }

    var getKeyURL: URL? {
        switch self {
        case .openai: URL(string: "https://platform.openai.com/api-keys")
        case .claude: URL(string: "https://console.anthropic.com/settings/keys")
        case .gemini: URL(string: "https://aistudio.google.com/apikey")
        case .grok: URL(string: "https://console.x.ai")
        case .ollama: nil
        }
    }
}
