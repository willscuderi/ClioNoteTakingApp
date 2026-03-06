import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(ServiceContainer.self) private var services
    @Environment(\.modelContext) private var modelContext
    @State private var listVM = MeetingListViewModel()
    @State private var recordingVM: RecordingViewModel?
    @State private var detailVM: MeetingDetailViewModel?
    @State private var transcriptVM: TranscriptViewModel?
    @State private var selectedMeeting: Meeting?
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                viewModel: listVM,
                selectedMeeting: $selectedMeeting
            )
        } content: {
            if let meeting = selectedMeeting, let detailVM {
                MeetingDetailView(meeting: meeting, viewModel: detailVM)
            } else {
                EmptyMeetingView(recordingVM: recordingVM)
            }
        } detail: {
            if let meeting = selectedMeeting, let transcriptVM {
                TranscriptPaneView(meeting: meeting, viewModel: transcriptVM)
            } else {
                Text("Select a meeting to view its transcript")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if let recordingVM {
                    RecordingToolbarView(viewModel: recordingVM)
                }
            }
        }
        .onAppear {
            recordingVM = RecordingViewModel(services: services)
            detailVM = MeetingDetailViewModel(services: services)
            transcriptVM = TranscriptViewModel(services: services)
        }
    }
}

struct EmptyMeetingView: View {
    let recordingVM: RecordingViewModel?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("No Meeting Selected")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Select a meeting from the sidebar or start a new recording.")
                .foregroundStyle(.tertiary)

            if let recordingVM, !recordingVM.isRecording {
                Button("Start Recording") {
                    Task {
                        await recordingVM.startRecording(context: modelContext)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct RecordingToolbarView: View {
    let viewModel: RecordingViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if viewModel.isRecording {
            HStack(spacing: 8) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)

                Text(viewModel.elapsedTime.durationFormatted)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Button {
                    Task { await viewModel.togglePause() }
                } label: {
                    Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                }

                Button {
                    Task { await viewModel.stopRecording(context: modelContext) }
                } label: {
                    Image(systemName: "stop.fill")
                        .foregroundStyle(.red)
                }

                Button {
                    viewModel.addBookmark(context: modelContext)
                } label: {
                    Image(systemName: "bookmark.fill")
                }
                .help("Add bookmark")
            }
        } else {
            Button {
                Task { await viewModel.startRecording(context: modelContext) }
            } label: {
                Label("Record", systemImage: "record.circle")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Meeting.self, inMemory: true)
        .environment(ServiceContainer.makeDefault())
}
