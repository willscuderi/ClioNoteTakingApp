import Foundation
import os

final class MarkdownExportService {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "MarkdownExport")

    func export(meeting: Meeting) throws -> URL {
        let markdown = buildMarkdown(for: meeting)

        let fileName = sanitizeFileName(meeting.title) + ".md"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        logger.info("Exported markdown to \(fileURL.path)")
        return fileURL
    }

    func buildMarkdown(for meeting: Meeting) -> String {
        var md = "# \(meeting.title)\n\n"
        md += "**Date:** \(meeting.createdAt.formatted(date: .long, time: .shortened))\n"
        md += "**Duration:** \(meeting.formattedDuration)\n\n"

        if let summary = meeting.summary {
            md += "---\n\n"
            md += summary
            md += "\n\n"
        }

        if !meeting.bookmarks.isEmpty {
            md += "---\n\n"
            md += "## Bookmarks\n\n"
            for bookmark in meeting.bookmarks.sorted(by: { $0.timestamp < $1.timestamp }) {
                md += "- **\(bookmark.formattedTimestamp)** \(bookmark.label)\n"
            }
            md += "\n"
        }

        if !meeting.segments.isEmpty {
            md += "---\n\n"
            md += "## Transcript\n\n"
            for segment in meeting.segments.sorted(by: { $0.startTime < $1.startTime }) {
                md += "**[\(segment.formattedTimestamp)]** \(segment.text)\n\n"
            }
        }

        return md
    }

    private func sanitizeFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: invalid).joined(separator: "_")
    }
}
