import SwiftUI
import SwiftData

struct SidebarView: View {
    @Bindable var viewModel: MeetingListViewModel
    @Binding var selectedMeeting: Meeting?
    var detailVM: MeetingDetailViewModel?
    var recordingVM: RecordingViewModel?
    @Environment(ServiceContainer.self) private var services
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meeting.createdAt, order: .reverse) private var meetings: [Meeting]
    @Query(sort: \MeetingFolder.sortOrder) private var folders: [MeetingFolder]
    @State private var selectedFolderID: PersistentIdentifier? // nil = All Meetings
    @State private var isCreatingFolder = false
    @State private var newFolderName = ""
    @State private var renamingFolder: MeetingFolder?
    @State private var renameFolderName = ""

    private var displayedMeetings: [Meeting] {
        let filtered = viewModel.filteredMeetings(meetings)
        guard let folderID = selectedFolderID else { return filtered }
        return filtered.filter { $0.folder?.persistentModelID == folderID }
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Upcoming Calendar Events
            if services.calendar.isAuthorized && !services.calendar.upcomingMeetings.isEmpty {
                CalendarSection(
                    meetings: services.calendar.upcomingMeetings,
                    recordingVM: recordingVM
                )
                Divider()
            }

            // MARK: - Folder Bar
            if !folders.isEmpty || isCreatingFolder {
                FolderBar(
                    folders: folders,
                    selectedFolderID: $selectedFolderID,
                    isCreatingFolder: $isCreatingFolder,
                    newFolderName: $newFolderName,
                    renamingFolder: $renamingFolder,
                    renameFolderName: $renameFolderName,
                    onCreateFolder: createFolder,
                    onDeleteFolder: deleteFolder,
                    onStartRename: startRename,
                    onCommitRename: commitRename
                )
                Divider()
            }

            // MARK: - Meeting Files
            List(selection: $selectedMeeting) {
                ForEach(displayedMeetings) { meeting in
                    MeetingRowView(meeting: meeting)
                        .tag(meeting)
                        .contextMenu {
                            if !folders.isEmpty {
                                Menu("Move to Folder") {
                                    Button("None (Remove from folder)") {
                                        meeting.folder = nil
                                        try? modelContext.save()
                                    }
                                    Divider()
                                    ForEach(folders) { folder in
                                        Button(folder.name) {
                                            meeting.folder = folder
                                            try? modelContext.save()
                                        }
                                    }
                                }
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                viewModel.deleteMeeting(meeting, context: modelContext)
                                if selectedMeeting == meeting {
                                    selectedMeeting = nil
                                }
                            }
                        }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search meetings")
            .overlay {
                if let detailVM, detailVM.isBulkExporting {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text(detailVM.bulkExportProgress ?? "Exporting...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                } else if meetings.isEmpty {
                    ContentUnavailableView(
                        "No Meetings Yet",
                        systemImage: "waveform",
                        description: Text("Start a recording to create your first meeting.")
                    )
                } else if displayedMeetings.isEmpty && !viewModel.searchText.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else if displayedMeetings.isEmpty && selectedFolderID != nil {
                    ContentUnavailableView(
                        "Empty Folder",
                        systemImage: "folder",
                        description: Text("Right-click a meeting to move it here.")
                    )
                }
            }
        }
        .navigationTitle("Clio")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    isCreatingFolder = true
                    newFolderName = ""
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                .help("Create a new folder")

                Menu {
                    ForEach(ExportDestination.allCases) { dest in
                        Button {
                            guard let detailVM else { return }
                            let completed = meetings.filter { $0.status == .completed }
                            Task { await detailVM.bulkExport(meetings: completed, to: dest) }
                        } label: {
                            Label(dest.rawValue, systemImage: dest.icon)
                        }
                    }
                } label: {
                    Label("Export All", systemImage: "arrow.up.doc")
                }
                .disabled(meetings.filter { $0.status == .completed }.isEmpty)
            }
        }
    }

    // MARK: - Folder Actions

    private func createFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let folder = MeetingFolder(name: name, sortOrder: folders.count)
        modelContext.insert(folder)
        try? modelContext.save()
        isCreatingFolder = false
        newFolderName = ""
    }

    private func deleteFolder(_ folder: MeetingFolder) {
        // Move meetings out of the folder before deleting
        for meeting in folder.meetings {
            meeting.folder = nil
        }
        if selectedFolderID == folder.persistentModelID {
            selectedFolderID = nil
        }
        modelContext.delete(folder)
        try? modelContext.save()
    }

    private func startRename(_ folder: MeetingFolder) {
        renamingFolder = folder
        renameFolderName = folder.name
    }

    private func commitRename() {
        guard let folder = renamingFolder else { return }
        let name = renameFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            folder.name = name
            try? modelContext.save()
        }
        renamingFolder = nil
        renameFolderName = ""
    }
}

