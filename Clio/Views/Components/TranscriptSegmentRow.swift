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
                        .foregroundStyle(speakerColor(for: speaker))
                }
                Text(segment.text)
                    .font(.system(size: 15))
                    .lineSpacing(3)
                    .textSelection(.enabled)
            }
        }
    }

    /// Maps speaker labels to distinct colors for visual differentiation.
    private func speakerColor(for speaker: String) -> Color {
        switch speaker {
        case "You":         return .blue
        case "Remote":      return .purple
        case "Speaker A":   return .blue
        case "Speaker B":   return .purple
        case "Speaker C":   return .green
        case "Speaker D":   return .orange
        case "Speaker E":   return .pink
        case "Speaker F":   return .teal
        default:
            // Cycle through palette for Speaker G, H, etc.
            let palette: [Color] = [.blue, .purple, .green, .orange, .pink, .teal, .indigo, .mint]
            let hash = abs(speaker.hashValue)
            return palette[hash % palette.count]
        }
    }
}
