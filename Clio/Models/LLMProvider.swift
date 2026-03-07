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

    var setupSteps: [String] {
        switch self {
        case .openai:
            [
                "Click the link below to open OpenAI's API key page",
                "Sign in or create a free account",
                "Click \"Create new secret key\"",
                "Copy the key and paste it here"
            ]
        case .claude:
            [
                "Click the link below to open Anthropic's console",
                "Sign in or create a free account",
                "Click \"Create Key\"",
                "Copy the key and paste it here"
            ]
        case .gemini:
            [
                "Click the link below to open Google AI Studio",
                "Sign in with your Google account",
                "Click \"Create API Key\"",
                "Copy the key and paste it here"
            ]
        case .grok:
            [
                "Click the link below to open the xAI console",
                "Sign in or create an account",
                "Generate a new API key",
                "Copy the key and paste it here"
            ]
        case .ollama:
            [
                "Download Ollama from ollama.com",
                "Open Ollama — it runs in your menu bar",
                "Run: ollama pull llama3.2",
                "That's it! No API key needed"
            ]
        }
    }

    var signupURL: URL? {
        switch self {
        case .openai: URL(string: "https://platform.openai.com/signup")
        case .claude: URL(string: "https://console.anthropic.com/")
        case .gemini: URL(string: "https://aistudio.google.com/")
        case .grok: URL(string: "https://console.x.ai/")
        case .ollama: URL(string: "https://ollama.com/download")
        }
    }

    var getLinkLabel: String {
        switch self {
        case .openai: "Open OpenAI API Keys"
        case .claude: "Open Anthropic Console"
        case .gemini: "Open Google AI Studio"
        case .grok: "Open xAI Console"
        case .ollama: "Download Ollama"
        }
    }
}
