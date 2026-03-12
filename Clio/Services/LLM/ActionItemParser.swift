import Foundation

/// Parses action items from LLM-generated markdown summaries.
enum ActionItemParser {
    /// Parse action items from a summary string.
    /// Supports patterns like:
    /// - [ ] **Owner:** Task description (by date)
    /// - [ ] Task description
    /// - **Action:** Task description
    /// - Task description (as bullet under ### Action Items)
    static func parse(_ summary: String) -> [ParsedActionItem] {
        var items: [ParsedActionItem] = []
        let lines = summary.components(separatedBy: .newlines)

        var inActionSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Detect action items section headers
            if trimmed.hasPrefix("### Action Items") || trimmed.hasPrefix("## Action Items") {
                inActionSection = true
                continue
            }

            // Exit section on next header
            if inActionSection && (trimmed.hasPrefix("### ") || trimmed.hasPrefix("## ")) {
                inActionSection = false
                continue
            }

            // Parse checkbox items anywhere in the document
            if let item = parseCheckboxLine(trimmed) {
                items.append(item)
                continue
            }

            // Parse bullet items within action section
            if inActionSection, let item = parseBulletLine(trimmed) {
                items.append(item)
            }
        }

        return items
    }

    /// Parse "- [ ] **Owner:** Task (by date)" or "- [ ] Task"
    private static func parseCheckboxLine(_ line: String) -> ParsedActionItem? {
        // Match: - [ ] or - [x] patterns
        let checkboxPattern = #"^[-*]\s*\[[ x]\]\s*(.+)$"#
        guard let match = line.range(of: checkboxPattern, options: .regularExpression) else { return nil }

        let content = String(line[match]).replacingOccurrences(
            of: #"^[-*]\s*\[[ x]\]\s*"#,
            with: "",
            options: .regularExpression
        )

        let isCompleted = line.contains("[x]")
        return parseContent(content, isCompleted: isCompleted)
    }

    /// Parse "- Task description" within action items section
    private static func parseBulletLine(_ line: String) -> ParsedActionItem? {
        guard line.hasPrefix("- ") || line.hasPrefix("* ") else { return nil }
        let content = String(line.dropFirst(2))
        guard !content.isEmpty else { return nil }
        return parseContent(content, isCompleted: false)
    }

    /// Extract owner and due date from action item text
    private static func parseContent(_ content: String, isCompleted: Bool) -> ParsedActionItem {
        var text = content
        var owner: String?
        var dueDate: String?

        // Extract **Owner:** prefix
        let ownerPattern = #"\*\*([^*]+)\*\*:\s*"#
        if let ownerMatch = text.range(of: ownerPattern, options: .regularExpression) {
            let ownerText = String(text[ownerMatch])
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: ":", with: "")
                .trimmingCharacters(in: .whitespaces)
            if !ownerText.lowercased().contains("action") {
                owner = ownerText
            }
            text = String(text[ownerMatch.upperBound...]).trimmingCharacters(in: .whitespaces)
        }

        // Extract (by date) or (deadline: date) suffix
        let datePattern = #"\((?:by |deadline:?\s*)([^)]+)\)\s*$"#
        if let dateMatch = text.range(of: datePattern, options: .regularExpression) {
            let dateText = String(text[dateMatch])
                .replacingOccurrences(of: #"^\((?:by |deadline:?\s*)"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: ")", with: "")
                .trimmingCharacters(in: .whitespaces)
            dueDate = dateText
            text = String(text[..<dateMatch.lowerBound]).trimmingCharacters(in: .whitespaces)
        }

        return ParsedActionItem(
            text: text,
            owner: owner,
            dueDate: dueDate,
            isCompleted: isCompleted
        )
    }
}

struct ParsedActionItem {
    let text: String
    let owner: String?
    let dueDate: String?
    let isCompleted: Bool
}
