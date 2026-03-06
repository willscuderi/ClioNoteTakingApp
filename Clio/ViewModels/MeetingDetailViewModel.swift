import AppKit
import Foundation
import SwiftData
import os

@MainActor
@Observable
final class MeetingDetailViewModel {
    var isGeneratingSummary = false
    var selectedLLMProvider: LLMProvider = .openai
    var errorMessage: String?

    private let services: ServiceContainer
    private let logger = Logger.llm

    init(services: ServiceContainer) {
        self.services = services
    }

    func generateSummary(for meeting: Meeting, context: ModelContext) async {
        guard !isGeneratingSummary else { return }
        isGeneratingSummary = true
        errorMessage = nil

        do {
            let transcript = meeting.fullTranscript
            guard !transcript.isEmpty else {
                errorMessage = "No transcript available to summarize"
                isGeneratingSummary = false
                return
            }

            let summary = try await services.llm.summarize(
                transcript: transcript,
                provider: selectedLLMProvider
            )
            meeting.summary = summary
            try? context.save()
            logger.info("Summary generated for: \(meeting.title)")
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Summary generation failed: \(error.localizedDescription)")
        }

        isGeneratingSummary = false
    }

    func exportMarkdown(meeting: Meeting) {
        do {
            let url = try services.export.exportMarkdown(meeting: meeting)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportToAppleNotes(meeting: Meeting) async {
        do {
            try await services.export.exportToAppleNotes(meeting: meeting)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportToNotion(meeting: Meeting) async {
        do {
            let apiKey = try services.keychain.loadAPIKey(for: "notion") ?? ""
            try await services.export.exportToNotion(meeting: meeting, apiKey: apiKey)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
