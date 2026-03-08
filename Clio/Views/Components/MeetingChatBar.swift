import SwiftUI

/// Inline chat bar that appears at the bottom of a completed meeting's detail view.
/// Users can ask questions about the specific meeting and get AI-powered answers.
struct MeetingChatBar: View {
    @Bindable var viewModel: MeetingChatViewModel
    let meeting: Meeting

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            // MARK: - Chat History (scrollable, max 200pt)
            if !viewModel.messages.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                chatMessageView(message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .frame(maxHeight: 200)
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let lastID = viewModel.messages.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()
            }

            // MARK: - Input Bar
            HStack(spacing: 8) {
                ProviderModelButton(
                    selectedProvider: $viewModel.selectedLLMProvider,
                    selectedModelID: $viewModel.selectedModelID
                )
                .controlSize(.small)

                TextField("Ask about this meeting...", text: $viewModel.currentQuestion)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit {
                        Task { await viewModel.ask(about: meeting) }
                    }

                Button {
                    Task { await viewModel.ask(about: meeting) }
                } label: {
                    if viewModel.isAsking {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(
                                viewModel.currentQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color.secondary : Color.accentColor
                            )
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.currentQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isAsking)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        }
    }

    // MARK: - Chat Message View

    @ViewBuilder
    private func chatMessageView(_ message: MeetingChatViewModel.ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Question
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Text(message.question)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
            }

            // Answer
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(.purple)

                if message.isLoading {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Thinking...")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                } else if let error = message.errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                } else {
                    Text(message.answer)
                        .font(.system(size: 13))
                        .lineSpacing(3)
                        .textSelection(.enabled)
                }
            }
            .padding(.leading, 4)
        }
    }
}
