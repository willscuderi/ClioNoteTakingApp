import Foundation

enum MeetingStatus: String, Codable, CaseIterable {
    case recording
    case paused
    case processing
    case completed
    case failed

    var displayName: String {
        switch self {
        case .recording: "Recording"
        case .paused: "Paused"
        case .processing: "Processing"
        case .completed: "Completed"
        case .failed: "Failed"
        }
    }
}
