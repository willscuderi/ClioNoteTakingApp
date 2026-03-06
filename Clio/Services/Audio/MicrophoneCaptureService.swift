import AVFoundation
import Combine
import os

final class MicrophoneCaptureService: AudioCaptureServiceProtocol {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "Microphone")
    private let bufferSubject = PassthroughSubject<AVAudioPCMBuffer, Never>()
    private var audioEngine: AVAudioEngine?

    private(set) var isCapturing = false
    private(set) var audioLevel: Float = 0

    /// Target format: 16kHz mono Float32 (Whisper's native format)
    private let targetSampleRate: Double = 16000
    private let targetChannels: AVAudioChannelCount = 1

    var audioBufferPublisher: AnyPublisher<AVAudioPCMBuffer, Never> {
        bufferSubject.eraseToAnyPublisher()
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startCapture(source: AudioSource) async throws {
        guard !isCapturing else { return }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0 else {
            throw AudioCaptureError.noInputDevice
        }

        // Create target format for Whisper (16kHz mono)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: targetChannels,
            interleaved: false
        ) else {
            throw AudioCaptureError.formatError
        }

        // Create converter from input format to target format
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioCaptureError.formatError
        }

        // Buffer size: ~100ms of audio at input sample rate
        let bufferSize = AVAudioFrameCount(inputFormat.sampleRate * 0.1)

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) {
            [weak self] buffer, _ in
            guard let self else { return }

            // Calculate RMS audio level
            self.updateAudioLevel(buffer: buffer)

            // Convert to target format
            let frameCount = AVAudioFrameCount(
                Double(buffer.frameLength) * self.targetSampleRate / inputFormat.sampleRate
            )
            guard let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: frameCount
            ) else { return }

            var error: NSError?
            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            if error == nil && convertedBuffer.frameLength > 0 {
                self.bufferSubject.send(convertedBuffer)
            }
        }

        try engine.start()
        self.audioEngine = engine
        isCapturing = true
        logger.info("Microphone capture started at \(inputFormat.sampleRate)Hz → \(self.targetSampleRate)Hz")
    }

    func stopCapture() async throws {
        guard isCapturing else { return }
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isCapturing = false
        audioLevel = 0
        logger.info("Microphone capture stopped")
    }

    func pauseCapture() async throws {
        guard isCapturing else { return }
        audioEngine?.pause()
        isCapturing = false
        logger.info("Microphone capture paused")
    }

    func resumeCapture() async throws {
        guard let engine = audioEngine else { return }
        try engine.start()
        isCapturing = true
        logger.info("Microphone capture resumed")
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

        // Convert to dB-like scale (0.0 to 1.0)
        let level = max(0, min(1, (20 * log10f(max(rms, 1e-7)) + 60) / 60))
        self.audioLevel = level
    }
}
