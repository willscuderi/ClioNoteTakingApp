import SwiftUI
import SwiftData

enum MeetingContentTab: String, CaseIterable, Identifiable {
    case transcript = "Transcript"
    case summary = "Summary"
    case actionItems = "Action Items"
    case notes = "Notes"

    var id: String { rawValue }
}

struct MeetingContentView: View {
    let meeting: Meeting
    @Bindable var detailVM: MeetingDetailViewModel
    @Bindable var transcriptVM: TranscriptViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(ServiceContainer.self) private var services
    @State private var selectedTab: MeetingContentTab = .transcript
    @State private var chatVM: MeetingChatViewModel?
    @State private var selectedTemplate: SummaryTemplate = SummaryTemplate.builtIn[0]

    var body: some View {
        // Show split view during active recording
        if meeting.status == .recording || meeting.status == .paused {
            RecordingSplitView(meeting: meeting, transcriptVM: transcriptVM)
        } else {
            normalContentView
        }
    }

    @ViewBuilder
    private var normalContentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Header
            VStack(alignment: .leading, spacing: 8) {
                EditableTitleView(meeting: meeting)

                HStack(spacing: 16) {
                    Label(meeting.createdAt.meetingDateFormatted, systemImage: "calendar")
                    Label(meeting.formattedDuration, systemImage: "clock")
                    StatusBadge(status: meeting.status)
                }
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // MARK: - Tab Bar + Actions
            HStack(spacing: 12) {
                Picker("", selection: $selectedTab) {
                    ForEach(MeetingContentTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 280)

                Spacer()

                if meeting.status == .completed {
                    ProviderModelButton(selectedProvider: $detailVM.selectedLLMProvider, selectedModelID: $detailVM.selectedModelID)

                    Button {
                        Task {
                            await detailVM.generateSummary(
                                for: meeting,
                                context: modelContext,
                                template: selectedTemplate
                            )
                        }
                    } label: {
                        if detailVM.isGeneratingSummary {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Generating...")
                                    .font(.system(size: 13))
                            }
                        } else {
                            Text(meeting.summary != nil ? "Regenerate" : "Generate Summary")
                                .font(.system(size: 13))
                        }
                    }
                    .buttonStyle(HoverAccentButtonStyle())
                    .disabled(detailVM.isGeneratingSummary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)

            Divider()

            // MARK: - Tab Content
            Group {
                switch selectedTab {
                case .transcript:
                    TranscriptTabView(meeting: meeting, viewModel: transcriptVM)
                case .summary:
                    SummaryTabView(meeting: meeting, isGenerating: detailVM.isGeneratingSummary, streamedSummary: detailVM.streamedSummary, selectedTemplate: $selectedTemplate)
                case .actionItems:
                    ActionItemsTabView(meeting: meeting)
                case .notes:
                    NotesTabView(meeting: meeting)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // MARK: - Per-Meeting Chat Bar
            if meeting.status == .completed, let chatVM {
                MeetingChatBar(viewModel: chatVM, meeting: meeting)
            }
        }
        .onAppear {
            if chatVM == nil {
                chatVM = MeetingChatViewModel(services: services)
            }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { detailVM.errorMessage != nil },
            set: { if !$0 { detailVM.errorMessage = nil } }
        )) {
            Button("OK") { detailVM.clearMessages() }
        } message: {
            Text(detailVM.errorMessage ?? "")
        }
        .alert("Export Complete", isPresented: Binding(
            get: { detailVM.successMessage != nil },
            set: { if !$0 { detailVM.successMessage = nil } }
        )) {
            if let urlString = detailVM.lastExportURL,
               let url = URL(string: urlString) {
                Button("Open in Notion") {
                    NSWorkspace.shared.open(url)
                    detailVM.lastExportURL = nil
                    detailVM.successMessage = nil
                }
                Button("OK") {
                    detailVM.lastExportURL = nil
                    detailVM.successMessage = nil
                }
            } else {
                Button("OK") { detailVM.successMessage = nil }
            }
        } message: {
            Text(detailVM.successMessage ?? "")
        }
        .toolbar {
            ToolbarItemGroup(placement: .secondaryAction) {
                ShareLink(
                    item: services.export.buildMarkdownContent(meeting: meeting),
                    subject: Text(meeting.title),
                    message: Text("Meeting notes from \(meeting.title)")
                ) {
                    Label("Share", systemImage: "square.and.arrow.up.on.square")
                }

                Menu {
                    Button {
                        detailVM.exportMarkdownWithSavePanel(meeting: meeting)
                    } label: {
                        Label("Markdown (Save As...)", systemImage: "doc.text")
                    }
                    Button {
                        Task { await detailVM.exportToAppleNotes(meeting: meeting) }
                    } label: {
                        Label("Apple Notes", systemImage: "note.text")
                    }
                    Button {
                        Task { await detailVM.exportToNotion(meeting: meeting) }
                    } label: {
                        Label("Notion", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        detailVM.exportToObsidian(meeting: meeting)
                    } label: {
                        Label("Obsidian", systemImage: "diamond")
                    }
                    Button {
                        detailVM.exportToOneNote(meeting: meeting)
                    } label: {
                        Label("OneNote", systemImage: "book.closed")
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }
        }
    }
}

// MARK: - Hover Button Style

/// Grey normally, accent blue on hover
struct HoverAccentButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .foregroundStyle(isHovered ? .white : .primary)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.accentColor : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isHovered ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .onHover { hovering in
                isHovered = hovering
            }
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}
