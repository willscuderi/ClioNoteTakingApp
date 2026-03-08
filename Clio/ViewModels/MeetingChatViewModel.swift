import Foundation
import os

/// Per-meeting AI chat. Builds context from a single meeting's summary + transcript
/// and lets the user ask follow-up questions inline at the bottom of the meeting detail.
@MainActor
@Observable
final class MeetingChatViewModel {
    struct ChatMessage: Identifiable {
        let id = UUID()
        let question: String
        var answer: String
        var isLoading: Bool
        var errorMessage: String?
    }

    var messages: [ChatMessage] = []
    var currentQuestion: String = ""
    var isAsking: Bool = false

    var selectedLLMProvider: LLMProvider = .ollama {
        didSet { selectedModelID = selectedLLMProvider.defaultModel.id }
    }
    var selectedModelID: String = LLMProvider.ollama.defaultModel.id

    var resolvedModel: LLMModel {
        selectedLLMProvider.availableModels.first(where: { $0.id == selectedModelID })
            ?? selectedLLMProvider.defaultModel
    }

    private let services: ServiceContainer
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "MeetingChat")

    init(services: ServiceContainer) {
        self.services = services
    }

    func ask(about meeting: Meeting) async {
        let trimmed = currentQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isAsking else { return }

        isAsking = true
        var message = ChatMessage(question: trimmed, answer: "", isLoading: true)
        messages.append(message)
        currentQuestion = ""

        let index = messages.count - 1

        do {
            let context = buildContext(from: meeting)
            logger.info("Meeting chat: \(context.count) chars context for \"\(trimmed.prefix(40))\"")

            let answer = try await services.llm.askQuestion(
                question: trimmed,
                context: context,
                provider: selectedLLMProvider,
                model: resolvedModel
            )

            messages[index].answer = answer
            messages[index].isLoading = false
        } catch {
            messages[index].errorMessage = error.localizedDescription
            messages[index].isLoading = false
            logger.error("Meeting chat failed: \(error.localizedDescription)")
        }

        isAsking = false
    }

    // MARK: - Context

    private func buildContext(from meeting: Meeting) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        var context = "## \(meeting.title)\n"
        context += "Date: \(dateFormatter.string(from: meeting.createdAt))\n"
        context += "Duration: \(meeting.formattedDuration)\n\n"

        if let summary = meeting.summary, !summary.isEmpty {
            context += "### Summary\n\(summary)\n\n"
        }

        let transcript = meeting.fullTranscript
        if !transcript.isEmpty {
            let remaining = 40000 - context.count - 100
            if remaining > 500 {
                context += "### Transcript\n\(String(transcript.prefix(remaining)))\n"
            }
        }

        return context
    }
}
