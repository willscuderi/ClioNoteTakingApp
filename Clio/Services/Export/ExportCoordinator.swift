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

    func exportMarkdown(meeting: Meeting) throws -> URL {
        try markdown.export(meeting: meeting)
    }

    func exportToAppleNotes(meeting: Meeting) async throws {
        try await appleNotes.export(meeting: meeting)
    }

    @discardableResult
    func exportToNotion(meeting: Meeting, apiKey: String) async throws -> String {
        try await notion.export(meeting: meeting, apiKey: apiKey.isEmpty ? nil : apiKey)
    }

    func exportToObsidian(meeting: Meeting) throws {
        let content = buildMarkdownContent(meeting: meeting)
        try obsidian.export(meeting: meeting, markdownContent: content)
    }

    func exportToOneNote(meeting: Meeting) throws {
        let content = buildMarkdownContent(meeting: meeting)
        try oneNote.export(meeting: meeting, markdownContent: content)
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
