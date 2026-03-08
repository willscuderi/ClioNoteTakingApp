import SwiftUI
import SwiftData

struct ContentView: View {
    /// Shared RecordingViewModel passed from ClioApp. Falls back to creating its own.
    var recordingVM: RecordingViewModel?

    @Environment(ServiceContainer.self) private var services
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meeting.createdAt, order: .reverse) private var allMeetings: [Meeting]
    @Query(sort: \MeetingFolder.sortOrder) private var folders: [MeetingFolder]
    @State private var listVM = MeetingListViewModel()
    @State private var localRecordingVM: RecordingViewModel?
    @State private var detailVM: MeetingDetailViewModel?
    @State private var transcriptVM: TranscriptViewModel?
    @State private var selectedMeetingIDs: Set<PersistentIdentifier> = []
    @State private var selectedFolderID: PersistentIdentifier?
    @State private var isCreatingFolder = false
    @State private var panelController = RecordingPanelController()
    @State private var aiSearchVM: AISearchViewModel?
    @State private var showAISearch = false

    /// Use the shared VM if provided, otherwise the locally-created one.
    private var activeRecordingVM: RecordingViewModel? {
        recordingVM ?? localRecordingVM
    }

    /// When exactly one meeting is selected, return it for the detail view
    private var selectedMeeting: Meeting? {
        guard selectedMeetingIDs.count == 1,
              let id = selectedMeetingIDs.first else { return nil }
        return allMeetings.first { $0.persistentModelID == id }
    }

    /// All selected meetings resolved from IDs
    private var selectedMeetings: [Meeting] {
        allMeetings.filter { selectedMeetingIDs.contains($0.persistentModelID) }
    }

    /// Meetings filtered by search + folder (mirrors SidebarView logic for toolbar)
    private var displayedMeetings: [Meeting] {
        let filtered = listVM.filteredMeetings(allMeetings)
        guard let folderID = selectedFolderID else { return filtered }
        return filtered.filter { $0.folder?.persistentModelID == folderID }
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(
                viewModel: listVM,
                selectedMeetingIDs: $selectedMeetingIDs,
                detailVM: detailVM,
                recordingVM: activeRecordingVM,
                selectedFolderID: $selectedFolderID,
                isCreatingFolder: $isCreatingFolder
            )
        } detail: {
            if selectedMeetingIDs.count > 1, let detailVM {
                BulkSelectionView(
                    selectedMeetings: selectedMeetings,
                    detailVM: detailVM,
                    selectedMeetingIDs: $selectedMeetingIDs
                )
            } else if let meeting = selectedMeeting, let detailVM, let transcriptVM {
                MeetingContentView(
                    meeting: meeting,
                    detailVM: detailVM,
                    transcriptVM: transcriptVM
                )
                .id(meeting.persistentModelID)
            } else {
                EmptyMeetingView(recordingVM: activeRecordingVM)
            }
        }
        .frame(minWidth: 750, minHeight: 600)
        .toolbar {
            // Sidebar toolbar items (Select All, New Folder, Export)
            ToolbarItemGroup(placement: .navigation) {
                // Select All / Deselect All
                Button {
                    if selectedMeetingIDs.count == displayedMeetings.count && !displayedMeetings.isEmpty {
                        selectedMeetingIDs.removeAll()
                    } else {
                        selectedMeetingIDs = Set(displayedMeetings.map(\.persistentModelID))
                    }
                } label: {
                    Label(
                        selectedMeetingIDs.count == displayedMeetings.count && !displayedMeetings.isEmpty
                            ? "Deselect All" : "Select All",
                        systemImage: selectedMeetingIDs.count == displayedMeetings.count && !displayedMeetings.isEmpty
                            ? "checkmark.circle.fill" : "checkmark.circle"
                    )
                }
                .help(selectedMeetingIDs.count == displayedMeetings.count && !displayedMeetings.isEmpty
                    ? "Deselect all meetings" : "Select all meetings")

                Button {
                    isCreatingFolder = true
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                .help("Create a new folder")

                // Export: selected meetings or all
                Menu {
                    ForEach(ExportDestination.allCases) { dest in
                        Button {
                            guard let detailVM else { return }
                            let toExport: [Meeting]
                            if !selectedMeetingIDs.isEmpty {
                                toExport = selectedMeetings.filter { $0.status == .completed }
                            } else {
                                toExport = allMeetings.filter { $0.status == .completed }
                            }
                            guard !toExport.isEmpty else { return }
                            Task { await detailVM.bulkExport(meetings: toExport, to: dest) }
                        } label: {
                            Label(dest.rawValue, systemImage: dest.icon)
                        }
                    }
                } label: {
                    if !selectedMeetingIDs.isEmpty {
                        Label("Export (\(selectedMeetingIDs.count))", systemImage: "arrow.up.doc")
                    } else {
                        Label("Export All", systemImage: "arrow.up.doc")
                    }
                }
                .disabled(
                    !selectedMeetingIDs.isEmpty
                        ? selectedMeetings.filter { $0.status == .completed }.isEmpty
                        : allMeetings.filter { $0.status == .completed }.isEmpty
                )

                Button {
                    showAISearch = true
                } label: {
                    Label("Ask AI", systemImage: "sparkles")
                }
                .help("Ask AI about your meetings")
            }

            // Recording toolbar items
            ToolbarItemGroup(placement: .primaryAction) {
                if let vm = activeRecordingVM {
                    RecordingToolbarView(viewModel: vm)
                }
            }
        }
        .sheet(isPresented: $showAISearch) {
            if let aiSearchVM {
                AISearchView(
                    viewModel: aiSearchVM,
                    meetings: allMeetings,
                    focusedMeeting: selectedMeeting
                )
            }
        }
        .onAppear {
            if recordingVM == nil {
                localRecordingVM = RecordingViewModel(services: services)
            }
            detailVM = MeetingDetailViewModel(services: services)
            transcriptVM = TranscriptViewModel(services: services)
            aiSearchVM = AISearchViewModel(services: services)
        }
        .onChange(of: activeRecordingVM?.isRecording) { _, isRecording in
            guard let vm = activeRecordingVM else { return }
            if isRecording == true {
                panelController.show(recordingVM: vm, modelContext: modelContext)
            } else {
                panelController.hide()
            }
        }
        // Auto-open the recording meeting when recording starts
        .onChange(of: activeRecordingVM?.currentMeeting) { _, newMeeting in
            if let meeting = newMeeting {
                selectedMeetingIDs = [meeting.persistentModelID]
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
