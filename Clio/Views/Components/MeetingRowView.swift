import SwiftUI

struct MeetingRowView: View {
    let meeting: Meeting

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(meeting.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if meeting.status == .recording {
                    Circle()
                        .fill(.red)
                        .frame(width: 6, height: 6)
                }
            }

            HStack(spacing: 8) {
                Text(meeting.createdAt.relativeFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if meeting.durationSeconds > 0 {
                    Text(meeting.formattedDuration)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if let summary = meeting.summary {
                Text(summary.prefix(80) + (summary.count > 80 ? "..." : ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
