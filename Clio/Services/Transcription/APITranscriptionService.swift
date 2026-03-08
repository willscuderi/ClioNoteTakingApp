import AVFoundation
import Combine
import os

final class APITranscriptionService: TranscriptionServiceProtocol {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "APISTT")
    private let segmentSubject = PassthroughSubject<TranscriptSegment, Never>()
    private let keychain: KeychainServiceProtocol
    private let apiURL = URL(string: "https://api.openai.com/v1/audio/transcriptions")!

    private(set) var isTranscribing = false

    var segmentPublisher: AnyPublisher<TranscriptSegment, Never> {
        segmentSubject.eraseToAnyPublisher()
    }

    init(keychain: KeychainServiceProtocol) {
        self.keychain = keychain
    }

    func startTranscription() async throws {
        guard let _ = try keychain.loadAPIKey(for: "openai") else {
            throw TranscriptionError.apiKeyMissing("openai")
        }
        isTranscribing = true
        logger.info("API transcription ready")
    }

    func stopTranscription() async throws {
        isTranscribing = false
        logger.info("API transcription stopped")
    }

    func transcribeBuffer(_ buffer: AVAudioPCMBuffer) async throws -> TranscriptSegment? {
        guard let apiKey = try keychain.loadAPIKey(for: "openai") else {
            throw TranscriptionError.apiKeyMissing("openai")
        }

        // Convert PCM buffer to WAV data for the API
        let wavData = try AudioEncoding.encodeToWAV(buffer: buffer)

        // Build multipart form request
        let boundary = UUID().uuidString
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        var body = Data()

        // Model field
        body.appendMultipart(boundary: boundary, name: "model", value: "whisper-1")

        // Response format
        body.appendMultipart(boundary: boundary, name: "response_format", value: "verbose_json")

        // Language (optional — let it auto-detect)
        // body.appendMultipart(boundary: boundary, name: "language", value: "en")

        // Audio file
        body.appendMultipart(boundary: boundary, name: "file", filename: "audio.wav", mimeType: "audio/wav", data: wavData)

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        logger.debug("Sending \(wavData.count) bytes to Whisper API")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Whisper API error \(httpResponse.statusCode): \(errorBody)")
            throw TranscriptionError.apiError(httpResponse.statusCode, errorBody)
        }

        // Parse response
        let result = try JSONDecoder().decode(WhisperResponse.self, from: data)

        let segment = TranscriptSegment(
            text: result.text,
            startTime: 0,
            endTime: result.duration ?? Double(buffer.frameLength) / buffer.format.sampleRate,
            confidence: 1.0,
            source: .openAIWhisper
        )

        segmentSubject.send(segment)
        logger.info("Transcribed: \(result.text.prefix(60))...")
        return segment
    }

}


// MARK: - Whisper API Response

private struct WhisperResponse: Decodable {
    let text: String
    let duration: Double?
    let language: String?
    let segments: [WhisperSegment]?

    struct WhisperSegment: Decodable {
        let start: Double
        let end: Double
        let text: String
    }
}

// MARK: - Errors

enum TranscriptionError: LocalizedError {
    case apiKeyMissing(String)
    case encodingFailed
    case networkError(String)
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing(let provider): "API key not configured for \(provider)"
        case .encodingFailed: "Failed to encode audio for API"
        case .networkError(let msg): "Network error: \(msg)"
        case .apiError(let code, let msg): "API error (\(code)): \(msg)"
        }
    }
}
