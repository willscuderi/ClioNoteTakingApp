import SwiftUI

struct MeetingRowView: View {
    let meeting: Meeting

    var body: some View {
        HStack(spacing: 0) {
            // Status color strip
            RoundedRectangle(cornerRadius: 2)
                .fill(statusColor)
                .frame(width: 3, height: 44)
                .padding(.trailing, 8)

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
        }
        .padding(.vertical, 6)
    }

    private var statusColor: Color {
        switch meeting.status {
        case .recording: return .red
        case .paused: return .orange
        case .completed: return .green.opacity(0.6)
        case .processing: return .blue.opacity(0.6)
        case .failed: return .gray.opacity(0.4)
        }
    }
}
