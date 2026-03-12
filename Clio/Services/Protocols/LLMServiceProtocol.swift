import Foundation

protocol LLMServiceProtocol: AnyObject {
    func summarize(transcript: String, provider: LLMProvider, model: LLMModel?, systemPrompt: String?) async throws -> String
    func summarizeStreaming(transcript: String, provider: LLMProvider, model: LLMModel?, systemPrompt: String?) -> AsyncThrowingStream<String, Error>
    func askQuestion(question: String, context: String, provider: LLMProvider, model: LLMModel?) async throws -> String
    func isConfigured(provider: LLMProvider) -> Bool
}

extension LLMServiceProtocol {
    func summarize(transcript: String, provider: LLMProvider, model: LLMModel?) async throws -> String {
        try await summarize(transcript: transcript, provider: provider, model: model, systemPrompt: nil)
    }

    func summarizeStreaming(transcript: String, provider: LLMProvider, model: LLMModel?) -> AsyncThrowingStream<String, Error> {
        summarizeStreaming(transcript: transcript, provider: provider, model: model, systemPrompt: nil)
    }
}
