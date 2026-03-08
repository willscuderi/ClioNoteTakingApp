import AVFoundation
import Combine
import os

/// Transcription service using AssemblyAI's API with speaker diarization support.
/// Uploads audio, requests transcription with `speaker_labels: true`, polls for results,
/// and returns utterances with per-speaker labels (Speaker A, Speaker B, etc.).
///
/// **Known limitation (v1):** Speaker labels are assigned independently per audio chunk.
/// Speaker A in one chunk might be a different physical person than Speaker A in another.
/// This is acceptable for v1; future improvements could accumulate larger segments or
/// post-process to align speaker labels across the recording.
final class AssemblyAITranscriptionService: TranscriptionServiceProtocol {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "AssemblyAI")
    private let segmentSubject = PassthroughSubject<TranscriptSegment, Never>()
    private let keychain: KeychainServiceProtocol

    private let baseURL = "https://api.assemblyai.com/v2"
    private let pollInterval: TimeInterval = 3
    private let maxPollAttempts = 30 // 90s max wait

    private(set) var isTranscribing = false

    var segmentPublisher: AnyPublisher<TranscriptSegment, Never> {
        segmentSubject.eraseToAnyPublisher()
    }

    init(keychain: KeychainServiceProtocol) {
        self.keychain = keychain
    }

    func startTranscription() async throws {
        guard let _ = try keychain.loadAPIKey(for: "assemblyai") else {
            throw TranscriptionError.apiKeyMissing("assemblyai")
        }
        isTranscribing = true
        logger.info("AssemblyAI transcription ready")
    }

    func stopTranscription() async throws {
        isTranscribing = false
        logger.info("AssemblyAI transcription stopped")
    }

    // MARK: - Protocol Conformance (single segment)

    func transcribeBuffer(_ buffer: AVAudioPCMBuffer) async throws -> TranscriptSegment? {
        // For protocol conformance, return the first utterance or combined text
        let segments = try await transcribeBufferWithDiarization(buffer)
        guard !segments.isEmpty else { return nil }

        // If only one segment, return it directly
        if segments.count == 1 { return segments[0] }

        // Combine all segments into one for the basic protocol
        let combined = segments.map(\.text).joined(separator: " ")
        let segment = TranscriptSegment(
            text: combined,
            startTime: segments.first?.startTime ?? 0,
            endTime: segments.last?.endTime ?? 0,
            confidence: segments.map(\.confidence).reduce(0, +) / Float(segments.count),
            source: .assemblyAI
        )
        segmentSubject.send(segment)
        return segment
    }

    // MARK: - Diarization Pipeline

    /// Full diarization pipeline: encode → upload → submit → poll → parse utterances.
    /// Returns multiple `TranscriptSegment` objects, each with a `speakerLabel`.
    func transcribeBufferWithDiarization(_ buffer: AVAudioPCMBuffer) async throws -> [TranscriptSegment] {
        guard let apiKey = try keychain.loadAPIKey(for: "assemblyai") else {
            throw TranscriptionError.apiKeyMissing("assemblyai")
        }

        // 1. Encode audio to WAV
        let wavData = try AudioEncoding.encodeToWAV(buffer: buffer)
        logger.debug("Encoded WAV: \(wavData.count) bytes")

        // 2. Upload audio
        let uploadURL = try await uploadAudio(wavData: wavData, apiKey: apiKey)
        logger.debug("Upload complete: \(uploadURL)")

        // 3. Submit transcription request with speaker diarization
        let transcriptID = try await submitTranscription(audioURL: uploadURL, apiKey: apiKey)
        logger.debug("Transcription submitted: \(transcriptID)")

        // 4. Poll for completion
        let response = try await pollForCompletion(transcriptID: transcriptID, apiKey: apiKey)
        logger.info("Transcription complete, \(response.utterances?.count ?? 0) utterances")

        // 5. Parse utterances into TranscriptSegments
        guard let utterances = response.utterances, !utterances.isEmpty else {
            // No utterances — fall back to full text if available
            if let text = response.text, !text.isEmpty {
                let segment = TranscriptSegment(
                    text: text,
                    startTime: 0,
                    endTime: Double(buffer.frameLength) / buffer.format.sampleRate,
                    confidence: response.confidence ?? 1.0,
                    source: .assemblyAI
                )
                segmentSubject.send(segment)
                return [segment]
            }
            return []
        }

        var segments: [TranscriptSegment] = []
        for utterance in utterances {
            let segment = TranscriptSegment(
                text: utterance.text,
                startTime: Double(utterance.start) / 1000.0, // ms → seconds
                endTime: Double(utterance.end) / 1000.0,
                confidence: utterance.confidence,
                source: .assemblyAI
            )
            segment.speakerLabel = "Speaker \(utterance.speaker)"
            segments.append(segment)
            segmentSubject.send(segment)
        }

        return segments
    }

    // MARK: - API Steps

    /// Step 1: Upload audio data to AssemblyAI's hosting service.
    private func uploadAudio(wavData: Data, apiKey: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/upload") else {
            throw TranscriptionError.networkError("Invalid upload URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = wavData
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            throw TranscriptionError.apiError(status, "Upload failed: \(body)")
        }

        let uploadResponse = try JSONDecoder().decode(AssemblyAIUploadResponse.self, from: data)
        return uploadResponse.upload_url
    }

    /// Step 2: Submit a transcription request with speaker diarization enabled.
    private func submitTranscription(audioURL: String, apiKey: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/transcript") else {
            throw TranscriptionError.networkError("Invalid transcript URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "audio_url": audioURL,
            "speaker_labels": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseBody = String(data: data, encoding: .utf8) ?? "Unknown"
            throw TranscriptionError.apiError(status, "Submit failed: \(responseBody)")
        }

        let submitResponse = try JSONDecoder().decode(AssemblyAITranscriptResponse.self, from: data)
        return submitResponse.id
    }

    /// Step 3: Poll until the transcription is complete.
    private func pollForCompletion(transcriptID: String, apiKey: String) async throws -> AssemblyAITranscriptResponse {
        guard let url = URL(string: "\(baseURL)/transcript/\(transcriptID)") else {
            throw TranscriptionError.networkError("Invalid poll URL")
        }

        for attempt in 1...maxPollAttempts {
            var request = URLRequest(url: url)
            request.setValue(apiKey, forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 15

            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(AssemblyAITranscriptResponse.self, from: data)

            switch response.status {
            case "completed":
                return response
            case "error":
                let errorMsg = response.error ?? "Unknown AssemblyAI error"
                throw TranscriptionError.apiError(-1, errorMsg)
            default:
                // "queued" or "processing" — wait and retry
                logger.debug("Poll attempt \(attempt)/\(self.maxPollAttempts): status=\(response.status)")
                try await Task.sleep(for: .seconds(pollInterval))
            }
        }

        throw TranscriptionError.networkError("AssemblyAI transcription timed out after \(maxPollAttempts * Int(pollInterval))s")
    }
}

// MARK: - AssemblyAI API Response Models

private struct AssemblyAIUploadResponse: Decodable {
    let upload_url: String
}

struct AssemblyAITranscriptResponse: Decodable {
    let id: String
    let status: String
    let text: String?
    let confidence: Float?
    let utterances: [AssemblyAIUtterance]?
    let error: String?
}

struct AssemblyAIUtterance: Decodable {
    let speaker: String      // "A", "B", "C", ...
    let text: String
    let start: Int            // milliseconds
    let end: Int              // milliseconds
    let confidence: Float
}
