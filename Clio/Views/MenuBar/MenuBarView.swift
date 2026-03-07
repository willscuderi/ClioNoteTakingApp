import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Environment(ServiceContainer.self) private var services
    @Environment(\.modelContext) private var modelContext
    @State private var recordingVM: RecordingViewModel?

    var body: some View {
        VStack(spacing: 8) {
            if let recordingVM {
                if recordingVM.isRecording {
                    // Recording state
                    HStack {
                        Circle()
                            .fill(recordingVM.isPaused ? .orange : .red)
                            .frame(width: 8, height: 8)
                        Text(recordingVM.isPaused ? "Paused" : "Recording")
                            .font(.headline)
                        Spacer()
                        Text(recordingVM.elapsedTime.durationFormatted)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    Button {
                        Task { await recordingVM.togglePause() }
                    } label: {
                        Label(
                            recordingVM.isPaused ? "Resume" : "Pause",
                            systemImage: recordingVM.isPaused ? "play.fill" : "pause.fill"
                        )
                    }

                    Button {
                        Task { await recordingVM.stopRecording(context: modelContext) }
                    } label: {
                        Label("Stop Recording", systemImage: "stop.fill")
                    }

                    Button {
                        recordingVM.addBookmark(context: modelContext)
                    } label: {
                        Label("Add Bookmark", systemImage: "bookmark.fill")
                    }
                } else {
                    // Idle state
                    Text("Clio")
                        .font(.headline)

                    // Meeting app detected prompt
                    if services.meetingDetector.shouldPromptRecording,
                       let appName = services.meetingDetector.detectedMeetingApp {
                        MeetingDetectedBanner(
                            appName: appName,
                            onRecord: {
                                Task { await recordingVM.startRecording(context: modelContext) }
                                services.meetingDetector.dismissPrompt()
                            },
                            onDismiss: {
                                services.meetingDetector.dismissPrompt()
                            }
                        )
                    }

                    // Upcoming meeting from calendar
                    if let next = services.calendar.nextMeeting {
                        UpcomingMeetingRow(
                            meeting: next,
                            onRecord: {
                                Task { await recordingVM.startRecording(context: modelContext) }
                            }
                        )
                    }

                    Divider()

                    Button {
                        Task { await recordingVM.startRecording(context: modelContext) }
                    } label: {
                        Label("Start Recording", systemImage: "record.circle")
                    }
                }

                if let error = recordingVM.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(3)
                        .padding(.horizontal, 4)
                }
            }

            Divider()

            Button("Open Clio") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                if let window = NSApplication.shared.windows.first(where: { $0.title == "Clio" || $0 is NSPanel == false }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(8)
        .frame(width: 240)
        .onAppear {
            recordingVM = RecordingViewModel(services: services)
        }
    }
}

// MARK: - Meeting Detected Banner

struct MeetingDetectedBanner: View {
    let appName: String
    let onRecord: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "video.fill")
                    .foregroundStyle(Color.accentColor)
                    .font(.caption)
                Text("\(appName) detected")
                    .font(.caption.weight(.medium))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button(action: onRecord) {
                Label("Start Recording", systemImage: "record.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.08)))
    }
}

// MARK: - Upcoming Meeting Row

struct UpcomingMeetingRow: View {
    let meeting: CalendarMeeting
    let onRecord: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(meeting.isInProgress ? .green : (meeting.isStartingSoon ? .orange : .secondary))
                    .frame(width: 6, height: 6)
                Text(meeting.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }

            HStack {
                Text(meeting.formattedTime)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                if meeting.isStartingSoon || meeting.isInProgress {
                    Button("Record", action: onRecord)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }
}
