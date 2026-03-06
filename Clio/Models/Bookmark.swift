import Foundation
import SwiftData

@Model
final class Bookmark {
    var id: UUID
    var label: String
    var timestamp: Double
    var createdAt: Date
    var meeting: Meeting?

    init(
        id: UUID = UUID(),
        label: String = "",
        timestamp: Double,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.timestamp = timestamp
        self.createdAt = createdAt
    }

    var formattedTimestamp: String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
