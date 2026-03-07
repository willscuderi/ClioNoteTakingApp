import AppKit
import Foundation
import SwiftData
import os

@MainActor
@Observable
final class MeetingDetailViewModel {
    var isGeneratingSummary = false
    var selectedLLMProvider: LLMProvider = .ollama {
        didSet { selectedModelID = selectedLLMProvider.defaultModel.id }
    }
    var selectedModelID: String = LLMProvider.ollama.defaultModel.id

    var resolvedModel: LLMModel {
        selectedLLMProvider.availableModels.first(where: { $0.id == selectedModelID })
            ?? selectedLLMProvider.defaultModel
    }
    var errorMessage: String?
    var successMessage: String?

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
                provider: selectedLLMProvider,
                model: resolvedModel
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

    // MARK: - Single Meeting Export

    func exportMarkdownWithSavePanel(meeting: Meeting) {
        let markdown = services.export.buildMarkdownContent(meeting: meeting)
        let fileName = sanitizeFileName(meeting.title) + ".md"

        let panel = NSSavePanel()
        panel.title = "Save Meeting Notes"
        panel.nameFieldStringValue = fileName
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try markdown.write(to: url, atomically: true, encoding: .utf8)
            successMessage = "Saved to \(url.lastPathComponent)"
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }

    func exportToAppleNotes(meeting: Meeting) async {
        do {
            try await services.export.exportToAppleNotes(meeting: meeting)
            successMessage = "Exported \"\(meeting.title)\" to Apple Notes"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportToNotion(meeting: Meeting) async {
        do {
            let apiKey = try services.keychain.loadAPIKey(for: "notion") ?? ""
            try await services.export.exportToNotion(meeting: meeting, apiKey: apiKey)
            successMessage = "Exported \"\(meeting.title)\" to Notion"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Bulk Export

    var bulkExportProgress: String?
    var isBulkExporting = false

    func bulkExportWithSavePanel(meetings: [Meeting]) {
        let panel = NSOpenPanel()
        panel.title = "Choose folder for meeting notes"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let folderURL = panel.url else { return }

        Task {
            await bulkExportMarkdownTo(folder: folderURL, meetings: meetings)
        }
    }

    private func bulkExportMarkdownTo(folder: URL, meetings: [Meeting]) async {
        isBulkExporting = true
        let total = meetings.count
        var succeeded = 0
        var failed = 0

        for (index, meeting) in meetings.enumerated() {
            bulkExportProgress = "Exporting \(index + 1) of \(total)..."
            do {
                let markdown = services.export.buildMarkdownContent(meeting: meeting)
                let fileName = sanitizeFileName(meeting.title) + ".md"
                let fileURL = folder.appendingPathComponent(fileName)
                try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
                succeeded += 1
            } catch {
                failed += 1
                logger.error("Bulk markdown export failed for '\(meeting.title)': \(error.localizedDescription)")
            }
        }

        bulkExportProgress = nil
        isBulkExporting = false
        if failed > 0 {
            errorMessage = "Exported \(succeeded) of \(total) meetings to Markdown. \(failed) failed."
        } else {
            successMessage = "Exported \(succeeded) meetings to \(folder.lastPathComponent)/"
            NSWorkspace.shared.activateFileViewerSelecting([folder])
        }
    }

    func bulkExport(meetings: [Meeting], to destination: ExportDestination) async {
        guard !isBulkExporting else { return }

        // Markdown gets a save panel
        if destination == .markdown {
            bulkExportWithSavePanel(meetings: meetings)
            return
        }

        isBulkExporting = true
        let total = meetings.count
        var succeeded = 0
        var failed = 0
        var lastError: String?

        for (index, meeting) in meetings.enumerated() {
            bulkExportProgress = "Exporting \(index + 1) of \(total) to \(destination.rawValue)..."
            do {
                switch destination {
                case .appleNotes:
                    try await services.export.exportToAppleNotes(meeting: meeting)
                case .notion:
                    let apiKey = try services.keychain.loadAPIKey(for: "notion") ?? ""
                    try await services.export.exportToNotion(meeting: meeting, apiKey: apiKey)
                case .markdown:
                    break // Handled above
                }
                succeeded += 1
            } catch {
                failed += 1
                lastError = error.localizedDescription
                logger.error("Bulk export failed for '\(meeting.title)': \(error.localizedDescription)")
            }
        }

        bulkExportProgress = nil
        isBulkExporting = false

        if failed > 0 && succeeded == 0 {
            errorMessage = "Export failed: \(lastError ?? "Unknown error")"
        } else if failed > 0 {
            errorMessage = "Exported \(succeeded) of \(total) meetings. \(failed) failed: \(lastError ?? "")"
        } else {
            successMessage = "Exported \(succeeded) meetings to \(destination.rawValue)"
        }
    }

    // MARK: - Helpers

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    private func sanitizeFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: invalid).joined(separator: "_")
    }
}

enum ExportDestination: String, CaseIterable, Identifiable {
    case markdown = "Markdown"
    case appleNotes = "Apple Notes"
    case notion = "Notion"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .markdown: "doc.text"
        case .appleNotes: "note.text"
        case .notion: "square.and.arrow.up"
        }
    }
}
