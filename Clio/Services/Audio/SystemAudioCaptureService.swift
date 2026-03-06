import AVFoundation
import Combine
import ScreenCaptureKit
import os

final class SystemAudioCaptureService: NSObject, AudioCaptureServiceProtocol {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "SystemAudio")
    private let bufferSubject = PassthroughSubject<AVAudioPCMBuffer, Never>()
    private var stream: SCStream?
    private var streamOutput: AudioStreamOutput?

    private(set) var isCapturing = false
    private(set) var audioLevel: Float = 0

    /// Target format: 16kHz mono (Whisper's native format)
    private let targetSampleRate: Int = 16000
    private let targetChannels: Int = 1

    var audioBufferPublisher: AnyPublisher<AVAudioPCMBuffer, Never> {
        bufferSubject.eraseToAnyPublisher()
    }

    func requestPermission() async -> Bool {
        // ScreenCaptureKit triggers TCC permission prompt on first use
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            return true
        } catch {
            logger.error("Screen capture permission denied: \(error.localizedDescription)")
            return false
        }
    }

    func startCapture(source: AudioSource) async throws {
        guard !isCapturing else { return }

        // Get available content
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)

        guard let display = content.displays.first else {
            throw AudioCaptureError.noDisplayAvailable
        }

        // Create filter to capture all audio from the display
        // Exclude nothing — we want all system audio
        let filter = SCContentFilter(display: display, excludingWindows: [])

        // Configure for audio-only capture at 16kHz mono
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.sampleRate = targetSampleRate
        config.channelCount = targetChannels
        config.excludesCurrentProcessAudio = false

        // Minimize video overhead since we only need audio
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1) // 1 fps minimum
        config.showsCursor = false

        // Create stream output handler
        let output = AudioStreamOutput { [weak self] sampleBuffer in
            self?.handleAudioSampleBuffer(sampleBuffer)
        }
        self.streamOutput = output

        // Create and start the stream
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: .global(qos: .userInteractive))
        try await stream.startCapture()

        self.stream = stream
        isCapturing = true
        logger.info("System audio capture started at \(self.targetSampleRate)Hz")
    }

    func stopCapture() async throws {
        guard isCapturing, let stream else { return }
        try await stream.stopCapture()
        self.stream = nil
        self.streamOutput = nil
        isCapturing = false
        audioLevel = 0
        logger.info("System audio capture stopped")
    }

    func pauseCapture() async throws {
        // ScreenCaptureKit doesn't support pause — stop the stream
        try await stopCapture()
        logger.info("System audio capture paused (stopped)")
    }

    func resumeCapture() async throws {
        // Restart capture
        try await startCapture(source: .systemAudio)
        logger.info("System audio capture resumed (restarted)")
    }

    private func handleAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let formatDescription = sampleBuffer.formatDescription,
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return
        }

        let sampleRate = asbd.pointee.mSampleRate
        let channels = asbd.pointee.mChannelsPerFrame

        guard let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(channels),
            interleaved: false
        ) else { return }

        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }

        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return
        }
        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)

        var dataPointer: UnsafeMutablePointer<Int8>?
        var totalLength: Int = 0
        let status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &totalLength, dataPointerOut: &dataPointer)

        guard status == noErr, let srcData = dataPointer else { return }

        // Copy sample data into PCM buffer
        if let destData = pcmBuffer.floatChannelData?[0] {
            memcpy(destData, srcData, min(totalLength, Int(pcmBuffer.frameCapacity) * MemoryLayout<Float>.size))
        }

        // Update audio level
        updateAudioLevel(buffer: pcmBuffer)

        bufferSubject.send(pcmBuffer)
    }

    private func updateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        var rms: Float = 0
        for i in 0..<frameLength {
            rms += channelData[i] * channelData[i]
        }
        rms = sqrtf(rms / Float(frameLength))
        let level = max(0, min(1, (20 * log10f(max(rms, 1e-7)) + 60) / 60))
        self.audioLevel = level
    }
}

// MARK: - SCStreamOutput handler

private final class AudioStreamOutput: NSObject, SCStreamOutput {
    let handler: (CMSampleBuffer) -> Void

    init(handler: @escaping (CMSampleBuffer) -> Void) {
        self.handler = handler
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        handler(sampleBuffer)
    }
}
