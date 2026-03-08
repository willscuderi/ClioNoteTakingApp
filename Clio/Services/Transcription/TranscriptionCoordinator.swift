import AVFoundation
import Combine
import os

final class TranscriptionCoordinator: TranscriptionServiceProtocol {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "TranscriptionCoord")
    private let local: LocalTranscriptionService
    private let api: APITranscriptionService
    let assemblyAI: AssemblyAITranscriptionService
    private let segmentSubject = PassthroughSubject<TranscriptSegment, Never>()
    private var cancellables = Set<AnyCancellable>()

    var preferredSource: TranscriptionSource = .local

    var isTranscribing: Bool {
        switch preferredSource {
        case .local: local.isTranscribing
        case .openAIWhisper: api.isTranscribing
        case .assemblyAI: assemblyAI.isTranscribing
        }
    }

    var segmentPublisher: AnyPublisher<TranscriptSegment, Never> {
        segmentSubject.eraseToAnyPublisher()
    }

    init(local: LocalTranscriptionService, api: APITranscriptionService, assemblyAI: AssemblyAITranscriptionService) {
        self.local = local
        self.api = api
        self.assemblyAI = assemblyAI

        // Forward segments from all services
        local.segmentPublisher
            .sink { [weak self] in self?.segmentSubject.send($0) }
            .store(in: &cancellables)

        api.segmentPublisher
            .sink { [weak self] in self?.segmentSubject.send($0) }
            .store(in: &cancellables)

        assemblyAI.segmentPublisher
            .sink { [weak self] in self?.segmentSubject.send($0) }
            .store(in: &cancellables)
    }

    func startTranscription() async throws {
        logger.info("Starting transcription via \(self.preferredSource.rawValue)")
        switch preferredSource {
        case .local: try await local.startTranscription()
        case .openAIWhisper: try await api.startTranscription()
        case .assemblyAI: try await assemblyAI.startTranscription()
        }
    }

    func stopTranscription() async throws {
        switch preferredSource {
        case .local: try await local.stopTranscription()
        case .openAIWhisper: try await api.stopTranscription()
        case .assemblyAI: try await assemblyAI.stopTranscription()
        }
    }

    func transcribeBuffer(_ buffer: AVAudioPCMBuffer) async throws -> TranscriptSegment? {
        switch preferredSource {
        case .local: try await local.transcribeBuffer(buffer)
        case .openAIWhisper: try await api.transcribeBuffer(buffer)
        case .assemblyAI: try await assemblyAI.transcribeBuffer(buffer)
        }
    }

    /// Transcribe with full diarization support. Only AssemblyAI returns multiple speaker-labeled segments;
    /// other sources return a single-element array.
    func transcribeBufferWithDiarization(_ buffer: AVAudioPCMBuffer) async throws -> [TranscriptSegment] {
        switch preferredSource {
        case .assemblyAI:
            return try await assemblyAI.transcribeBufferWithDiarization(buffer)
        case .local, .openAIWhisper:
            // Wrap single-segment result for non-diarization sources
            if let segment = try await transcribeBuffer(buffer) {
                return [segment]
            }
            return []
        }
    }
}
