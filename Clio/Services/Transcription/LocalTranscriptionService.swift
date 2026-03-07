import AVFoundation
import Combine
import os

final class LocalTranscriptionService: TranscriptionServiceProtocol {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "LocalSTT")
    private let segmentSubject = PassthroughSubject<TranscriptSegment, Never>()
    private var whisperContext: WhisperContext?

    /// Cumulative time offset (seconds) from previous chunks in the same session.
    private var sessionTimeOffset: Double = 0

    private(set) var isTranscribing = false

    var segmentPublisher: AnyPublisher<TranscriptSegment, Never> {
        segmentSubject.eraseToAnyPublisher()
    }

    func startTranscription() async throws {
        logger.info("Starting local transcription")
        sessionTimeOffset = 0

        // Load the model lazily on first use
        if whisperContext == nil {
            logger.info("Loading whisper model...")
            whisperContext = try WhisperContext.loadBundled()
            logger.info("Whisper model loaded successfully")
        }

        isTranscribing = true
    }

    func stopTranscription() async throws {
        logger.info("Stopping local transcription")
        isTranscribing = false
    }

    func transcribeBuffer(_ buffer: AVAudioPCMBuffer) async throws -> TranscriptSegment? {
        guard let ctx = whisperContext else {
            throw WhisperError.modelNotFound("No model loaded — call startTranscription() first")
        }

        // Extract Float32 samples from the PCM buffer
        guard let channelData = buffer.floatChannelData else { return nil }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return nil }

        // Copy samples from channel 0 (mono)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))

        // Check audio level (for logging) — use a very low threshold to avoid
        // filtering out quiet speech. Whisper handles silence well on its own.
        let rms = sqrt(samples.reduce(0.0) { $0 + $1 * $1 } / Float(samples.count))
        logger.info("Audio chunk: \(frameCount) samples, RMS: \(String(format: "%.6f", rms))")

        if rms < 0.0005 {
            logger.info("Skipping near-zero buffer (RMS: \(String(format: "%.6f", rms)))")
            sessionTimeOffset += Double(frameCount) / 16000.0
            return nil
        }

        // Run whisper inference
        logger.info("Running whisper inference on \(samples.count) samples...")
        let whisperSegments = try await ctx.transcribe(samples: samples)
        logger.info("Whisper returned \(whisperSegments.count) segments")

        guard !whisperSegments.isEmpty else {
            sessionTimeOffset += Double(frameCount) / 16000.0
            return nil
        }

        // Combine all whisper segments into one TranscriptSegment per buffer chunk
        let combinedText = whisperSegments.map(\.text).joined(separator: " ")
        let startTime = sessionTimeOffset + (whisperSegments.first?.startTime ?? 0)
        let endTime = sessionTimeOffset + (whisperSegments.last?.endTime ?? Double(frameCount) / 16000.0)

        let segment = TranscriptSegment(
            text: combinedText,
            startTime: startTime,
            endTime: endTime,
            source: .local
        )

        segmentSubject.send(segment)

        // Advance time offset by this chunk's duration
        sessionTimeOffset += Double(frameCount) / 16000.0

        return segment
    }
}
