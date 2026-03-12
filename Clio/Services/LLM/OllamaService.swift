import Foundation
import os

final class OllamaService: LLMServiceProtocol {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "Ollama")
    private let baseURL: String

    init(baseURL: String = "http://localhost:11434") {
        self.baseURL = baseURL
    }

    func summarize(transcript: String, provider: LLMProvider, model: LLMModel? = nil, systemPrompt: String? = nil) async throws -> String {
        guard provider == .ollama else {
            throw LLMError.providerMismatch
        }

        // Verify Ollama is running
        guard await isReachable() else {
            throw LLMError.apiError("Ollama is not running. Start it from your Applications folder or menu bar.")
        }

        let modelID = model?.id ?? provider.defaultModel.id
        let prompt = systemPrompt ?? LLMPrompts.summarySystem

        // Ollama uses the OpenAI-compatible /api/chat endpoint
        let truncatedTranscript = String(transcript.prefix(50000))

        let requestBody: [String: Any] = [
            "model": modelID,
            "messages": [
                ["role": "system", "content": prompt],
                ["role": "user", "content": "Please summarize this meeting transcript:\n\n\(truncatedTranscript)"]
            ],
            "stream": false,
            "options": [
                "temperature": 0.3
            ]
        ]

        let url = URL(string: "\(baseURL)/api/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300 // Local models can be slow
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        logger.info("Sending transcript to Ollama \(modelID) (\(truncatedTranscript.count) chars)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.apiError("Invalid response from Ollama")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Ollama API error \(httpResponse.statusCode): \(errorBody)")
            if errorBody.lowercased().contains("not found") {
                throw LLMError.apiError("Model \"\(modelID)\" not found. Run: ollama pull \(modelID)")
            }
            throw LLMError.apiError("Ollama error: HTTP \(httpResponse.statusCode)")
        }

        let result = try JSONDecoder().decode(OllamaChatResponse.self, from: data)

        guard let content = result.message?.content, !content.isEmpty else {
            throw LLMError.apiError("No content in Ollama response")
        }

        logger.info("Summary generated (\(content.count) chars)")
        return content
    }

    func summarizeStreaming(transcript: String, provider: LLMProvider, model: LLMModel?, systemPrompt: String? = nil) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard provider == .ollama else { throw LLMError.providerMismatch }
                    guard await self.isReachable() else {
                        throw LLMError.apiError("Ollama is not running. Start it from your Applications folder or menu bar.")
                    }

                    let modelID = model?.id ?? provider.defaultModel.id
                    let truncated = String(transcript.prefix(50000))
                    let prompt = systemPrompt ?? LLMPrompts.summarySystem

                    let requestBody: [String: Any] = [
                        "model": modelID,
                        "messages": [
                            ["role": "system", "content": prompt],
                            ["role": "user", "content": "Please summarize this meeting transcript:\n\n\(truncated)"]
                        ],
                        "stream": true,
                        "options": [
                            "temperature": 0.3
                        ]
                    ]

                    let url = URL(string: "\(self.baseURL)/api/chat")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.timeoutInterval = 300
                    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                        throw LLMError.apiError("Ollama error: HTTP \(code)")
                    }

                    // Ollama streams newline-delimited JSON
                    for try await line in bytes.lines {
                        guard !line.isEmpty,
                              let data = line.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let message = obj["message"] as? [String: Any],
                              let content = message["content"] as? String else { continue }

                        continuation.yield(content)
                        if let done = obj["done"] as? Bool, done { break }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func askQuestion(question: String, context: String, provider: LLMProvider, model: LLMModel?) async throws -> String {
        guard provider == .ollama else { throw LLMError.providerMismatch }
        guard await isReachable() else {
            throw LLMError.apiError("Ollama is not running. Start it from your Applications folder or menu bar.")
        }

        let modelID = model?.id ?? provider.defaultModel.id
        let truncatedContext = String(context.prefix(50000))

        let requestBody: [String: Any] = [
            "model": modelID,
            "messages": [
                ["role": "system", "content": LLMPrompts.askQuestionSystem],
                ["role": "user", "content": "Here is the meeting context:\n\n\(truncatedContext)\n\n---\n\nQuestion: \(question)"]
            ],
            "stream": false,
            "options": [
                "temperature": 0.3
            ]
        ]

        let url = URL(string: "\(baseURL)/api/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        logger.info("Asking question via Ollama \(modelID) (\(truncatedContext.count) chars context)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.apiError("Invalid response from Ollama")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            if errorBody.lowercased().contains("not found") {
                throw LLMError.apiError("Model \"\(modelID)\" not found. Run: ollama pull \(modelID)")
            }
            throw LLMError.apiError("Ollama error: HTTP \(httpResponse.statusCode)")
        }

        let result = try JSONDecoder().decode(OllamaChatResponse.self, from: data)

        guard let content = result.message?.content, !content.isEmpty else {
            throw LLMError.apiError("No content in Ollama response")
        }

        return content
    }

    func isConfigured(provider: LLMProvider) -> Bool {
        guard provider == .ollama else { return false }
        // Ollama doesn't need an API key — just check if it's reachable
        // We do a synchronous check based on cached state; the real check happens at summarize time
        return true
    }

    /// Check if the Ollama server is reachable
    private func isReachable() async -> Bool {
        let url = URL(string: "\(baseURL)/api/tags")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 3

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}

// MARK: - Response Models

private struct OllamaChatResponse: Decodable {
    let message: Message?

    struct Message: Decodable {
        let content: String?
    }
}
