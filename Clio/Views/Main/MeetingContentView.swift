import SwiftUI
import SwiftData

enum MeetingContentTab: String, CaseIterable, Identifiable {
    case transcript = "Transcript"
    case summary = "Summary"
    case notes = "Notes"

    var id: String { rawValue }
}

struct MeetingContentView: View {
    let meeting: Meeting
    @Bindable var detailVM: MeetingDetailViewModel
    @Bindable var transcriptVM: TranscriptViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: MeetingContentTab = .transcript

    var body: some View {
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
                    ProviderModelButton(viewModel: detailVM)

                    Button {
                        Task {
                            await detailVM.generateSummary(
                                for: meeting,
                                context: modelContext
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
                    SummaryTabView(meeting: meeting, isGenerating: detailVM.isGeneratingSummary)
                case .notes:
                    NotesTabView(meeting: meeting)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            Button("OK") { detailVM.successMessage = nil }
        } message: {
            Text(detailVM.successMessage ?? "")
        }
        .toolbar {
            ToolbarItemGroup(placement: .secondaryAction) {
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
