import Testing
import Foundation
@testable import Clio

@Suite("MarkdownExportService Tests")
struct MarkdownExportServiceTests {
    @Test("Builds markdown with title and date")
    func basicMarkdown() {
        let service = MarkdownExportService()
        let meeting = Meeting(title: "Test Meeting")
        meeting.status = .completed
        meeting.durationSeconds = 1800

        let markdown = service.buildMarkdown(for: meeting)
        #expect(markdown.contains("# Test Meeting"))
        #expect(markdown.contains("**Duration:** 30:00"))
    }

    @Test("Includes summary when present")
    func withSummary() {
        let service = MarkdownExportService()
        let meeting = Meeting(title: "Test")
        meeting.summary = "This is the summary"

        let markdown = service.buildMarkdown(for: meeting)
        #expect(markdown.contains("This is the summary"))
    }

    @Test("Includes transcript segments in order")
    func withSegments() {
        let service = MarkdownExportService()
        let meeting = Meeting(title: "Test")
        let seg1 = TranscriptSegment(text: "First", startTime: 0, endTime: 5)
        let seg2 = TranscriptSegment(text: "Second", startTime: 5, endTime: 10)
        seg1.meeting = meeting
        seg2.meeting = meeting
        meeting.segments = [seg2, seg1]

        let markdown = service.buildMarkdown(for: meeting)
        let firstIndex = markdown.range(of: "First")!.lowerBound
        let secondIndex = markdown.range(of: "Second")!.lowerBound
        #expect(firstIndex < secondIndex)
    }
}
