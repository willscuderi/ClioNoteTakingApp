import SwiftUI
import SwiftData

struct AISearchView: View {
    @Bindable var viewModel: AISearchViewModel
    let meetings: [Meeting]
    /// When set, AI searches only this meeting instead of all meetings
    var focusedMeeting: Meeting?
    @Environment(\.dismiss) private var dismiss

    private var searchMeetings: [Meeting] {
        if let focused = focusedMeeting {
            return [focused]
        }
        return meetings
    }

    private var placeholderText: String {
        if let focused = focusedMeeting {
            return "Ask about \"\(focused.title)\"..."
        }
        return "Ask a question about your meetings..."
    }

    private var headerTitle: String {
        if focusedMeeting != nil {
            return "Ask AI about this meeting"
        }
        return "Ask AI"
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            HStack {
                Label(headerTitle, systemImage: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                ProviderModelButton(
                    selectedProvider: $viewModel.selectedLLMProvider,
                    selectedModelID: $viewModel.selectedModelID
                )
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            // MARK: - Question Input
            HStack(spacing: 10) {
                TextField(placeholderText, text: $viewModel.question)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 15))
                    .onSubmit {
                        Task { await viewModel.search(meetings: searchMeetings) }
                    }

                Button {
                    Task { await viewModel.search(meetings: searchMeetings) }
                } label: {
                    if viewModel.isSearching {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSearching)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()

            // MARK: - Answer Area
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.isSearching && viewModel.answer.isEmpty {
                        // Loading state
                        VStack(spacing: 12) {
                            Spacer(minLength: 40)
                            ProgressView()
                            Text(focusedMeeting != nil ? "Analyzing this meeting..." : "Searching across your meetings...")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 40)
                        }
                        .frame(maxWidth: .infinity)
                    } else if let error = viewModel.errorMessage {
                        // Error state
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 32))
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else if !viewModel.answer.isEmpty {
                        // Answer
                        Text(viewModel.answer)
                            .font(.system(size: 15))
                            .lineSpacing(4)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        // Empty state with example questions
                        emptyStateView
                    }
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 620, height: 500)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 20)

            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)

            if focusedMeeting != nil {
                Text("Ask questions about this meeting")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("AI will analyze the transcript and summary to answer your question.")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            } else {
                Text("Ask questions about your meetings")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("AI will search across all your meeting transcripts and summaries to find answers.")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Try asking:")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                ForEach(exampleQuestions, id: \.self) { example in
                    Button {
                        viewModel.question = example
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text(example)
                                .font(.system(size: 13))
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 8)

            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity)
    }

    private var exampleQuestions: [String] {
        if focusedMeeting != nil {
            return [
                "What were the key decisions?",
                "What action items were discussed?",
                "Summarize the main topics",
                "What was agreed upon?"
            ]
        }
        return [
            "What action items were assigned to me?",
            "What decisions were made about the project timeline?",
            "Summarize all discussions about the budget",
            "What did we agree on in the last standup?"
        ]
    }
}
