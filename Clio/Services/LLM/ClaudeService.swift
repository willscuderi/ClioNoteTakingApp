import Foundation
import os

final class ClaudeService: LLMServiceProtocol {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "Claude")
    private let keychain: KeychainServiceProtocol
    private let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!

    init(keychain: KeychainServiceProtocol) {
        self.keychain = keychain
    }

    func summarize(transcript: String, provider: LLMProvider, model: LLMModel? = nil) async throws -> String {
        guard provider == .claude else {
            throw LLMError.providerMismatch
        }

        guard let apiKey = try keychain.loadAPIKey(for: "claude") else {
            throw LLMError.notConfigured
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

        // Truncate transcript if too long
        let truncatedTranscript = String(transcript.prefix(80000))

        let requestBody: [String: Any] = [
            "model": modelID,
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
            throw LLMError.from(statusCode: httpResponse.statusCode, body: errorBody)
        }

        let result = try JSONDecoder().decode(ClaudeResponse.self, from: data)

        guard let textBlock = result.content.first(where: { $0.type == "text" }) else {
            throw LLMError.apiError("No text content in response")
        }

        logger.info("Summary generated (\(textBlock.text.count) chars)")
        return textBlock.text
    }

    func summarizeStreaming(transcript: String, provider: LLMProvider, model: LLMModel?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard provider == .claude else { throw LLMError.providerMismatch }
                    guard let apiKey = try self.keychain.loadAPIKey(for: "claude") else { throw LLMError.notConfigured }

                    let modelID = model?.id ?? provider.defaultModel.id
                    let truncated = String(transcript.prefix(80000))

                    let requestBody: [String: Any] = [
                        "model": modelID,
                        "max_tokens": 2000,
                        "stream": true,
                        "system": LLMPrompts.summarySystem,
                        "messages": [
                            ["role": "user", "content": "Please summarize this meeting transcript:\n\n\(truncated)"]
                        ]
                    ]

                    var request = URLRequest(url: self.apiURL)
                    request.httpMethod = "POST"
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.timeoutInterval = 120
                    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                        throw LLMError.from(statusCode: code, body: "Streaming request failed")
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let json = String(line.dropFirst(6))
                        guard let data = json.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let eventType = obj["type"] as? String else { continue }

                        if eventType == "content_block_delta",
                           let delta = obj["delta"] as? [String: Any],
                           let text = delta["text"] as? String {
                            continuation.yield(text)
                        } else if eventType == "message_stop" {
                            break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func askQuestion(question: String, context: String, provider: LLMProvider, model: LLMModel?) async throws -> String {
        guard provider == .claude else { throw LLMError.providerMismatch }
        guard let apiKey = try keychain.loadAPIKey(for: "claude") else { throw LLMError.notConfigured }

        let modelID = model?.id ?? provider.defaultModel.id
        let truncatedContext = String(context.prefix(80000))

        let requestBody: [String: Any] = [
            "model": modelID,
            "max_tokens": 2000,
            "system": LLMPrompts.askQuestionSystem,
            "messages": [
                ["role": "user", "content": "Here is the meeting context:\n\n\(truncatedContext)\n\n---\n\nQuestion: \(question)"]
            ]
        ]

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        logger.info("Asking question via Claude (\(truncatedContext.count) chars context)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.apiError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.from(statusCode: httpResponse.statusCode, body: errorBody)
        }

        let result = try JSONDecoder().decode(ClaudeResponse.self, from: data)

        guard let textBlock = result.content.first(where: { $0.type == "text" }) else {
            throw LLMError.apiError("No text content in response")
        }

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
