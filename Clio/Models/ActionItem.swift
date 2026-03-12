import Foundation
import SwiftData

@Model
final class ActionItem {
    var id: UUID
    var text: String
    var owner: String?
    var dueDate: String?
    var isCompleted: Bool
    var meeting: Meeting?

    init(
        id: UUID = UUID(),
        text: String,
        owner: String? = nil,
        dueDate: String? = nil,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.text = text
        self.owner = owner
        self.dueDate = dueDate
        self.isCompleted = isCompleted
    }
}
