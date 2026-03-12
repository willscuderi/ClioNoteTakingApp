import AVFoundation
import Combine
import os

/// A circular buffer that stores the last N minutes of audio as PCM Float32 samples.
/// Used for retroactive recording: the user can "go back" and capture audio they missed.
/// Memory: 5 min × 16kHz × 4 bytes/sample ≈ 19.2 MB — negligible.
final class RollingAudioBuffer {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "RollingBuffer")
    private let sampleRate: Double = 16000
    private var cancellable: AnyCancellable?

    /// Ring buffer storage
    private var samples: [Float]
    /// Write position in the ring buffer
    private var writeIndex = 0
    /// Total samples written (may exceed capacity; used to know how full the buffer is)
    private var totalWritten = 0
    /// Maximum duration in seconds
    let maxDurationSeconds: Int

    private var capacity: Int {
        samples.count
    }

    init(maxDurationSeconds: Int = 300) {
        self.maxDurationSeconds = maxDurationSeconds
        let totalSamples = Int(16000) * maxDurationSeconds
        self.samples = [Float](repeating: 0, count: totalSamples)
        logger.info("Rolling buffer initialized: \(maxDurationSeconds)s (\(totalSamples) samples, \(totalSamples * 4 / 1024)KB)")
    }

    /// Connect to an audio source to passively accumulate samples.
    func connect(to source: AnyPublisher<AVAudioPCMBuffer, Never>) {
        cancellable?.cancel()
        cancellable = source.sink { [weak self] buffer in
            self?.append(buffer: buffer)
        }
        logger.info("Rolling buffer connected to audio source")
    }

    func disconnect() {
        cancellable?.cancel()
        cancellable = nil
        logger.info("Rolling buffer disconnected")
    }

    /// Clear all stored audio and reset.
    func clear() {
        writeIndex = 0
        totalWritten = 0
        // Zero out the buffer (no need to reallocate)
        samples.withUnsafeMutableBufferPointer { ptr in
            ptr.baseAddress?.initialize(repeating: 0, count: ptr.count)
        }
        logger.info("Rolling buffer cleared")
    }

    /// Extract the last `seconds` of audio as an AVAudioPCMBuffer.
    /// Returns nil if the buffer is empty.
    func captureRetroactive(seconds: Int) -> AVAudioPCMBuffer? {
        let availableSamples = min(totalWritten, capacity)
        guard availableSamples > 0 else {
            logger.warning("Rolling buffer is empty, nothing to capture")
            return nil
        }

        let requestedSamples = min(Int(sampleRate) * seconds, availableSamples)

        // Calculate the read start position in the ring buffer
        let readStart: Int
        if totalWritten <= capacity {
            // Buffer hasn't wrapped yet — read from the end of written data
            readStart = max(0, writeIndex - requestedSamples)
        } else {
            // Buffer has wrapped — calculate start relative to writeIndex
            readStart = (writeIndex - requestedSamples + capacity) % capacity
        }

        // Create output buffer
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!

        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(requestedSamples)) else {
            logger.error("Failed to create PCM buffer for retroactive capture")
            return nil
        }
        pcmBuffer.frameLength = AVAudioFrameCount(requestedSamples)

        guard let destData = pcmBuffer.floatChannelData?[0] else { return nil }

        // Copy from the ring buffer, handling wrap-around
        if readStart + requestedSamples <= capacity {
            // Contiguous read
            samples.withUnsafeBufferPointer { src in
                destData.initialize(from: src.baseAddress!.advanced(by: readStart), count: requestedSamples)
            }
        } else {
            // Wrapped read: two parts
            let firstPart = capacity - readStart
            let secondPart = requestedSamples - firstPart
            samples.withUnsafeBufferPointer { src in
                destData.initialize(from: src.baseAddress!.advanced(by: readStart), count: firstPart)
                destData.advanced(by: firstPart).initialize(from: src.baseAddress!, count: secondPart)
            }
        }

        logger.info("Captured retroactive audio: \(requestedSamples) samples (\(String(format: "%.1f", Double(requestedSamples) / self.sampleRate))s)")
        return pcmBuffer
    }

    /// How many seconds of audio are currently stored.
    var availableSeconds: Double {
        Double(min(totalWritten, capacity)) / sampleRate
    }

    // MARK: - Private

    private func append(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        let src = UnsafeBufferPointer(start: channelData, count: frameCount)

        for i in 0..<frameCount {
            samples[writeIndex] = src[i]
            writeIndex = (writeIndex + 1) % capacity
        }
        totalWritten += frameCount
    }
}
