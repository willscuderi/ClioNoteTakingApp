import Foundation
import SwiftData

@Model
final class MeetingFolder {
    var id: UUID
    var name: String
    var createdAt: Date
    var sortOrder: Int

    @Relationship(deleteRule: .nullify, inverse: \Meeting.folder)
    var meetings: [Meeting]

    init(name: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.sortOrder = sortOrder
        self.meetings = []
    }
}
