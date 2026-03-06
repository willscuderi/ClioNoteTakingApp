import AVFoundation
import Combine

protocol TranscriptionServiceProtocol: AnyObject {
    var isTranscribing: Bool { get }
    var segmentPublisher: AnyPublisher<TranscriptSegment, Never> { get }

    func startTranscription() async throws
    func stopTranscription() async throws
    func transcribeBuffer(_ buffer: AVAudioPCMBuffer) async throws -> TranscriptSegment?
}
