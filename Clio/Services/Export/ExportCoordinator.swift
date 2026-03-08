import AppKit
import Foundation
import os

final class ExportCoordinator: ExportServiceProtocol {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "ExportCoord")
    private let markdown: MarkdownExportService
    private let appleNotes: AppleNotesExportService
    private let notion: NotionExportService
    let obsidian: ObsidianExportService
    let oneNote: OneNoteExportService

    init(markdown: MarkdownExportService,
         appleNotes: AppleNotesExportService,
         notion: NotionExportService,
         obsidian: ObsidianExportService = ObsidianExportService(),
         oneNote: OneNoteExportService = OneNoteExportService()) {
        self.markdown = markdown
        self.appleNotes = appleNotes
        self.notion = notion
        self.obsidian = obsidian
        self.oneNote = oneNote
    }

    // MARK: - Clipboard Fallback

    /// Copy meeting notes to clipboard as a safety net when exports fail.
    func copyToClipboard(meeting: Meeting) {
        let content = buildMarkdownContent(meeting: meeting)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        logger.info("Meeting notes copied to clipboard as fallback")
    }

    // MARK: - Exports with Clipboard Fallback

    func exportMarkdown(meeting: Meeting) throws -> URL {
        try markdown.export(meeting: meeting)
    }

    func exportToAppleNotes(meeting: Meeting) async throws {
        do {
            try await appleNotes.export(meeting: meeting)
        } catch {
            copyToClipboard(meeting: meeting)
            logger.error("Apple Notes export failed, copied to clipboard: \(error.localizedDescription)")
            throw ExportError.appleScriptError(
                "Apple Notes export failed. Meeting notes copied to clipboard. \(error.localizedDescription)"
            )
        }
    }

    @discardableResult
    func exportToNotion(meeting: Meeting, apiKey: String) async throws -> String {
        do {
            return try await notion.export(meeting: meeting, apiKey: apiKey.isEmpty ? nil : apiKey)
        } catch {
            copyToClipboard(meeting: meeting)
            logger.error("Notion export failed, copied to clipboard: \(error.localizedDescription)")
            throw ExportError.networkError(
                "Notion export failed. Meeting notes copied to clipboard. \(error.localizedDescription)"
            )
        }
    }

    func exportToObsidian(meeting: Meeting) throws {
        let content = buildMarkdownContent(meeting: meeting)
        do {
            try obsidian.export(meeting: meeting, markdownContent: content)
        } catch {
            copyToClipboard(meeting: meeting)
            logger.error("Obsidian export failed, copied to clipboard: \(error.localizedDescription)")
            throw ExportError.fileWriteFailed(
                "Obsidian export failed. Meeting notes copied to clipboard. \(error.localizedDescription)"
            )
        }
    }

    func exportToOneNote(meeting: Meeting) throws {
        let content = buildMarkdownContent(meeting: meeting)
        do {
            try oneNote.export(meeting: meeting, markdownContent: content)
        } catch {
            copyToClipboard(meeting: meeting)
            logger.error("OneNote export failed, copied to clipboard: \(error.localizedDescription)")
            throw ExportError.fileWriteFailed(
                "OneNote export failed. Meeting notes copied to clipboard. \(error.localizedDescription)"
            )
        }
    }

    func testNotionConnection(apiKey: String?) async -> (success: Bool, message: String) {
        await notion.testConnection(apiKey: apiKey)
    }

    func autoSaveMeetingNotes(meeting: Meeting) {
        markdown.autoSave(meeting: meeting)
    }

    func buildMarkdownContent(meeting: Meeting) -> String {
        markdown.buildMarkdown(for: meeting)
    }
}
