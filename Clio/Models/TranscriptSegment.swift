import Foundation
import SwiftData

@Model
final class TranscriptSegment {
    var id: UUID
    var text: String
    var startTime: Double
    var endTime: Double
    var confidence: Float
    var source: TranscriptionSource
    var speakerLabel: String?
    var meeting: Meeting?

    init(
        id: UUID = UUID(),
        text: String,
        startTime: Double,
        endTime: Double,
        confidence: Float = 1.0,
        source: TranscriptionSource = .local
    ) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
        self.source = source
    }

    var formattedTimestamp: String {
        let minutes = Int(startTime) / 60
        let seconds = Int(startTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
