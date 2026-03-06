import Foundation

protocol LLMServiceProtocol: AnyObject {
    func summarize(transcript: String, provider: LLMProvider) async throws -> String
    func isConfigured(provider: LLMProvider) -> Bool
}
