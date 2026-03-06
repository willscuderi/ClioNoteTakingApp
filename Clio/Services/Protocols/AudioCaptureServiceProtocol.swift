import AVFoundation
import Combine

enum AudioSource: String, CaseIterable {
    case systemAudio
    case microphone
    case both
}

protocol AudioCaptureServiceProtocol: AnyObject {
    var isCapturing: Bool { get }
    var audioLevel: Float { get }
    var audioBufferPublisher: AnyPublisher<AVAudioPCMBuffer, Never> { get }

    func requestPermission() async -> Bool
    func startCapture(source: AudioSource) async throws
    func stopCapture() async throws
    func pauseCapture() async throws
    func resumeCapture() async throws
}
