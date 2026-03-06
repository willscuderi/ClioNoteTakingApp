import Foundation
import os

final class ExportCoordinator: ExportServiceProtocol {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "ExportCoord")
    private let markdown: MarkdownExportService
    private let appleNotes: AppleNotesExportService
    private let notion: NotionExportService

    init(markdown: MarkdownExportService,
         appleNotes: AppleNotesExportService,
         notion: NotionExportService) {
        self.markdown = markdown
        self.appleNotes = appleNotes
        self.notion = notion
    }

    func exportMarkdown(meeting: Meeting) throws -> URL {
        try markdown.export(meeting: meeting)
    }

    func exportToAppleNotes(meeting: Meeting) async throws {
        try await appleNotes.export(meeting: meeting)
    }

    func exportToNotion(meeting: Meeting, apiKey: String) async throws {
        try await notion.export(meeting: meeting)
    }
}
