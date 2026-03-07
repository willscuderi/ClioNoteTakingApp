import Foundation
import SwiftData

@Model
final class Meeting {
    var id: UUID
    var title: String
    var createdAt: Date
    var endedAt: Date?
    var status: MeetingStatus
    var summary: String?
    var rawTranscript: String?
    var notes: String?
    var durationSeconds: Double
    var audioFilePath: String?

    @Relationship(deleteRule: .cascade, inverse: \TranscriptSegment.meeting)
    var segments: [TranscriptSegment]

    @Relationship(deleteRule: .cascade, inverse: \Bookmark.meeting)
    var bookmarks: [Bookmark]

    var folder: MeetingFolder?

    init(
        id: UUID = UUID(),
        title: String = "New Meeting",
        createdAt: Date = Date(),
        status: MeetingStatus = .recording
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.status = status
        self.durationSeconds = 0
        self.segments = []
        self.bookmarks = []
    }

    var formattedDuration: String {
        let hours = Int(durationSeconds) / 3600
        let minutes = (Int(durationSeconds) % 3600) / 60
        let seconds = Int(durationSeconds) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var fullTranscript: String {
        segments
            .sorted { $0.startTime < $1.startTime }
            .map { segment in
                if let speaker = segment.speakerLabel {
                    return "[\(speaker)] \(segment.text)"
                }
                return segment.text
            }
            .joined(separator: "\n")
    }
}
