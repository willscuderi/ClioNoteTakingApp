import AppKit
import Foundation
import SwiftData
import os

@MainActor
@Observable
final class MeetingDetailViewModel {
    var isGeneratingSummary = false
    var streamedSummary: String = ""
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
    var lastExportURL: String?

    private let services: ServiceContainer
    private let logger = Logger.llm

    init(services: ServiceContainer) {
        self.services = services
    }

    func generateSummary(for meeting: Meeting, context: ModelContext, template: SummaryTemplate? = nil) async {
        guard !isGeneratingSummary else { return }
        isGeneratingSummary = true
        streamedSummary = ""
        errorMessage = nil

        let transcript = buildEnrichedTranscript(for: meeting)
        guard !transcript.isEmpty else {
            errorMessage = "No transcript available to summarize"
            isGeneratingSummary = false
            return
        }

        do {
            let stream = services.llm.summarizeStreaming(
                transcript: transcript,
                provider: selectedLLMProvider,
                model: resolvedModel,
                systemPrompt: template?.systemPrompt
            )

            for try await chunk in stream {
                streamedSummary += chunk
            }

            meeting.summary = streamedSummary
            extractActionItems(from: streamedSummary, meeting: meeting, context: context)
            try? context.save()
            logger.info("Summary generated for: \(meeting.title)")
        } catch {
            // If we got partial content, still save it
            if !streamedSummary.isEmpty {
                meeting.summary = streamedSummary
                extractActionItems(from: streamedSummary, meeting: meeting, context: context)
                try? context.save()
            }
            errorMessage = error.localizedDescription
            logger.error("Summary generation failed: \(error.localizedDescription)")
        }

        isGeneratingSummary = false
    }

    /// Parse action items from summary and save to SwiftData
    private func extractActionItems(from summary: String, meeting: Meeting, context: ModelContext) {
        // Clear existing action items for this meeting
        for item in meeting.actionItems {
            context.delete(item)
        }
        meeting.actionItems.removeAll()

        let parsed = ActionItemParser.parse(summary)
        for parsedItem in parsed {
            let actionItem = ActionItem(
                text: parsedItem.text,
                owner: parsedItem.owner,
                dueDate: parsedItem.dueDate,
                isCompleted: parsedItem.isCompleted
            )
            actionItem.meeting = meeting
            meeting.actionItems.append(actionItem)
            context.insert(actionItem)
        }
        logger.info("Extracted \(parsed.count) action items from summary")
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
            let url = try await services.export.exportToNotion(meeting: meeting, apiKey: apiKey)
            lastExportURL = url
            successMessage = "Exported \"\(meeting.title)\" to Notion"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportToObsidian(meeting: Meeting) {
        do {
            guard let coordinator = services.export as? ExportCoordinator else {
                errorMessage = "Export service not configured"
                return
            }
            try coordinator.exportToObsidian(meeting: meeting)
            successMessage = "Exported \"\(meeting.title)\" to Obsidian"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportToOneNote(meeting: Meeting) {
        do {
            guard let coordinator = services.export as? ExportCoordinator else {
                errorMessage = "Export service not configured"
                return
            }
            try coordinator.exportToOneNote(meeting: meeting)
            successMessage = "Exported \"\(meeting.title)\" to OneNote"
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
                case .obsidian:
                    if let coordinator = services.export as? ExportCoordinator {
                        try coordinator.exportToObsidian(meeting: meeting)
                    }
                case .oneNote:
                    if let coordinator = services.export as? ExportCoordinator {
                        try coordinator.exportToOneNote(meeting: meeting)
                    }
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

    // MARK: - Transcript Enrichment

    /// Build transcript with bookmark markers injected at the correct positions.
    private func buildEnrichedTranscript(for meeting: Meeting) -> String {
        let sortedSegments = meeting.segments.sorted { $0.startTime < $1.startTime }
        guard !sortedSegments.isEmpty else { return "" }

        let sortedBookmarks = meeting.bookmarks.sorted { $0.timestamp < $1.timestamp }
        guard !sortedBookmarks.isEmpty else { return meeting.fullTranscript }

        var lines: [String] = []
        var bookmarkIndex = 0

        for segment in sortedSegments {
            // Insert any bookmarks that fall before or within this segment
            while bookmarkIndex < sortedBookmarks.count &&
                  sortedBookmarks[bookmarkIndex].timestamp <= segment.endTime {
                let bookmark = sortedBookmarks[bookmarkIndex]
                let label = bookmark.label.isEmpty ? "Bookmark" : bookmark.label
                lines.append("[BOOKMARK: \"\(label)\" at \(bookmark.formattedTimestamp)]")
                bookmarkIndex += 1
            }

            if let speaker = segment.speakerLabel {
                lines.append("[\(speaker)] \(segment.text)")
            } else {
                lines.append(segment.text)
            }
        }

        // Any remaining bookmarks after the last segment
        while bookmarkIndex < sortedBookmarks.count {
            let bookmark = sortedBookmarks[bookmarkIndex]
            let label = bookmark.label.isEmpty ? "Bookmark" : bookmark.label
            lines.append("[BOOKMARK: \"\(label)\" at \(bookmark.formattedTimestamp)]")
            bookmarkIndex += 1
        }

        return lines.joined(separator: "\n")
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
    case obsidian = "Obsidian"
    case oneNote = "OneNote"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .markdown: "doc.text"
        case .appleNotes: "note.text"
        case .notion: "square.and.arrow.up"
        case .obsidian: "diamond"
        case .oneNote: "book.closed"
        }
    }
}
