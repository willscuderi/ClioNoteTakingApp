import Foundation

protocol LLMServiceProtocol: AnyObject {
    func summarize(transcript: String, provider: LLMProvider, model: LLMModel?) async throws -> String
    func isConfigured(provider: LLMProvider) -> Bool
}
