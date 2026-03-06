import AVFoundation
import Combine
import os

final class TranscriptionCoordinator: TranscriptionServiceProtocol {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "TranscriptionCoord")
    private let local: LocalTranscriptionService
    private let api: APITranscriptionService
    private let segmentSubject = PassthroughSubject<TranscriptSegment, Never>()
    private var cancellables = Set<AnyCancellable>()

    var preferredSource: TranscriptionSource = .local

    var isTranscribing: Bool {
        switch preferredSource {
        case .local: local.isTranscribing
        case .openAIWhisper: api.isTranscribing
        }
    }

    var segmentPublisher: AnyPublisher<TranscriptSegment, Never> {
        segmentSubject.eraseToAnyPublisher()
    }

    init(local: LocalTranscriptionService, api: APITranscriptionService) {
        self.local = local
        self.api = api

        // Forward segments from both services
        local.segmentPublisher
            .sink { [weak self] in self?.segmentSubject.send($0) }
            .store(in: &cancellables)

        api.segmentPublisher
            .sink { [weak self] in self?.segmentSubject.send($0) }
            .store(in: &cancellables)
    }

    func startTranscription() async throws {
        logger.info("Starting transcription via \(self.preferredSource.rawValue)")
        switch preferredSource {
        case .local: try await local.startTranscription()
        case .openAIWhisper: try await api.startTranscription()
        }
    }

    func stopTranscription() async throws {
        switch preferredSource {
        case .local: try await local.stopTranscription()
        case .openAIWhisper: try await api.stopTranscription()
        }
    }

    func transcribeBuffer(_ buffer: AVAudioPCMBuffer) async throws -> TranscriptSegment? {
        switch preferredSource {
        case .local: try await local.transcribeBuffer(buffer)
        case .openAIWhisper: try await api.transcribeBuffer(buffer)
        }
    }
}
