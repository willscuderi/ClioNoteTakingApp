import Foundation
import os
import whisper_cpp

/// Thread-safe wrapper around whisper.cpp C API.
/// Uses an actor to serialize all access to the underlying C context.
actor WhisperContext {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "WhisperContext")
    private var context: OpaquePointer

    private init(context: OpaquePointer) {
        self.context = context
    }

    deinit {
        whisper_free(context)
    }

    /// Load a whisper model from a file path.
    static func load(from path: String, useGPU: Bool = true) throws -> WhisperContext {
        var params = whisper_context_default_params()
        params.use_gpu = useGPU
        params.flash_attn = true

        guard let ctx = whisper_init_from_file_with_params(path, params) else {
            throw WhisperError.modelLoadFailed(path)
        }

        return WhisperContext(context: ctx)
    }

    /// Load the bundled model from the app's Resources/Models directory.
    static func loadBundled(modelName: String = "ggml-base.en", useGPU: Bool = true) throws -> WhisperContext {
        // Look in the Models folder inside the bundle
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "bin", subdirectory: "Models") else {
            // Also try without subdirectory (flat bundle)
            guard let flatURL = Bundle.main.url(forResource: modelName, withExtension: "bin") else {
                throw WhisperError.modelNotFound(modelName)
            }
            return try load(from: flatURL.path, useGPU: useGPU)
        }
        return try load(from: modelURL.path, useGPU: useGPU)
    }

    /// Transcribe a buffer of 16kHz mono Float32 PCM samples.
    /// Returns an array of transcribed segments with timestamps.
    func transcribe(samples: [Float], language: String = "en") throws -> [WhisperSegment] {
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)

        // Thread count: use most available cores but leave 2 free
        let maxThreads = max(1, min(8, ProcessInfo.processInfo.activeProcessorCount - 2))
        params.n_threads = Int32(maxThreads)
        params.language = (language as NSString).utf8String
        params.translate = false
        params.no_context = true
        params.single_segment = false
        params.print_special = false
        params.print_progress = false
        params.print_realtime = false
        params.print_timestamps = false

        logger.debug("Transcribing \(samples.count) samples (\(String(format: "%.1f", Double(samples.count) / 16000.0))s)")

        let result = samples.withUnsafeBufferPointer { ptr in
            whisper_full(context, params, ptr.baseAddress, Int32(samples.count))
        }

        guard result == 0 else {
            throw WhisperError.transcriptionFailed(code: Int(result))
        }

        let segmentCount = whisper_full_n_segments(context)
        var segments: [WhisperSegment] = []

        for i in 0..<segmentCount {
            guard let textPtr = whisper_full_get_segment_text(context, i) else { continue }
            let text = String(cString: textPtr).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            // Timestamps are in centiseconds (1/100s)
            let t0 = whisper_full_get_segment_t0(context, i)
            let t1 = whisper_full_get_segment_t1(context, i)

            let segment = WhisperSegment(
                text: text,
                startTime: Double(t0) / 100.0,
                endTime: Double(t1) / 100.0
            )
            segments.append(segment)
        }

        logger.debug("Got \(segments.count) segments from whisper")
        return segments
    }
}

/// A single transcribed segment from whisper.cpp.
struct WhisperSegment {
    let text: String
    let startTime: Double  // seconds
    let endTime: Double    // seconds
}

/// Errors from whisper.cpp operations.
enum WhisperError: LocalizedError {
    case modelNotFound(String)
    case modelLoadFailed(String)
    case transcriptionFailed(code: Int)

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let name): "Whisper model not found: \(name)"
        case .modelLoadFailed(let path): "Failed to load whisper model at: \(path)"
        case .transcriptionFailed(let code): "Whisper transcription failed with code \(code)"
        }
    }
}
