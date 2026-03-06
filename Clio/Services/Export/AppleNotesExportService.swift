import Foundation
import os

final class AppleNotesExportService {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "AppleNotesExport")

    func export(meeting: Meeting) async throws {
        let title = meeting.title
        let body = buildHTMLBody(for: meeting)

        // Escape for AppleScript string literals
        let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\\", with: "\\\\")

        let scriptSource = """
        tell application "Notes"
            activate
            make new note at folder "Notes" with properties {name:"\(escapedTitle)", body:"\(escapedBody)"}
        end tell
        """

        guard let script = NSAppleScript(source: scriptSource) else {
            throw ExportError.scriptCreationFailed
        }

        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)

        if let error = errorInfo {
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
            logger.error("Apple Notes export failed: \(message)")
            throw ExportError.appleScriptError(message)
        }

        logger.info("Exported to Apple Notes: \(title)")
    }

    private func buildHTMLBody(for meeting: Meeting) -> String {
        var html = ""

        html += "<h1>\(escapeHTML(meeting.title))</h1>"
        html += "<p><b>Date:</b> \(meeting.createdAt.meetingDateFormatted)</p>"
        html += "<p><b>Duration:</b> \(meeting.formattedDuration)</p>"

        if let summary = meeting.summary {
            html += "<hr>"
            // Convert basic markdown to HTML
            html += markdownToBasicHTML(summary)
        }

        if !meeting.bookmarks.isEmpty {
            html += "<hr><h2>Bookmarks</h2><ul>"
            for bookmark in meeting.bookmarks.sorted(by: { $0.timestamp < $1.timestamp }) {
                html += "<li><b>\(bookmark.formattedTimestamp)</b> \(escapeHTML(bookmark.label))</li>"
            }
            html += "</ul>"
        }

        if !meeting.segments.isEmpty {
            html += "<hr><h2>Transcript</h2>"
            for segment in meeting.segments.sorted(by: { $0.startTime < $1.startTime }) {
                html += "<p><b>[\(segment.formattedTimestamp)]</b> \(escapeHTML(segment.text))</p>"
            }
        }

        return html
    }

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// Simple markdown to HTML conversion for summaries
    private func markdownToBasicHTML(_ markdown: String) -> String {
        var html = ""
        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("### ") {
                html += "<h3>\(escapeHTML(String(trimmed.dropFirst(4))))</h3>"
            } else if trimmed.hasPrefix("## ") {
                html += "<h2>\(escapeHTML(String(trimmed.dropFirst(3))))</h2>"
            } else if trimmed.hasPrefix("# ") {
                html += "<h1>\(escapeHTML(String(trimmed.dropFirst(2))))</h1>"
            } else if trimmed.hasPrefix("- [ ] ") {
                html += "<p>☐ \(escapeHTML(String(trimmed.dropFirst(6))))</p>"
            } else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
                html += "<p>☑ \(escapeHTML(String(trimmed.dropFirst(6))))</p>"
            } else if trimmed.hasPrefix("- ") {
                html += "<p>• \(escapeHTML(String(trimmed.dropFirst(2))))</p>"
            } else if trimmed.isEmpty {
                html += "<br>"
            } else {
                html += "<p>\(escapeHTML(String(trimmed)))</p>"
            }
        }
        return html
    }
}
