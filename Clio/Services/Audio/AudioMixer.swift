import AVFoundation
import Combine
import os

final class AudioMixer {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "AudioMixer")
    private let outputSubject = PassthroughSubject<AVAudioPCMBuffer, Never>()
    private var cancellables = Set<AnyCancellable>()

    var outputPublisher: AnyPublisher<AVAudioPCMBuffer, Never> {
        outputSubject.eraseToAnyPublisher()
    }

    func connect(systemAudio: AnyPublisher<AVAudioPCMBuffer, Never>,
                 microphone: AnyPublisher<AVAudioPCMBuffer, Never>,
                 source: AudioSource) {
        cancellables.removeAll()

        switch source {
        case .systemAudio:
            systemAudio.sink { [weak self] buffer in
                self?.outputSubject.send(buffer)
            }.store(in: &cancellables)

        case .microphone:
            microphone.sink { [weak self] buffer in
                self?.outputSubject.send(buffer)
            }.store(in: &cancellables)

        case .both:
            // TODO: Real mixing of two audio streams
            // For now, merge both streams sequentially
            systemAudio.merge(with: microphone)
                .sink { [weak self] buffer in
                    self?.outputSubject.send(buffer)
                }.store(in: &cancellables)
        }

        logger.info("Audio mixer connected for source: \(source.rawValue)")
    }

    func disconnect() {
        cancellables.removeAll()
        logger.info("Audio mixer disconnected")
    }
}
