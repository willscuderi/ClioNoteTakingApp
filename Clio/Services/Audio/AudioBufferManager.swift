import AVFoundation
import Combine
import os

final class AudioBufferManager {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "AudioBuffer")
    private let chunkSubject = PassthroughSubject<AVAudioPCMBuffer, Never>()
    private var cancellables = Set<AnyCancellable>()

    let chunkDurationSeconds: Double
    private let sampleRate: Double
    private let channels: AVAudioChannelCount

    /// Accumulated samples waiting to form a complete chunk
    private var accumulatedSamples: [Float] = []
    private let samplesPerChunk: Int
    private let audioFormat: AVAudioFormat

    /// Publishes audio chunks ready for transcription
    var chunkPublisher: AnyPublisher<AVAudioPCMBuffer, Never> {
        chunkSubject.eraseToAnyPublisher()
    }

    init(chunkDurationSeconds: Double = 10.0, sampleRate: Double = 16000, channels: AVAudioChannelCount = 1) {
        self.chunkDurationSeconds = chunkDurationSeconds
        self.sampleRate = sampleRate
        self.channels = channels
        self.samplesPerChunk = Int(sampleRate * chunkDurationSeconds)
        self.audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        )!
        accumulatedSamples.reserveCapacity(samplesPerChunk)
    }

    func connect(to source: AnyPublisher<AVAudioPCMBuffer, Never>) {
        cancellables.removeAll()
        accumulatedSamples.removeAll(keepingCapacity: true)

        source.sink { [weak self] buffer in
            self?.accumulate(buffer: buffer)
        }.store(in: &cancellables)

        logger.info("Buffer manager connected, chunk: \(self.chunkDurationSeconds)s (\(self.samplesPerChunk) samples)")
    }

    func disconnect() {
        cancellables.removeAll()
        logger.info("Buffer manager disconnected")
    }

    /// Flush any remaining accumulated samples as a final chunk
    func flush() {
        guard !accumulatedSamples.isEmpty else { return }
        emitChunk(from: accumulatedSamples)
        accumulatedSamples.removeAll(keepingCapacity: true)
        logger.info("Buffer manager flushed remaining samples")
    }

    private func accumulate(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        // Append new samples
        accumulatedSamples.append(contentsOf: UnsafeBufferPointer(start: channelData, count: frameLength))

        // Emit complete chunks
        while accumulatedSamples.count >= samplesPerChunk {
            let chunk = Array(accumulatedSamples.prefix(samplesPerChunk))
            accumulatedSamples.removeFirst(samplesPerChunk)
            emitChunk(from: chunk)
        }
    }

    private func emitChunk(from samples: [Float]) {
        let frameCount = AVAudioFrameCount(samples.count)
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
            logger.error("Failed to create PCM buffer for chunk")
            return
        }
        pcmBuffer.frameLength = frameCount

        if let destData = pcmBuffer.floatChannelData?[0] {
            samples.withUnsafeBufferPointer { src in
                destData.initialize(from: src.baseAddress!, count: samples.count)
            }
        }

        chunkSubject.send(pcmBuffer)
        logger.debug("Emitted chunk: \(samples.count) samples (\(Double(samples.count) / self.sampleRate)s)")
    }
}
