import Foundation
import os

/// LLM service that proxies through the Clio Pro backend (Gemini-powered).
/// No API key needed from the user — just a Clio Pro subscription.
final class ClioProService: LLMServiceProtocol {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "ClioProService")
    private let baseURL = "https://clionotes.com/api/summarize"
    private let apiKey: String

    init() {
        // The Clio Pro API key is embedded — it authenticates the app, not the user.
        // Rate limiting is per-device on the server side.
        self.apiKey = "clio-pro-v1"
    }

    private var deviceId: String {
        if let existing = UserDefaults.standard.string(forKey: "clioDeviceId") {
            return existing
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "clioDeviceId")
        return id
    }

    func summarize(transcript: String, provider: LLMProvider, model: LLMModel? = nil, systemPrompt: String? = nil) async throws -> String {
        guard provider == .clioPro else { throw LLMError.providerMismatch }

        var result = ""
        let stream = summarizeStreaming(transcript: transcript, provider: provider, model: model, systemPrompt: systemPrompt)
        for try await chunk in stream {
            result += chunk
        }
        return result
    }

    func summarizeStreaming(transcript: String, provider: LLMProvider, model: LLMModel? = nil, systemPrompt: String? = nil) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard provider == .clioPro else { throw LLMError.providerMismatch }

                    guard let url = URL(string: self.baseURL) else {
                        throw LLMError.apiError("Invalid Clio Pro URL")
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.timeoutInterval = 120

                    var body: [String: Any] = [
                        "transcript": String(transcript.prefix(100_000)),
                        "deviceId": self.deviceId,
                    ]
                    if let systemPrompt {
                        body["systemPrompt"] = systemPrompt
                    }
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw LLMError.apiError("Invalid response from Clio Pro")
                    }

                    if httpResponse.statusCode == 429 {
                        throw LLMError.rateLimited
                    }

                    if httpResponse.statusCode == 401 {
                        throw LLMError.apiError("Clio Pro subscription required. Please upgrade in Settings.")
                    }

                    guard httpResponse.statusCode == 200 else {
                        throw LLMError.apiError("Clio Pro error (HTTP \(httpResponse.statusCode))")
                    }

                    // Stream text chunks
                    var buffer = Data()
                    for try await byte in bytes {
                        buffer.append(byte)

                        // Flush whenever we get a reasonable chunk
                        if buffer.count >= 64 {
                            if let text = String(data: buffer, encoding: .utf8) {
                                continuation.yield(text)
                            }
                            buffer.removeAll()
                        }
                    }

                    // Flush remaining
                    if !buffer.isEmpty, let text = String(data: buffer, encoding: .utf8) {
                        continuation.yield(text)
                    }

                    continuation.finish()
                    self.logger.info("Clio Pro summary completed successfully")
                } catch {
                    self.logger.error("Clio Pro error: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func askQuestion(question: String, context: String, provider: LLMProvider, model: LLMModel?) async throws -> String {
        guard provider == .clioPro else { throw LLMError.providerMismatch }

        guard let url = URL(string: baseURL) else {
            throw LLMError.apiError("Invalid Clio Pro URL")
        }

        let systemPrompt = LLMPrompts.askQuestionSystem

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "transcript": String(context.prefix(100_000)),
            "deviceId": deviceId,
            "systemPrompt": "\(systemPrompt)\n\nQuestion from the user: \(question)",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.apiError("Invalid response from Clio Pro")
        }

        if httpResponse.statusCode == 429 { throw LLMError.rateLimited }
        if httpResponse.statusCode == 401 { throw LLMError.apiError("Clio Pro subscription required.") }

        guard httpResponse.statusCode == 200 else {
            throw LLMError.apiError("Clio Pro error (HTTP \(httpResponse.statusCode))")
        }

        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
            throw LLMError.apiError("Empty response from Clio Pro")
        }

        return text
    }

    func isConfigured(provider: LLMProvider) -> Bool {
        guard provider == .clioPro else { return false }
        // Always available — the server handles subscription validation.
        // If the user isn't subscribed, the 401 error message tells them to upgrade.
        return true
    }
}
