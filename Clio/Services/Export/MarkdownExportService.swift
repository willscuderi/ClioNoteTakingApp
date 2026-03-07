import Foundation
import os

final class MarkdownExportService {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "MarkdownExport")

    /// Persistent local folder for meeting notes.
    /// Located in Application Support so it survives app updates.
    static let meetingNotesDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("com.willscuderi.Clio", isDirectory: true)
            .appendingPathComponent("MeetingNotes", isDirectory: true)
    }()

    init() {
        // Ensure the persistent directory exists
        try? FileManager.default.createDirectory(
            at: Self.meetingNotesDirectory,
            withIntermediateDirectories: true
        )
    }

    /// Export meeting to a markdown file and return its URL.
    func export(meeting: Meeting) throws -> URL {
        let markdown = buildMarkdown(for: meeting)

        let fileName = sanitizeFileName(meeting.title) + ".md"
        let fileURL = Self.meetingNotesDirectory.appendingPathComponent(fileName)

        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        logger.info("Exported markdown to \(fileURL.path)")
        return fileURL
    }

    /// Auto-save a meeting to the local MeetingNotes folder.
    /// Called automatically when a recording completes.
    func autoSave(meeting: Meeting) {
        do {
            let url = try export(meeting: meeting)
            logger.info("Auto-saved meeting notes: \(url.lastPathComponent)")
        } catch {
            logger.error("Auto-save failed: \(error.localizedDescription)")
        }
    }

    /// Returns all locally saved meeting note files, newest first.
    func savedMeetingNotes() -> [URL] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: Self.meetingNotesDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return contents
            .filter { $0.pathExtension == "md" }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return date1 > date2
            }
    }

    /// Path to the MeetingNotes folder for display in settings.
    static var meetingNotesPath: String {
        meetingNotesDirectory.path
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
