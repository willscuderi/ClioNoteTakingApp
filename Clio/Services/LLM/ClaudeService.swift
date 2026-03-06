import Foundation
import os

final class ClaudeService: LLMServiceProtocol {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "Claude")
    private let keychain: KeychainServiceProtocol
    private let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!

    init(keychain: KeychainServiceProtocol) {
        self.keychain = keychain
    }

    func summarize(transcript: String, provider: LLMProvider) async throws -> String {
        guard provider == .claude else {
            throw LLMError.providerMismatch
        }

        guard let apiKey = try keychain.loadAPIKey(for: "claude") else {
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

        // Truncate transcript if too long
        let truncatedTranscript = String(transcript.prefix(80000))

        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 2000,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": "Please summarize this meeting transcript:\n\n\(truncatedTranscript)"]
            ]
        ]

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        logger.info("Sending transcript to Claude (\(truncatedTranscript.count) chars)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.apiError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Claude API error \(httpResponse.statusCode): \(errorBody)")
            throw LLMError.apiError("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        let result = try JSONDecoder().decode(ClaudeResponse.self, from: data)

        guard let textBlock = result.content.first(where: { $0.type == "text" }) else {
            throw LLMError.apiError("No text content in response")
        }

        logger.info("Summary generated (\(textBlock.text.count) chars)")
        return textBlock.text
    }

    func isConfigured(provider: LLMProvider) -> Bool {
        guard provider == .claude else { return false }
        return (try? keychain.loadAPIKey(for: "claude")) != nil
    }
}

// MARK: - Response Models

private struct ClaudeResponse: Decodable {
    let content: [ContentBlock]

    struct ContentBlock: Decodable {
        let type: String
        let text: String
    }
}
