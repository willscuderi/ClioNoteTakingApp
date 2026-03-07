import Foundation
import os

final class OllamaService: LLMServiceProtocol {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "Ollama")
    private let baseURL: String

    init(baseURL: String = "http://localhost:11434") {
        self.baseURL = baseURL
    }

    func summarize(transcript: String, provider: LLMProvider, model: LLMModel? = nil) async throws -> String {
        guard provider == .ollama else {
            throw LLMError.providerMismatch
        }

        // Verify Ollama is running
        guard await isReachable() else {
            throw LLMError.apiError("Ollama is not running. Start it from your Applications folder or menu bar.")
        }

        let modelID = model?.id ?? provider.defaultModel.id

        let systemPrompt = """
        You are a meeting note assistant. Given a meeting transcript, produce a clear, concise summary in Markdown format. Include:

        ## Meeting Summary
        A 2-3 sentence overview of what was discussed.

        ### Key Points
        Bullet points of the most important topics, decisions, and insights.

        ### Action Items
        A checklist of follow-up tasks mentioned or implied, with owners if identifiable.

        ### Decisions Made
        Any decisions that were reached during the meeting.

        Be concise but thorough. Use the speakers' own language where appropriate.

        The transcript may include speaker labels like [You] and [Remote]. [You] is the person who recorded the meeting (the local user). [Remote] is audio from the other side of a call — it may contain multiple people. When speaker labels are present, attribute statements and action items to the correct speaker. If you can distinguish multiple remote participants by context or conversational cues, label them (e.g., "Remote Speaker 1", "Remote Speaker 2"). If unsure, use "Remote" as a group label.
        """

        // Ollama uses the OpenAI-compatible /api/chat endpoint
        let truncatedTranscript = String(transcript.prefix(50000))

        let requestBody: [String: Any] = [
            "model": modelID,
            "messages": [
                ["role": "system", "content": systemPrompt],
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
