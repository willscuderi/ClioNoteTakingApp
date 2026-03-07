import Foundation

enum LLMModelTier: String, Codable {
    case fast
    case balanced
    case best

    var label: String {
        switch self {
        case .fast: "Fast"
        case .balanced: "Balanced"
        case .best: "Best Quality"
        }
    }

    var description: String {
        switch self {
        case .fast: "Quickest response, lower cost"
        case .balanced: "Good quality at reasonable speed"
        case .best: "Highest quality, slower and more expensive"
        }
    }
}

struct LLMModel: Identifiable, Hashable, Codable {
    let id: String          // API model ID, e.g. "claude-sonnet-4-6"
    let displayName: String // e.g. "Sonnet 4.6"
    let provider: LLMProvider
    let tier: LLMModelTier

    var tierLabel: String {
        "(\(tier.label))"
    }
}

extension LLMProvider {
    /// Available models for this provider, ordered fast -> balanced -> best.
    var availableModels: [LLMModel] {
        switch self {
        case .openai:
            [
                LLMModel(id: "gpt-4o-mini", displayName: "GPT-4o Mini", provider: .openai, tier: .fast),
                LLMModel(id: "gpt-4o", displayName: "GPT-4o", provider: .openai, tier: .balanced),
                LLMModel(id: "o3-mini", displayName: "o3-mini", provider: .openai, tier: .best),
            ]
        case .claude:
            [
                LLMModel(id: "claude-haiku-4-5-20251001", displayName: "Haiku 4.5", provider: .claude, tier: .fast),
                LLMModel(id: "claude-sonnet-4-6", displayName: "Sonnet 4.6", provider: .claude, tier: .balanced),
                LLMModel(id: "claude-opus-4-6", displayName: "Opus 4.6", provider: .claude, tier: .best),
            ]
        case .gemini:
            [
                LLMModel(id: "gemini-2.0-flash", displayName: "Gemini 2.0 Flash", provider: .gemini, tier: .fast),
                LLMModel(id: "gemini-2.5-pro", displayName: "Gemini 2.5 Pro", provider: .gemini, tier: .balanced),
            ]
        case .grok:
            [
                LLMModel(id: "grok-3-mini-fast", displayName: "Grok 3 Mini Fast", provider: .grok, tier: .fast),
                LLMModel(id: "grok-3", displayName: "Grok 3", provider: .grok, tier: .balanced),
            ]
        case .ollama:
            [
                LLMModel(id: "llama3.2", displayName: "Llama 3.2 3B", provider: .ollama, tier: .fast),
                LLMModel(id: "llama3.3", displayName: "Llama 3.3 70B", provider: .ollama, tier: .balanced),
            ]
        }
    }

    /// Default model for this provider.
    /// Most providers default to balanced; Ollama defaults to fast (smaller download).
    var defaultModel: LLMModel {
        switch self {
        case .ollama:
            return availableModels.first(where: { $0.tier == .fast }) ?? availableModels[0]
        default:
            return availableModels.first(where: { $0.tier == .balanced }) ?? availableModels[0]
        }
    }
}
