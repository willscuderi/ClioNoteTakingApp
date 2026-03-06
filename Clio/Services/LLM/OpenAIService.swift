import Foundation
import os

final class OpenAIService: LLMServiceProtocol {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "OpenAI")
    private let keychain: KeychainServiceProtocol
    private let apiURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    init(keychain: KeychainServiceProtocol) {
        self.keychain = keychain
    }

    func summarize(transcript: String, provider: LLMProvider) async throws -> String {
        guard provider == .openai else {
            throw LLMError.providerMismatch
        }

        guard let apiKey = try keychain.loadAPIKey(for: "openai") else {
            throw LLMError.notConfigured
        }

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
        """

        // Truncate transcript if too long (GPT-4o context is 128k but we cap at ~50k chars)
        let truncatedTranscript = String(transcript.prefix(50000))

        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "Please summarize this meeting transcript:\n\n\(truncatedTranscript)"]
            ],
            "temperature": 0.3,
            "max_tokens": 2000
        ]

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        logger.info("Sending transcript to OpenAI (\(truncatedTranscript.count) chars)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.apiError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("OpenAI API error \(httpResponse.statusCode): \(errorBody)")
            throw LLMError.apiError("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        let result = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)

        guard let content = result.choices.first?.message.content else {
            throw LLMError.apiError("No content in response")
        }

        logger.info("Summary generated (\(content.count) chars)")
        return content
    }

    func isConfigured(provider: LLMProvider) -> Bool {
        guard provider == .openai else { return false }
        return (try? keychain.loadAPIKey(for: "openai")) != nil
    }
}

// MARK: - Response Models

private struct OpenAIChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String?
    }
}
