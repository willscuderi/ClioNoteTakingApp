import Foundation
import SwiftData
import os

@MainActor
@Observable
final class MeetingListViewModel {
    var searchText = ""
    var selectedMeetingID: PersistentIdentifier?

    private let logger = Logger.ui

    func filteredMeetings(_ meetings: [Meeting]) -> [Meeting] {
        guard !searchText.isEmpty else { return meetings }
        let query = searchText.lowercased()
        return meetings.filter { meeting in
            meeting.title.lowercased().contains(query)
            || (meeting.summary?.lowercased().contains(query) ?? false)
            || (meeting.rawTranscript?.lowercased().contains(query) ?? false)
        }
    }

    func deleteMeeting(_ meeting: Meeting, context: ModelContext) {
        logger.info("Deleting meeting: \(meeting.title)")
        context.delete(meeting)
        try? context.save()
    }
}
