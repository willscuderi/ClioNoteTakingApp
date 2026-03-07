import SwiftUI
import SwiftData

struct ContentView: View {
    /// Shared RecordingViewModel passed from ClioApp. Falls back to creating its own.
    var recordingVM: RecordingViewModel?

    @Environment(ServiceContainer.self) private var services
    @Environment(\.modelContext) private var modelContext
    @State private var listVM = MeetingListViewModel()
    @State private var localRecordingVM: RecordingViewModel?
    @State private var detailVM: MeetingDetailViewModel?
    @State private var transcriptVM: TranscriptViewModel?
    @State private var selectedMeeting: Meeting?
    @State private var panelController = RecordingPanelController()

    /// Use the shared VM if provided, otherwise the locally-created one.
    private var activeRecordingVM: RecordingViewModel? {
        recordingVM ?? localRecordingVM
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(
                viewModel: listVM,
                selectedMeeting: $selectedMeeting,
                detailVM: detailVM,
                recordingVM: activeRecordingVM
            )
        } detail: {
            if let meeting = selectedMeeting, let detailVM, let transcriptVM {
                MeetingContentView(
                    meeting: meeting,
                    detailVM: detailVM,
                    transcriptVM: transcriptVM
                )
            } else {
                EmptyMeetingView(recordingVM: activeRecordingVM)
            }
        }
        .frame(minWidth: 750, minHeight: 600)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if let vm = activeRecordingVM {
                    RecordingToolbarView(viewModel: vm)
                }
            }
        }
        .onAppear {
            if recordingVM == nil {
                localRecordingVM = RecordingViewModel(services: services)
            }
            detailVM = MeetingDetailViewModel(services: services)
            transcriptVM = TranscriptViewModel(services: services)
        }
        .onChange(of: activeRecordingVM?.isRecording) { _, isRecording in
            guard let vm = activeRecordingVM else { return }
            if isRecording == true {
                panelController.show(recordingVM: vm, modelContext: modelContext)
            } else {
                panelController.hide()
            }
        }
    }
}

struct EmptyMeetingView: View {
    let recordingVM: RecordingViewModel?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 72))
                .foregroundStyle(.quaternary)
            Text("No Meeting Selected")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Select a meeting from the sidebar or start a new recording.")
                .font(.system(size: 15))
                .foregroundStyle(.tertiary)

            if let recordingVM, !recordingVM.isRecording {
                Button {
                    Task {
                        await recordingVM.startRecording(context: modelContext)
                    }
                } label: {
                    Label("Start Recording", systemImage: "record.circle")
                        .font(.system(size: 15, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if let error = recordingVM.errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                        .padding(.top, 4)
                }
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

                if let status = viewModel.transcriptionStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

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
        } else if viewModel.isPostProcessing {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                if let status = viewModel.postProcessingStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

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
