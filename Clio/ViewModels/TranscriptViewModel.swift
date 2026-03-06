import Foundation
import Combine
import os

@MainActor
@Observable
final class TranscriptViewModel {
    var segments: [TranscriptSegment] = []
    var isLiveTranscribing = false
    var autoScroll = true

    private let services: ServiceContainer
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger.transcription

    init(services: ServiceContainer) {
        self.services = services
    }

    func startListening() {
        isLiveTranscribing = true
        services.transcription.segmentPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] segment in
                self?.segments.append(segment)
                self?.logger.debug("New segment: \(segment.text.prefix(50))")
            }
            .store(in: &cancellables)
    }

    func stopListening() {
        isLiveTranscribing = false
        cancellables.removeAll()
    }

    func loadSegments(for meeting: Meeting) {
        segments = meeting.segments.sorted { $0.startTime < $1.startTime }
    }

    func clear() {
        segments.removeAll()
    }
}
