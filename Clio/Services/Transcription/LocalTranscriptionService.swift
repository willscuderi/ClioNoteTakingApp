import AVFoundation
import Combine
import os

final class LocalTranscriptionService: TranscriptionServiceProtocol {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "LocalSTT")
    private let segmentSubject = PassthroughSubject<TranscriptSegment, Never>()
    private var whisperContext: WhisperContext?

    /// Cumulative time offset (seconds) from previous chunks in the same session.
    private var sessionTimeOffset: Double = 0

    /// Last transcript text from previous chunk (for context continuity)
    private var lastTranscriptSuffix: String?

    /// Overlap samples retained from end of previous chunk (for Maximum accuracy)
    private var overlapSamples: [Float] = []
    private let overlapDurationSeconds: Double = 2.0
    private let sampleRate: Double = 16000.0

    private(set) var isTranscribing = false

    var segmentPublisher: AnyPublisher<TranscriptSegment, Never> {
        segmentSubject.eraseToAnyPublisher()
    }

    func startTranscription() async throws {
        logger.info("Starting local transcription")
        sessionTimeOffset = 0
        lastTranscriptSuffix = nil
        overlapSamples = []

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
        lastTranscriptSuffix = nil
        overlapSamples = []
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
        var samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))

        // Read accuracy settings
        let accuracy = TranscriptionAccuracy(rawValue: UserDefaults.standard.string(forKey: "transcriptionAccuracy") ?? "") ?? .balanced

        // Prepend overlap samples from previous chunk (Maximum accuracy mode)
        var overlapSampleCount = 0
        if accuracy.useOverlap && !overlapSamples.isEmpty {
            samples = overlapSamples + samples
            overlapSampleCount = overlapSamples.count
            logger.info("Prepended \(overlapSampleCount) overlap samples (\(String(format: "%.1f", Double(overlapSampleCount) / self.sampleRate))s)")
        }

        // Save overlap samples for next chunk (last 2 seconds)
        if accuracy.useOverlap {
            let overlapCount = Int(overlapDurationSeconds * sampleRate)
            if samples.count > overlapCount {
                overlapSamples = Array(samples.suffix(overlapCount))
            }
        } else {
            overlapSamples = []
        }

        // Check audio level — use a very low threshold to avoid
        // filtering out quiet speech. Whisper handles silence well on its own.
        let rms = sqrt(samples.reduce(0.0) { $0 + $1 * $1 } / Float(samples.count))
        logger.info("Audio chunk: \(samples.count) samples, RMS: \(String(format: "%.6f", rms))")

        if rms < 0.0005 {
            logger.info("Skipping near-zero buffer (RMS: \(String(format: "%.6f", rms)))")
            sessionTimeOffset += Double(frameCount) / sampleRate
            return nil
        }

        // Run whisper inference with accuracy-appropriate settings
        logger.info("Running whisper inference on \(samples.count) samples (accuracy: \(accuracy.rawValue))...")
        let whisperSegments = try await ctx.transcribe(
            samples: samples,
            useBeamSearch: accuracy.useBeamSearch,
            initialPrompt: lastTranscriptSuffix
        )
        logger.info("Whisper returned \(whisperSegments.count) segments")

        guard !whisperSegments.isEmpty else {
            sessionTimeOffset += Double(frameCount) / sampleRate
            return nil
        }

        // Combine all whisper segments into one TranscriptSegment per buffer chunk
        var combinedText = whisperSegments.map(\.text).joined(separator: " ")

        // Deduplicate overlap: if we prepended overlap audio, the start of the transcription
        // may repeat the end of the previous segment. Remove duplicated prefix.
        if accuracy.useOverlap && overlapSampleCount > 0, let lastSuffix = lastTranscriptSuffix {
            combinedText = deduplicateOverlap(previous: lastSuffix, current: combinedText)
        }

        // Save last transcript suffix for context continuity (last ~100 chars)
        let suffixLength = min(combinedText.count, 100)
        lastTranscriptSuffix = String(combinedText.suffix(suffixLength))

        let startTime = sessionTimeOffset + (whisperSegments.first?.startTime ?? 0)
        let endTime = sessionTimeOffset + (whisperSegments.last?.endTime ?? Double(frameCount) / sampleRate)

        let segment = TranscriptSegment(
            text: combinedText,
            startTime: startTime,
            endTime: endTime,
            source: .local
        )

        segmentSubject.send(segment)

        // Advance time offset by this chunk's actual duration (not including overlap)
        sessionTimeOffset += Double(frameCount) / sampleRate

        return segment
    }

    /// Remove duplicated text at the junction between overlapping chunks.
    /// Finds the longest common suffix of `previous` that matches a prefix of `current`.
    private func deduplicateOverlap(previous: String, current: String) -> String {
        let prevWords = previous.split(separator: " ")
        let currentWords = current.split(separator: " ")
        guard !prevWords.isEmpty && !currentWords.isEmpty else { return current }

        // Try matching the last N words of previous with the first N words of current
        let maxCheck = min(prevWords.count, currentWords.count, 10)
        var bestMatch = 0

        for length in 1...maxCheck {
            let prevSuffix = prevWords.suffix(length)
            let currentPrefix = currentWords.prefix(length)
            if prevSuffix.map(String.init) == currentPrefix.map(String.init) {
                bestMatch = length
            }
        }

        if bestMatch > 0 {
            let trimmed = currentWords.dropFirst(bestMatch).joined(separator: " ")
            return trimmed.isEmpty ? current : trimmed
        }

        return current
    }
}
