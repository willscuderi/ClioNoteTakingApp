import Foundation
import SwiftData

enum PreviewData {
    static func makeSampleMeetings() -> [Meeting] {
        let meeting1 = Meeting(
            title: "Weekly Standup",
            createdAt: Date().addingTimeInterval(-86400),
            status: .completed
        )
        meeting1.durationSeconds = 1800
        meeting1.summary = """
        ## Meeting Summary

        ### Key Points
        - Sprint velocity is on track for Q2 goals
        - Design review for the new dashboard is scheduled for Thursday
        - Backend migration to the new API is 70% complete

        ### Action Items
        - [ ] Review PR #142 for the auth module
        - [ ] Update project timeline in Notion
        - [ ] Schedule follow-up with design team
        """

        let segment1 = TranscriptSegment(
            text: "Good morning everyone. Let's start with a quick round of updates.",
            startTime: 0,
            endTime: 8
        )
        segment1.meeting = meeting1

        let segment2 = TranscriptSegment(
            text: "I've been working on the authentication module this week. The PR is up for review.",
            startTime: 8,
            endTime: 15
        )
        segment2.meeting = meeting1

        let segment3 = TranscriptSegment(
            text: "The backend migration is going well. We should be done by end of next week.",
            startTime: 15,
            endTime: 22
        )
        segment3.meeting = meeting1

        meeting1.segments = [segment1, segment2, segment3]

        let meeting2 = Meeting(
            title: "1:1 with Alex",
            createdAt: Date().addingTimeInterval(-172800),
            status: .completed
        )
        meeting2.durationSeconds = 2700
        meeting2.summary = "Discussed career goals and upcoming project assignments."

        let meeting3 = Meeting(
            title: "Product Planning",
            createdAt: Date().addingTimeInterval(-259200),
            status: .completed
        )
        meeting3.durationSeconds = 3600
        meeting3.summary = "Reviewed Q3 roadmap priorities and resource allocation."

        return [meeting1, meeting2, meeting3]
    }
}
