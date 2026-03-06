import Foundation
import os

final class LLMCoordinator: LLMServiceProtocol {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "LLMCoord")
    private let openAI: OpenAIService
    private let claude: ClaudeService

    init(openAI: OpenAIService, claude: ClaudeService) {
        self.openAI = openAI
        self.claude = claude
    }

    func summarize(transcript: String, provider: LLMProvider) async throws -> String {
        logger.info("Summarizing with provider: \(provider.rawValue)")
        switch provider {
        case .openai: return try await openAI.summarize(transcript: transcript, provider: provider)
        case .claude: return try await claude.summarize(transcript: transcript, provider: provider)
        case .gemini, .grok, .ollama:
            logger.warning("\(provider.displayName) not yet implemented, falling back to OpenAI")
            return try await openAI.summarize(transcript: transcript, provider: .openai)
        }
    }

    func isConfigured(provider: LLMProvider) -> Bool {
        switch provider {
        case .openai: openAI.isConfigured(provider: provider)
        case .claude: claude.isConfigured(provider: provider)
        case .gemini, .grok, .ollama: false
        }
    }
}

enum LLMError: LocalizedError {
    case providerMismatch
    case notConfigured
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .providerMismatch: "Provider mismatch"
        case .notConfigured: "API key not configured"
        case .apiError(let message): "API error: \(message)"
        }
    }
}
