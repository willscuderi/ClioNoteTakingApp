import Foundation
import os

final class NotionExportService {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "NotionExport")
    private let keychain: KeychainServiceProtocol
    private let apiURL = URL(string: "https://api.notion.com/v1/pages")!

    init(keychain: KeychainServiceProtocol) {
        self.keychain = keychain
    }

    func export(meeting: Meeting, apiKey: String? = nil) async throws {
        let key: String
        if let apiKey, !apiKey.isEmpty {
            key = apiKey
        } else if let stored = try keychain.loadAPIKey(for: "notion") {
            key = stored
        } else {
            throw ExportError.apiKeyMissing("notion")
        }

        // For now, create a standalone page (no parent database)
        // Users can move it to their preferred database in Notion
        let requestBody = buildPageRequest(for: meeting)

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExportError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Notion API error \(httpResponse.statusCode): \(errorBody)")
            throw ExportError.apiError(httpResponse.statusCode, errorBody)
        }

        logger.info("Exported to Notion: \(meeting.title)")
    }

    private func buildPageRequest(for meeting: Meeting) -> [String: Any] {
        var children: [[String: Any]] = []

        // Date and duration heading
        children.append(makeBlock(type: "callout", text: "📅 \(meeting.createdAt.meetingDateFormatted)  •  ⏱ \(meeting.formattedDuration)"))

        // Summary
        if let summary = meeting.summary {
            children.append(makeBlock(type: "heading_2", text: "Summary"))
            // Split summary into paragraph blocks
            for paragraph in summary.split(separator: "\n\n", omittingEmptySubsequences: true) {
                let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("### ") {
                    children.append(makeBlock(type: "heading_3", text: String(trimmed.dropFirst(4))))
                } else if trimmed.hasPrefix("## ") {
                    children.append(makeBlock(type: "heading_2", text: String(trimmed.dropFirst(3))))
                } else if trimmed.hasPrefix("- ") {
                    // Split into individual bullet items
                    for item in paragraph.split(separator: "\n") {
                        let itemText = item.trimmingCharacters(in: .whitespaces)
                        if itemText.hasPrefix("- [ ] ") {
                            children.append(makeTodoBlock(text: String(itemText.dropFirst(6)), checked: false))
                        } else if itemText.hasPrefix("- [x] ") || itemText.hasPrefix("- [X] ") {
                            children.append(makeTodoBlock(text: String(itemText.dropFirst(6)), checked: true))
                        } else if itemText.hasPrefix("- ") {
                            children.append(makeBlock(type: "bulleted_list_item", text: String(itemText.dropFirst(2))))
                        }
                    }
                } else if !trimmed.isEmpty {
                    children.append(makeBlock(type: "paragraph", text: trimmed))
                }
            }
        }

        // Bookmarks
        if !meeting.bookmarks.isEmpty {
            children.append(makeBlock(type: "heading_2", text: "Bookmarks"))
            for bookmark in meeting.bookmarks.sorted(by: { $0.timestamp < $1.timestamp }) {
                let label = bookmark.label.isEmpty ? "Bookmark" : bookmark.label
                children.append(makeBlock(type: "bulleted_list_item", text: "[\(bookmark.formattedTimestamp)] \(label)"))
            }
        }

        // Transcript (first 50 segments to avoid API limits)
        let segments = meeting.segments.sorted { $0.startTime < $1.startTime }
        if !segments.isEmpty {
            children.append(makeBlock(type: "heading_2", text: "Transcript"))
            children.append(makeBlock(type: "divider", text: ""))

            for segment in segments.prefix(50) {
                children.append(makeBlock(type: "paragraph", text: "[\(segment.formattedTimestamp)] \(segment.text)"))
            }

            if segments.count > 50 {
                children.append(makeBlock(type: "paragraph", text: "... \(segments.count - 50) more segments (see full transcript in Clio)"))
            }
        }

        // Notion API limits children to 100 blocks per request
        let limitedChildren = Array(children.prefix(100))

        return [
            "parent": ["type": "page_id", "page_id": ""],  // Will be overridden by user's config
            "properties": [
                "title": [
                    ["type": "text", "text": ["content": meeting.title]]
                ]
            ],
            "children": limitedChildren
        ]
    }

    private func makeBlock(type: String, text: String) -> [String: Any] {
        if type == "divider" {
            return ["object": "block", "type": "divider", "divider": [:] as [String: Any]]
        }

        return [
            "object": "block",
            "type": type,
            type: [
                "rich_text": [
                    ["type": "text", "text": ["content": String(text.prefix(2000))]]
                ]
            ]
        ]
    }

    private func makeTodoBlock(text: String, checked: Bool) -> [String: Any] {
        [
            "object": "block",
            "type": "to_do",
            "to_do": [
                "rich_text": [
                    ["type": "text", "text": ["content": String(text.prefix(2000))]]
                ],
                "checked": checked
            ] as [String: Any]
        ]
    }
}
