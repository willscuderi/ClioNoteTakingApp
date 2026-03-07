import AVFoundation
import CoreAudio
import Combine
import os

/// Coordinates system audio and microphone capture, mixing, and buffering.
/// This is the top-level audio service used by RecordingViewModel.
final class AudioCaptureCoordinator: AudioCaptureServiceProtocol {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "AudioCoord")

    private let systemAudio = SystemAudioCaptureService()
    let microphone = MicrophoneCaptureService()
    private let mixer = AudioMixer()
    let bufferManager = AudioBufferManager(chunkDurationSeconds: 10.0)

    /// Separate per-channel buffer managers for speaker separation in "Both" mode
    let micBufferManager = AudioBufferManager(chunkDurationSeconds: 10.0)
    let systemBufferManager = AudioBufferManager(chunkDurationSeconds: 10.0)

    private var activeSource: AudioSource?

    var isCapturing: Bool {
        systemAudio.isCapturing || microphone.isCapturing
    }

    var audioLevel: Float {
        switch activeSource {
        case .systemAudio: systemAudio.audioLevel
        case .microphone: microphone.audioLevel
        case .both: max(systemAudio.audioLevel, microphone.audioLevel)
        case .none: 0
        }
    }

    /// Raw mixed audio stream (before chunking)
    var audioBufferPublisher: AnyPublisher<AVAudioPCMBuffer, Never> {
        mixer.outputPublisher
    }

    func requestPermission() async -> Bool {
        // Request both permissions
        let micGranted = await microphone.requestPermission()
        let screenGranted = await systemAudio.requestPermission()
        logger.info("Permissions — mic: \(micGranted), screen: \(screenGranted)")
        return micGranted || screenGranted
    }

    func startCapture(source: AudioSource) async throws {
        activeSource = source

        // Start the appropriate capture service(s)
        switch source {
        case .systemAudio:
            try await systemAudio.startCapture(source: source)

        case .microphone:
            try await microphone.startCapture(source: source)

        case .both:
            // Start both — if one fails, still use the other
            do {
                try await systemAudio.startCapture(source: source)
            } catch {
                logger.warning("System audio failed, continuing with mic only: \(error.localizedDescription)")
            }
            try await microphone.startCapture(source: source)
        }

        // Connect mixer to active sources
        mixer.connect(
            systemAudio: systemAudio.audioBufferPublisher,
            microphone: microphone.audioBufferPublisher,
            source: source
        )

        // Connect buffer manager to mixer output (used for single-source modes)
        bufferManager.connect(to: mixer.outputPublisher)

        // In "Both" mode, also connect per-channel buffer managers for speaker separation
        if source == .both {
            micBufferManager.connect(to: microphone.audioBufferPublisher)
            systemBufferManager.connect(to: systemAudio.audioBufferPublisher)
        }

        logger.info("Audio capture coordinator started with source: \(source.rawValue)")
    }

    func stopCapture() async throws {
        // Flush remaining audio
        bufferManager.flush()
        bufferManager.disconnect()
        micBufferManager.flush()
        micBufferManager.disconnect()
        systemBufferManager.flush()
        systemBufferManager.disconnect()
        mixer.disconnect()

        if systemAudio.isCapturing {
            try await systemAudio.stopCapture()
        }
        if microphone.isCapturing {
            try await microphone.stopCapture()
        }

        activeSource = nil
        logger.info("Audio capture coordinator stopped")
    }

    func pauseCapture() async throws {
        if systemAudio.isCapturing {
            try await systemAudio.pauseCapture()
        }
        if microphone.isCapturing {
            try await microphone.pauseCapture()
        }
        logger.info("Audio capture coordinator paused")
    }

    func resumeCapture() async throws {
        guard let source = activeSource else { return }
        if source == .systemAudio || source == .both {
            try await systemAudio.resumeCapture()
        }
        if source == .microphone || source == .both {
            try await microphone.resumeCapture()
        }
        logger.info("Audio capture coordinator resumed")
    }
}
