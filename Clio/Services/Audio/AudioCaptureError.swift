import Foundation

enum AudioCaptureError: LocalizedError {
    case noInputDevice
    case noDisplayAvailable
    case formatError
    case permissionDenied
    case alreadyCapturing
    case notCapturing

    var errorDescription: String? {
        switch self {
        case .noInputDevice: "No audio input device available"
        case .noDisplayAvailable: "No display available for screen capture"
        case .formatError: "Failed to create audio format"
        case .permissionDenied: "Audio capture permission denied"
        case .alreadyCapturing: "Audio capture is already active"
        case .notCapturing: "Audio capture is not active"
        }
    }
}
