import SwiftUI
import SwiftData

struct MeetingDetailView: View {
    let meeting: Meeting
    @Bindable var viewModel: MeetingDetailViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(meeting.title)
                        .font(.title)
                        .fontWeight(.bold)
                    HStack(spacing: 12) {
                        Label(meeting.createdAt.meetingDateFormatted, systemImage: "calendar")
                        Label(meeting.formattedDuration, systemImage: "clock")
                        StatusBadge(status: meeting.status)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Divider()

                // Summary section
                if let summary = meeting.summary {
                    Text(summary)
                        .textSelection(.enabled)
                } else if meeting.status == .completed {
                    VStack(spacing: 8) {
                        Text("No summary generated yet.")
                            .foregroundStyle(.secondary)
                        HStack {
                            Picker("Provider", selection: $viewModel.selectedLLMProvider) {
                                ForEach(LLMProvider.allCases) { provider in
                                    Text(provider.displayName).tag(provider)
                                }
                            }
                            .frame(width: 150)

                            Button("Generate Summary") {
                                Task {
                                    await viewModel.generateSummary(
                                        for: meeting,
                                        context: modelContext
                                    )
                                }
                            }
                            .disabled(viewModel.isGeneratingSummary)
                        }
                        if viewModel.isGeneratingSummary {
                            ProgressView("Generating summary...")
                        }
                    }
                }

                // Notes section
                if let notes = meeting.notes, !notes.isEmpty {
                    Divider()
                    Text("Notes")
                        .font(.headline)
                    Text(notes)
                        .textSelection(.enabled)
                }

                // Bookmarks section
                if !meeting.bookmarks.isEmpty {
                    Divider()
                    Text("Bookmarks")
                        .font(.headline)
                    ForEach(meeting.bookmarks.sorted { $0.timestamp < $1.timestamp }) { bookmark in
                        HStack {
                            Image(systemName: "bookmark.fill")
                                .foregroundStyle(.orange)
                            Text(bookmark.formattedTimestamp)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            Text(bookmark.label.isEmpty ? "Bookmark" : bookmark.label)
                        }
                    }
                }

                // Error display
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItemGroup(placement: .secondaryAction) {
                Menu("Export") {
                    Button("Markdown") {
                        viewModel.exportMarkdown(meeting: meeting)
                    }
                    Button("Apple Notes") {
                        Task { await viewModel.exportToAppleNotes(meeting: meeting) }
                    }
                    Button("Notion") {
                        Task { await viewModel.exportToNotion(meeting: meeting) }
                    }
                }
            }
        }
    }
}

struct StatusBadge: View {
    let status: MeetingStatus

    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status {
        case .recording: .red.opacity(0.15)
        case .paused: .orange.opacity(0.15)
        case .processing: .blue.opacity(0.15)
        case .completed: .green.opacity(0.15)
        case .failed: .red.opacity(0.15)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .recording: .red
        case .paused: .orange
        case .processing: .blue
        case .completed: .green
        case .failed: .red
        }
    }
}