// MARK: - Folder Bar

private struct FolderBar: View {
    let folders: [MeetingFolder]
    @Binding var selectedFolderID: PersistentIdentifier?
    @Binding var isCreatingFolder: Bool
    @Binding var newFolderName: String
    @Binding var renamingFolder: MeetingFolder?
    @Binding var renameFolderName: String
    let onCreateFolder: () -> Void
    let onDeleteFolder: (MeetingFolder) -> Void
    let onStartRename: (MeetingFolder) -> Void
    let onCommitRename: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    // "All" chip
                    FolderChip(
                        name: "All",
                        icon: "tray.full",
                        isSelected: selectedFolderID == nil,
                        action: { selectedFolderID = nil }
                    )

                    ForEach(folders) { folder in
                        if renamingFolder?.persistentModelID == folder.persistentModelID {
                            // Inline rename field
                            TextField("Folder name", text: $renameFolderName)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11))
                                .frame(width: 100)
                                .onSubmit { onCommitRename() }
                        } else {
                            FolderChip(
                                name: folder.name,
                                icon: "folder",
                                count: folder.meetings.count,
                                isSelected: selectedFolderID == folder.persistentModelID,
                                action: { selectedFolderID = folder.persistentModelID }
                            )
                            .contextMenu {
                                Button("Rename") { onStartRename(folder) }
                                Divider()
                                Button("Delete Folder", role: .destructive) { onDeleteFolder(folder) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            // New folder input
            if isCreatingFolder {
                HStack(spacing: 6) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    TextField("Folder name", text: $newFolderName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .onSubmit { onCreateFolder() }

                    Button("Add") { onCreateFolder() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button {
                        isCreatingFolder = false
                        newFolderName = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Folder Chip

private struct FolderChip: View {
    let name: String
    let icon: String
    var count: Int?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(name)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10))
                        .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Calendar Section

private struct CalendarSection: View {
    let meetings: [CalendarMeeting]
    let recordingVM: RecordingViewModel?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Label("Upcoming", systemImage: "calendar")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(meetings.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color(nsColor: .separatorColor).opacity(0.3)))
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Event list (max 5 shown)
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(meetings.prefix(5)) { meeting in
                        CalendarEventRow(
                            meeting: meeting,
                            onRecord: {
                                guard let recordingVM, !recordingVM.isRecording else { return }
                                Task { await recordingVM.startRecording(context: modelContext) }
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(maxHeight: 220)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Calendar Event Row

private struct CalendarEventRow: View {
    let meeting: CalendarMeeting
    let onRecord: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(meeting.formattedTime)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    if !meeting.attendees.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "person.2")
                                .font(.system(size: 9))
                            Text("\(meeting.attendees.count)")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            if meeting.isStartingSoon || meeting.isInProgress {
                Button(action: onRecord) {
                    Image(systemName: "record.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Record this meeting")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(meeting.isInProgress ? Color.green.opacity(0.08) :
                      meeting.isStartingSoon ? Color.orange.opacity(0.06) :
                      Color.clear)
        )
    }

    private var statusColor: Color {
        if meeting.isInProgress { return .green }
        if meeting.isStartingSoon { return .orange }
        return Color(nsColor: .tertiaryLabelColor)
    }
}
