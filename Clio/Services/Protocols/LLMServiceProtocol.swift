import Foundation

protocol LLMServiceProtocol: AnyObject {
    func summarize(transcript: String, provider: LLMProvider, model: LLMModel?) async throws -> String
    func summarizeStreaming(transcript: String, provider: LLMProvider, model: LLMModel?) -> AsyncThrowingStream<String, Error>
    func askQuestion(question: String, context: String, provider: LLMProvider, model: LLMModel?) async throws -> String
    func isConfigured(provider: LLMProvider) -> Bool
}
