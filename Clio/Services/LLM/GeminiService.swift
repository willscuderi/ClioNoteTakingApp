import Foundation
import os

final class GeminiService: LLMServiceProtocol {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "Gemini")
    private let keychain: KeychainServiceProtocol
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    init(keychain: KeychainServiceProtocol) {
        self.keychain = keychain
    }

    func summarize(transcript: String, provider: LLMProvider, model: LLMModel? = nil) async throws -> String {
        guard provider == .gemini else {
            throw LLMError.providerMismatch
        }

        guard let apiKey = try keychain.loadAPIKey(for: "gemini") else {
            throw LLMError.notConfigured
        }

        let modelID = model?.id ?? provider.defaultModel.id

        let systemInstruction = """
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

        // Truncate transcript if too long (Gemini supports large contexts but cap reasonably)
        let truncatedTranscript = String(transcript.prefix(100000))

        let requestBody: [String: Any] = [
            "system_instruction": [
                "parts": [["text": systemInstruction]]
            ],
            "contents": [
                [
                    "parts": [["text": "Please summarize this meeting transcript:\n\n\(truncatedTranscript)"]]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 2000
            ]
        ]

        let url = URL(string: "\(baseURL)/\(modelID):generateContent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        logger.info("Sending transcript to Gemini \(modelID) (\(truncatedTranscript.count) chars)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.apiError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Gemini API error \(httpResponse.statusCode): \(errorBody)")
            throw LLMError.from(statusCode: httpResponse.statusCode, body: errorBody)
        }

        let result = try JSONDecoder().decode(GeminiResponse.self, from: data)

        guard let text = result.candidates?.first?.content?.parts?.first?.text else {
            throw LLMError.apiError("No text content in Gemini response")
        }

        logger.info("Summary generated (\(text.count) chars)")
        return text
    }

    func summarizeStreaming(transcript: String, provider: LLMProvider, model: LLMModel?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard provider == .gemini else { throw LLMError.providerMismatch }
                    guard let apiKey = try self.keychain.loadAPIKey(for: "gemini") else { throw LLMError.notConfigured }

                    let modelID = model?.id ?? provider.defaultModel.id
                    let truncated = String(transcript.prefix(100000))

                    let requestBody: [String: Any] = [
                        "system_instruction": [
                            "parts": [["text": LLMPrompts.summarySystem]]
                        ],
                        "contents": [
                            [
                                "parts": [["text": "Please summarize this meeting transcript:\n\n\(truncated)"]]
                            ]
                        ],
                        "generationConfig": [
                            "temperature": 0.3,
                            "maxOutputTokens": 2000
                        ]
                    ]

                    // Use streamGenerateContent endpoint
                    let url = URL(string: "\(self.baseURL)/\(modelID):streamGenerateContent?alt=sse")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
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
                              let candidates = obj["candidates"] as? [[String: Any]],
                              let content = candidates.first?["content"] as? [String: Any],
                              let parts = content["parts"] as? [[String: Any]],
                              let text = parts.first?["text"] as? String else { continue }
                        continuation.yield(text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func askQuestion(question: String, context: String, provider: LLMProvider, model: LLMModel?) async throws -> String {
        guard provider == .gemini else { throw LLMError.providerMismatch }
        guard let apiKey = try keychain.loadAPIKey(for: "gemini") else { throw LLMError.notConfigured }

        let modelID = model?.id ?? provider.defaultModel.id
        let truncatedContext = String(context.prefix(100000))

        let requestBody: [String: Any] = [
            "system_instruction": [
                "parts": [["text": LLMPrompts.askQuestionSystem]]
            ],
            "contents": [
                [
                    "parts": [["text": "Here is the meeting context:\n\n\(truncatedContext)\n\n---\n\nQuestion: \(question)"]]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 2000
            ]
        ]

        let url = URL(string: "\(baseURL)/\(modelID):generateContent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        logger.info("Asking question via Gemini (\(truncatedContext.count) chars context)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.apiError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.from(statusCode: httpResponse.statusCode, body: errorBody)
        }

        let result = try JSONDecoder().decode(GeminiResponse.self, from: data)

        guard let text = result.candidates?.first?.content?.parts?.first?.text else {
            throw LLMError.apiError("No text content in Gemini response")
        }

        return text
    }

    func isConfigured(provider: LLMProvider) -> Bool {
        guard provider == .gemini else { return false }
        return (try? keychain.loadAPIKey(for: "gemini")) != nil
    }
}

// MARK: - Response Models

private struct GeminiResponse: Decodable {
    let candidates: [Candidate]?

    struct Candidate: Decodable {
        let content: Content?
    }

    struct Content: Decodable {
        let parts: [Part]?
    }

    struct Part: Decodable {
        let text: String?
    }
}
