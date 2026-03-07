import SwiftUI

struct TranscriptSegmentRow: View {
    let segment: TranscriptSegment

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(segment.formattedTimestamp)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 44, alignment: .trailing)

            VStack(alignment: .leading, spacing: 3) {
                if let speaker = segment.speakerLabel {
                    Text(speaker)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(speaker == "You" ? .blue : .purple)
                }
                Text(segment.text)
                    .font(.system(size: 15))
                    .lineSpacing(3)
                    .textSelection(.enabled)
            }
        }
    }
}
