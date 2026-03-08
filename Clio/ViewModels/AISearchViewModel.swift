import Foundation
import SwiftData
import os

@MainActor
@Observable
final class AISearchViewModel {
    var question: String = ""
    var answer: String = ""
    var isSearching = false
    var errorMessage: String?

    var selectedLLMProvider: LLMProvider = .ollama {
        didSet { selectedModelID = selectedLLMProvider.defaultModel.id }
    }
    var selectedModelID: String = LLMProvider.ollama.defaultModel.id

    var resolvedModel: LLMModel {
        selectedLLMProvider.availableModels.first(where: { $0.id == selectedModelID })
            ?? selectedLLMProvider.defaultModel
    }

    private let services: ServiceContainer
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "AISearch")

    init(services: ServiceContainer) {
        self.services = services
    }

    func search(meetings: [Meeting]) async {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isSearching else { return }

        isSearching = true
        errorMessage = nil
        answer = ""

        do {
            let relevantMeetings = scoreMeetings(meetings, for: trimmed)
            guard !relevantMeetings.isEmpty else {
                answer = "No meetings found with relevant content. Try a different question."
                isSearching = false
                return
            }

            let context = buildContext(from: relevantMeetings)
            logger.info("AI Search: \(relevantMeetings.count) meetings, \(context.count) chars context")

            answer = try await services.llm.askQuestion(
                question: trimmed,
                context: context,
                provider: selectedLLMProvider,
                model: resolvedModel
            )
        } catch {
            errorMessage = error.localizedDescription
            logger.error("AI Search failed: \(error.localizedDescription)")
        }

        isSearching = false
    }

    // MARK: - Meeting Scoring

    /// Score meetings by keyword relevance, return top 10
    private func scoreMeetings(_ meetings: [Meeting], for query: String) -> [Meeting] {
        let keywords = extractKeywords(from: query)
        guard !keywords.isEmpty else { return Array(meetings.prefix(10)) }

        let scored: [(meeting: Meeting, score: Int)] = meetings
            .filter { $0.status == .completed }
            .map { meeting in
                var score = 0
                let titleLower = meeting.title.lowercased()
                let summaryLower = (meeting.summary ?? "").lowercased()
                let transcriptLower = meeting.fullTranscript.lowercased()

                for keyword in keywords {
                    // Title matches weighted 3x
                    if titleLower.contains(keyword) { score += 3 }
                    // Summary matches weighted 2x
                    if summaryLower.contains(keyword) { score += 2 }
                    // Transcript matches weighted 1x
                    if transcriptLower.contains(keyword) { score += 1 }
                }

                return (meeting, score)
            }
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }

        // If no keyword matches, return most recent meetings
        if scored.isEmpty {
            return Array(meetings.filter { $0.status == .completed }
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(10))
        }

        return Array(scored.prefix(10).map(\.meeting))
    }

    /// Extract meaningful keywords from a question
    private func extractKeywords(from query: String) -> [String] {
        let stopWords: Set<String> = [
            "what", "when", "where", "who", "which", "how", "why",
            "was", "were", "did", "does", "do", "is", "are", "am",
            "the", "a", "an", "and", "or", "but", "in", "on", "at",
            "to", "for", "of", "with", "by", "from", "as", "into",
            "about", "that", "this", "it", "my", "we", "they", "our",
            "can", "will", "would", "could", "should", "have", "has",
            "had", "been", "being", "any", "all", "each", "every",
            "there", "their", "them", "me", "us", "him", "her",
            "discussed", "mentioned", "talked", "said", "meeting",
            "meetings", "during"
        ]

        return query.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count > 2 && !stopWords.contains($0) }
    }

    /// Build context string from scored meetings for the LLM
    private func buildContext(from meetings: [Meeting]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        var parts: [String] = []
        var totalChars = 0
        let charLimit = 40000 // Leave room for system prompt and question

        for meeting in meetings {
            var section = "## \(meeting.title)\n"
            section += "Date: \(dateFormatter.string(from: meeting.createdAt))\n"
            section += "Duration: \(meeting.formattedDuration)\n\n"

            if let summary = meeting.summary, !summary.isEmpty {
                section += "### Summary\n\(summary)\n\n"
            }

            let transcript = meeting.fullTranscript
            if !transcript.isEmpty {
                let remaining = charLimit - totalChars - section.count - 100
                if remaining > 500 {
                    let truncated = String(transcript.prefix(remaining))
                    section += "### Transcript\n\(truncated)\n"
                }
            }

            section += "\n---\n\n"

            if totalChars + section.count > charLimit { break }
            parts.append(section)
            totalChars += section.count
        }

        return parts.joined()
    }
}
