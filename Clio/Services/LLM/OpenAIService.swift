import Foundation
import os

final class OpenAIService: LLMServiceProtocol {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "OpenAI")
    private let keychain: KeychainServiceProtocol
    private let apiURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    init(keychain: KeychainServiceProtocol) {
        self.keychain = keychain
    }

    func summarize(transcript: String, provider: LLMProvider, model: LLMModel? = nil) async throws -> String {
        guard provider == .openai else {
            throw LLMError.providerMismatch
        }

        guard let apiKey = try keychain.loadAPIKey(for: "openai") else {
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

        // Truncate transcript if too long (GPT-4o context is 128k but we cap at ~50k chars)
        let truncatedTranscript = String(transcript.prefix(50000))

        let requestBody: [String: Any] = [
            "model": modelID,
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
            throw LLMError.from(statusCode: httpResponse.statusCode, body: errorBody)
        }

        let result = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)

        guard let content = result.choices.first?.message.content else {
            throw LLMError.apiError("No content in response")
        }

        logger.info("Summary generated (\(content.count) chars)")
        return content
    }

    func summarizeStreaming(transcript: String, provider: LLMProvider, model: LLMModel?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard provider == .openai else { throw LLMError.providerMismatch }
                    guard let apiKey = try self.keychain.loadAPIKey(for: "openai") else { throw LLMError.notConfigured }

                    let modelID = model?.id ?? provider.defaultModel.id
                    let truncated = String(transcript.prefix(50000))

                    let requestBody: [String: Any] = [
                        "model": modelID,
                        "messages": [
                            ["role": "system", "content": LLMPrompts.summarySystem],
                            ["role": "user", "content": "Please summarize this meeting transcript:\n\n\(truncated)"]
                        ],
                        "temperature": 0.3,
                        "max_tokens": 2000,
                        "stream": true
                    ]

                    var request = URLRequest(url: self.apiURL)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
                        if json == "[DONE]" { break }
                        guard let data = json.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = obj["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let content = delta["content"] as? String else { continue }
                        continuation.yield(content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func askQuestion(question: String, context: String, provider: LLMProvider, model: LLMModel?) async throws -> String {
        guard provider == .openai else { throw LLMError.providerMismatch }
        guard let apiKey = try keychain.loadAPIKey(for: "openai") else { throw LLMError.notConfigured }

        let modelID = model?.id ?? provider.defaultModel.id
        let truncatedContext = String(context.prefix(50000))

        let requestBody: [String: Any] = [
            "model": modelID,
            "messages": [
                ["role": "system", "content": LLMPrompts.askQuestionSystem],
                ["role": "user", "content": "Here is the meeting context:\n\n\(truncatedContext)\n\n---\n\nQuestion: \(question)"]
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

        logger.info("Asking question via OpenAI (\(truncatedContext.count) chars context)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.apiError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.from(statusCode: httpResponse.statusCode, body: errorBody)
        }

        let result = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)

        guard let content = result.choices.first?.message.content else {
            throw LLMError.apiError("No content in response")
        }

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
