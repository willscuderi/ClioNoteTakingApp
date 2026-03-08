import SwiftUI
import SwiftData

/// Shown on launch when orphaned recordings are detected (meetings stuck in .recording/.paused status).
/// Gives the user the choice to recover their transcript or discard it.
struct CrashRecoveryView: View {
    let meetings: [Meeting]
    let recovery: CrashRecoveryService
    let onDismiss: () -> Void
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)

                Text("Recording Interrupted")
                    .font(.system(size: 18, weight: .semibold))

                Text("It looks like Clio was closed during \(meetings.count == 1 ? "a meeting" : "\(meetings.count) meetings"). We recovered your transcript\(meetings.count == 1 ? "" : "s").")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            // Meeting list
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(meetings, id: \.persistentModelID) { meeting in
                        RecoveryMeetingRow(meeting: meeting)
                    }
                }
                .padding(16)
            }
            .frame(maxHeight: 200)

            Divider()

            // Actions
            HStack(spacing: 12) {
                Button(role: .destructive) {
                    for meeting in meetings {
                        recovery.discardMeeting(meeting, context: modelContext)
                    }
                    onDismiss()
                } label: {
                    Text("Discard")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    for meeting in meetings {
                        recovery.recoverMeeting(meeting, context: modelContext)
                    }
                    onDismiss()
                } label: {
                    Text("Recover \(meetings.count == 1 ? "Meeting" : "All")")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(width: 440)
    }
}

// MARK: - Recovery Meeting Row

private struct RecoveryMeetingRow: View {
    let meeting: Meeting

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.system(size: 14))
                .foregroundStyle(.orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(meeting.createdAt, style: .date)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    if !meeting.segments.isEmpty {
                        Text("\(meeting.segments.count) segment\(meeting.segments.count == 1 ? "" : "s") recovered")
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                    } else {
                        Text("No transcript data")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
    }
}
