import Testing
import Foundation
@testable import Clio

@Suite("TranscriptSegment Model Tests")
struct TranscriptSegmentTests {
    @Test("Segment formats timestamp correctly")
    func timestampFormatting() {
        let segment = TranscriptSegment(text: "Test", startTime: 125, endTime: 130)
        #expect(segment.formattedTimestamp == "2:05")

        let segment2 = TranscriptSegment(text: "Test", startTime: 0, endTime: 5)
        #expect(segment2.formattedTimestamp == "0:00")

        let segment3 = TranscriptSegment(text: "Test", startTime: 3661, endTime: 3670)
        #expect(segment3.formattedTimestamp == "61:01")
    }

    @Test("Segment initializes with defaults")
    func defaultInit() {
        let segment = TranscriptSegment(text: "Hello", startTime: 0, endTime: 5)
        #expect(segment.confidence == 1.0)
        #expect(segment.source == .local)
        #expect(segment.speakerLabel == nil)
    }
}
