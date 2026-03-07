import Foundation
import os

final class LLMCoordinator: LLMServiceProtocol {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "LLMCoord")
    private let openAI: OpenAIService
    private let claude: ClaudeService
    private let gemini: GeminiService
    private let ollama: OllamaService

    init(openAI: OpenAIService, claude: ClaudeService, gemini: GeminiService, ollama: OllamaService) {
        self.openAI = openAI
        self.claude = claude
        self.gemini = gemini
        self.ollama = ollama
    }

    func summarize(transcript: String, provider: LLMProvider, model: LLMModel? = nil) async throws -> String {
        let resolvedModel = model ?? provider.defaultModel
        logger.info("Summarizing with \(provider.rawValue) / \(resolvedModel.id)")
        switch provider {
        case .openai: return try await openAI.summarize(transcript: transcript, provider: provider, model: resolvedModel)
        case .claude: return try await claude.summarize(transcript: transcript, provider: provider, model: resolvedModel)
        case .gemini: return try await gemini.summarize(transcript: transcript, provider: provider, model: resolvedModel)
        case .ollama: return try await ollama.summarize(transcript: transcript, provider: provider, model: resolvedModel)
        case .grok:
            logger.warning("Grok not yet implemented")
            throw LLMError.apiError("Grok is not yet supported")
        }
    }

    func isConfigured(provider: LLMProvider) -> Bool {
        switch provider {
        case .openai: openAI.isConfigured(provider: provider)
        case .claude: claude.isConfigured(provider: provider)
        case .gemini: gemini.isConfigured(provider: provider)
        case .ollama: ollama.isConfigured(provider: provider)
        case .grok: false
        }
    }
}

enum LLMError: LocalizedError {
    case providerMismatch
    case notConfigured
    case quotaExceeded
    case rateLimited
    case authenticationFailed
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .providerMismatch: "Provider mismatch"
        case .notConfigured: "API key not configured. Add your key in Settings \u{2192} API Keys."
        case .quotaExceeded: "You've run out of API tokens. Please check your plan and billing details with your AI provider."
        case .rateLimited: "Too many requests. Please wait a moment and try again."
        case .authenticationFailed: "Your API key is invalid or expired. Update it in Settings \u{2192} API Keys."
        case .apiError(let message): "API error: \(message)"
        }
    }

    /// Parse an HTTP error response into a user-friendly LLMError
    static func from(statusCode: Int, body: String) -> LLMError {
        let lower = body.lowercased()
        if statusCode == 429 || lower.contains("insufficient_quota") || lower.contains("quota") {
            return .quotaExceeded
        }
        if statusCode == 401 || lower.contains("invalid_api_key") || lower.contains("authentication") {
            return .authenticationFailed
        }
        if lower.contains("rate_limit") {
            return .rateLimited
        }
        return .apiError("HTTP \(statusCode)")
    }
}
