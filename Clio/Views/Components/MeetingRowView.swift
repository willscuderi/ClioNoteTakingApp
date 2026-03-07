import SwiftUI

struct MeetingRowView: View {
    let meeting: Meeting

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(meeting.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                if meeting.status == .recording {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                }
            }

            HStack(spacing: 10) {
                Text(meeting.createdAt.relativeFormatted)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                if meeting.durationSeconds > 0 {
                    Text(meeting.formattedDuration)
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
            }

            if let summary = meeting.summary {
                Text(summary.prefix(100) + (summary.count > 100 ? "..." : ""))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .lineSpacing(2)
            }
        }
        .padding(.vertical, 6)
    }
}
