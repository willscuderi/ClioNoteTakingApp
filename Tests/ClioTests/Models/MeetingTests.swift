import Testing
import Foundation
@testable import Clio

@Suite("Meeting Model Tests")
struct MeetingTests {
    @Test("Meeting initializes with default values")
    func defaultInit() {
        let meeting = Meeting()
        #expect(meeting.status == .recording)
        #expect(meeting.segments.isEmpty)
        #expect(meeting.bookmarks.isEmpty)
        #expect(meeting.durationSeconds == 0)
        #expect(meeting.summary == nil)
    }

    @Test("Meeting formats duration correctly")
    func durationFormatting() {
        let meeting = Meeting()
        meeting.durationSeconds = 3661 // 1h 1m 1s
        #expect(meeting.formattedDuration == "1:01:01")

        meeting.durationSeconds = 125 // 2m 5s
        #expect(meeting.formattedDuration == "2:05")

        meeting.durationSeconds = 0
        #expect(meeting.formattedDuration == "0:00")
    }

    @Test("Meeting builds full transcript from segments")
    func fullTranscript() {
        let meeting = Meeting(title: "Test")
        let seg1 = TranscriptSegment(text: "Hello", startTime: 0, endTime: 5)
        let seg2 = TranscriptSegment(text: "World", startTime: 5, endTime: 10)
        seg1.meeting = meeting
        seg2.meeting = meeting
        meeting.segments = [seg2, seg1] // intentionally out of order

        #expect(meeting.fullTranscript == "Hello World")
    }
}
