import Foundation

enum MeetingStatus: String, Codable, CaseIterable {
    case recording
    case paused
    case processing
    case completed
    case failed
}
