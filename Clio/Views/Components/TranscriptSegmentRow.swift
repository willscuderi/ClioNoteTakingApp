import SwiftUI

struct TranscriptSegmentRow: View {
    let segment: TranscriptSegment

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(segment.formattedTimestamp)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                if let speaker = segment.speakerLabel {
                    Text(speaker)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }
                Text(segment.text)
                    .font(.body)
                    .textSelection(.enabled)
            }
        }
    }
}
