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

                    Divider()

                    Button {
                        Task { await recordingVM.startRecording(context: modelContext) }
                    } label: {
                        Label("Start Recording", systemImage: "record.circle")
                    }
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
        .frame(width: 220)
        .onAppear {
            recordingVM = RecordingViewModel(services: services)
        }
    }
}
