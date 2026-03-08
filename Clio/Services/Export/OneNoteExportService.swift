import AppKit
import Foundation
import os

final class OneNoteExportService {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "OneNoteExport")

    /// Exports a meeting as HTML and opens it in OneNote (or the default browser if OneNote isn't installed).
    func export(meeting: Meeting, markdownContent: String) throws {
        let html = convertMarkdownToHTML(markdownContent, title: meeting.title)

        let fileName = sanitizeFileName(meeting.title) + ".html"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try html.write(to: tempURL, atomically: true, encoding: .utf8)

        // Try to open with OneNote
        let oneNoteBundleID = "com.microsoft.onenote.mac"
        if let oneNoteURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: oneNoteBundleID) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.open([tempURL], withApplicationAt: oneNoteURL, configuration: config)
            logger.info("Opened meeting in OneNote: \(meeting.title)")
        } else {
            // Fallback: open in default browser
            NSWorkspace.shared.open(tempURL)
            logger.info("OneNote not found, opened HTML in browser: \(meeting.title)")
        }
    }

    // MARK: - Markdown to HTML

    private func convertMarkdownToHTML(_ markdown: String, title: String) -> String {
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <title>\(escapeHTML(title))</title>
        <style>
        body { font-family: -apple-system, system-ui, sans-serif; max-width: 800px; margin: 40px auto; padding: 0 20px; line-height: 1.6; }
        h1 { border-bottom: 1px solid #eee; padding-bottom: 8px; }
        h2 { margin-top: 24px; }
        h3 { margin-top: 16px; }
        ul { padding-left: 20px; }
        code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; font-size: 0.9em; }
        blockquote { border-left: 3px solid #ddd; padding-left: 12px; margin-left: 0; color: #555; }
        </style>
        </head>
        <body>
        """

        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("### ") {
                html += "<h3>\(escapeHTML(String(trimmed.dropFirst(4))))</h3>\n"
            } else if trimmed.hasPrefix("## ") {
                html += "<h2>\(escapeHTML(String(trimmed.dropFirst(3))))</h2>\n"
            } else if trimmed.hasPrefix("# ") {
                html += "<h1>\(escapeHTML(String(trimmed.dropFirst(2))))</h1>\n"
            } else if trimmed.hasPrefix("- [ ] ") {
                html += "<ul><li>☐ \(escapeHTML(String(trimmed.dropFirst(6))))</li></ul>\n"
            } else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
                html += "<ul><li>☑ \(escapeHTML(String(trimmed.dropFirst(6))))</li></ul>\n"
            } else if trimmed.hasPrefix("- ") {
                html += "<ul><li>\(formatInlineMarkdown(String(trimmed.dropFirst(2))))</li></ul>\n"
            } else if trimmed.hasPrefix("> ") {
                html += "<blockquote>\(escapeHTML(String(trimmed.dropFirst(2))))</blockquote>\n"
            } else if trimmed.isEmpty {
                html += "<br>\n"
            } else {
                html += "<p>\(formatInlineMarkdown(String(trimmed)))</p>\n"
            }
        }

        html += "</body>\n</html>"
        return html
    }

    private func formatInlineMarkdown(_ text: String) -> String {
        var result = escapeHTML(text)
        // Bold: **text**
        result = result.replacingOccurrences(
            of: "\\*\\*(.+?)\\*\\*",
            with: "<strong>$1</strong>",
            options: .regularExpression
        )
        // Italic: *text*
        result = result.replacingOccurrences(
            of: "\\*(.+?)\\*",
            with: "<em>$1</em>",
            options: .regularExpression
        )
        // Code: `text`
        result = result.replacingOccurrences(
            of: "`(.+?)`",
            with: "<code>$1</code>",
            options: .regularExpression
        )
        return result
    }

    private func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func sanitizeFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: invalid).joined(separator: "_")
    }
}
