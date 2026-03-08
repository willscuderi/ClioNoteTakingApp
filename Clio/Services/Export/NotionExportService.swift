import Foundation
import os

final class NotionExportService {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "NotionExport")
    private let keychain: KeychainServiceProtocol
    private let baseURL = "https://api.notion.com/v1"
    private let notionVersion = "2022-06-28"

    private static let databaseIDKey = "notionClioDatabaseID"
    private static let parentPageIDKey = "notionParentPageID"

    init(keychain: KeychainServiceProtocol) {
        self.keychain = keychain
    }

    // MARK: - Public API

    /// Exports a meeting to Notion and returns the page URL.
    @discardableResult
    func export(meeting: Meeting, apiKey: String? = nil) async throws -> String {
        let key = try resolveAPIKey(override: apiKey)
        let databaseID = try await ensureDatabase(apiKey: key)

        // Create a page in the database with meeting metadata as properties
        let pageBody = buildDatabasePageRequest(for: meeting, databaseID: databaseID)

        let (data, response) = try await notionRequest(
            path: "/pages",
            method: "POST",
            apiKey: key,
            body: pageBody
        )

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Notion API error creating page: \(code) \(errorBody)")
            throw translateNotionError(code: code, body: errorBody)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let pageID = json["id"] as? String else {
            throw ExportError.networkError("Could not parse page ID from Notion response")
        }

        // Extract the page URL
        let pageURL = (json["url"] as? String) ?? "https://notion.so/\(pageID.replacingOccurrences(of: "-", with: ""))"

        try await appendContentBlocks(pageID: pageID, meeting: meeting, apiKey: key)
        logger.info("Exported to Notion database: \(meeting.title) — \(pageURL)")

        return pageURL
    }

    /// Test the Notion connection and return a status message.
    func testConnection(apiKey: String? = nil) async -> (success: Bool, message: String) {
        let key: String
        do {
            key = try resolveAPIKey(override: apiKey)
        } catch {
            return (false, "No Notion API key configured. Add one in Settings > API Keys.")
        }

        // 1. Validate the token by calling /users/me
        do {
            let (data, response) = try await notionRequest(
                path: "/users/me",
                method: "GET",
                apiKey: key
            )
            guard let httpResponse = response as? HTTPURLResponse else {
                return (false, "Could not connect to Notion API.")
            }
            if httpResponse.statusCode == 401 {
                return (false, "Invalid API key. Check that you copied the full Internal Integration Secret.")
            }
            if httpResponse.statusCode != 200 {
                let body = String(data: data, encoding: .utf8) ?? ""
                return (false, "Notion API error (\(httpResponse.statusCode)): \(body.prefix(200))")
            }
        } catch {
            return (false, "Network error: \(error.localizedDescription)")
        }

        // 2. Check if we can find an accessible page
        do {
            let storedPageID = UserDefaults.standard.string(forKey: Self.parentPageIDKey) ?? ""
            if !storedPageID.isEmpty {
                // Verify the stored parent page is accessible
                let (_, pageResponse) = try await notionRequest(
                    path: "/pages/\(storedPageID)",
                    method: "GET",
                    apiKey: key
                )
                if let httpResponse = pageResponse as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    return (true, "Connected! Parent page is accessible.")
                } else {
                    let code = (pageResponse as? HTTPURLResponse)?.statusCode ?? 0
                    if code == 404 {
                        return (false, "Parent page not found. The page may have been deleted, or the integration doesn't have access. Share the page with your Clio integration in Notion.")
                    }
                    return (false, "Cannot access parent page (error \(code)). Make sure the page is shared with your Clio integration.")
                }
            }

            // No stored page — check if there are any accessible pages
            let searchBody: [String: Any] = [
                "filter": ["value": "page", "property": "object"],
                "page_size": 1
            ]
            let (data, _) = try await notionRequest(
                path: "/search",
                method: "POST",
                apiKey: key,
                body: searchBody
            )
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]],
               !results.isEmpty {
                return (true, "Connected! Clio will auto-detect a parent page for its database.")
            }

            return (false, "Connected to Notion, but no pages are shared with the integration. In Notion, open a page, click Share, and add your Clio integration.")
        } catch {
            return (false, "Connection test failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Database Management

    /// Finds or creates the "Clio Meeting Notes" database.
    private func ensureDatabase(apiKey: String) async throws -> String {
        // Check if we already have a stored database ID
        if let storedID = UserDefaults.standard.string(forKey: Self.databaseIDKey) {
            // Verify it still exists
            if await databaseExists(id: storedID, apiKey: apiKey) {
                return storedID
            }
            // Stored ID is stale, clear it
            logger.warning("Stored Notion database ID is stale, clearing: \(storedID)")
            UserDefaults.standard.removeObject(forKey: Self.databaseIDKey)
        }

        // Search for an existing "Clio Meeting Notes" database
        if let existingID = try await findExistingDatabase(apiKey: apiKey) {
            UserDefaults.standard.set(existingID, forKey: Self.databaseIDKey)
            return existingID
        }

        // Create a new database
        let newID = try await createDatabase(apiKey: apiKey)
        UserDefaults.standard.set(newID, forKey: Self.databaseIDKey)
        return newID
    }

    private func databaseExists(id: String, apiKey: String) async -> Bool {
        guard let result = try? await notionRequest(
            path: "/databases/\(id)",
            method: "GET",
            apiKey: apiKey
        ) else { return false }
        return (result.1 as? HTTPURLResponse)?.statusCode == 200
    }

    private func findExistingDatabase(apiKey: String) async throws -> String? {
        let searchBody: [String: Any] = [
            "query": "Clio Meeting Notes",
            "filter": ["value": "database", "property": "object"],
            "page_size": 10
        ]

        let (data, response) = try await notionRequest(
            path: "/search",
            method: "POST",
            apiKey: apiKey,
            body: searchBody
        )

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            return nil
        }

        // Find a database with exact title match
        for result in results {
            if let title = result["title"] as? [[String: Any]],
               let firstText = title.first?["plain_text"] as? String,
               firstText == "Clio Meeting Notes",
               let id = result["id"] as? String {
                return id
            }
        }

        return nil
    }

    private func createDatabase(apiKey: String) async throws -> String {
        // First, find a page we can create the database under.
        // Search for any accessible page to use as parent.
        let parentPageID = try await findOrCreateParentPage(apiKey: apiKey)

        let databaseBody: [String: Any] = [
            "parent": ["type": "page_id", "page_id": parentPageID],
            "title": [
                ["type": "text", "text": ["content": "Clio Meeting Notes"]]
            ],
            "icon": ["type": "emoji", "emoji": "🎵"],
            "properties": [
                "Name": ["title": [:] as [String: Any]],
                "Date": ["date": [:] as [String: Any]],
                "Duration": [
                    "rich_text": [:] as [String: Any]
                ],
                "Status": [
                    "select": [
                        "options": [
                            ["name": "Completed", "color": "green"],
                            ["name": "Processing", "color": "yellow"],
                            ["name": "Recording", "color": "blue"],
                            ["name": "Failed", "color": "red"]
                        ]
                    ]
                ],
                "Bookmarks": ["number": ["format": "number"] as [String: Any]],
                "Has Summary": ["checkbox": [:] as [String: Any]]
            ] as [String: Any]
        ]

        let (data, response) = try await notionRequest(
            path: "/databases",
            method: "POST",
            apiKey: apiKey,
            body: databaseBody
        )

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Failed to create Notion database: \(code) \(errorBody)")
            throw translateNotionError(code: code, body: errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let databaseID = json["id"] as? String else {
            throw ExportError.networkError("Could not parse database ID from response")
        }

        logger.info("Created Notion database: \(databaseID)")
        return databaseID
    }

    private func findOrCreateParentPage(apiKey: String) async throws -> String {
        // Check if user configured a parent page ID in Settings > API Keys
        if let storedPageID = UserDefaults.standard.string(forKey: Self.parentPageIDKey),
           !storedPageID.isEmpty {
            // Validate the stored page is still accessible
            let (_, pageResponse) = try await notionRequest(
                path: "/pages/\(storedPageID)",
                method: "GET",
                apiKey: apiKey
            )
            if let httpResponse = pageResponse as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return storedPageID
            }
            // Stored page is inaccessible — clear it and try to find another
            logger.warning("Stored parent page \(storedPageID) is not accessible, clearing")
            UserDefaults.standard.removeObject(forKey: Self.parentPageIDKey)
        }

        // Search for any accessible page the integration can see
        let searchBody: [String: Any] = [
            "filter": ["value": "page", "property": "object"],
            "page_size": 5
        ]

        let (data, response) = try await notionRequest(
            path: "/search",
            method: "POST",
            apiKey: apiKey,
            body: searchBody
        )

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
           let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let results = json["results"] as? [[String: Any]],
           let firstPage = results.first,
           let pageID = firstPage["id"] as? String {
            UserDefaults.standard.set(pageID, forKey: Self.parentPageIDKey)
            logger.info("Auto-detected Notion parent page: \(pageID)")
            return pageID
        }

        // No accessible pages — guide the user
        throw ExportError.notionSetupRequired
    }

    // MARK: - Build Database Page (Meeting as Row)

    private func buildDatabasePageRequest(for meeting: Meeting, databaseID: String) -> [String: Any] {
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime]

        let properties: [String: Any] = [
            "Name": [
                "title": [
                    ["type": "text", "text": ["content": meeting.title]]
                ]
            ],
            "Date": [
                "date": [
                    "start": iso8601.string(from: meeting.createdAt),
                    "end": meeting.endedAt.map { iso8601.string(from: $0) } as Any
                ].compactMapValues { $0 }
            ],
            "Duration": [
                "rich_text": [
                    ["type": "text", "text": ["content": meeting.formattedDuration]]
                ]
            ],
            "Status": [
                "select": ["name": meeting.status.displayName]
            ],
            "Bookmarks": [
                "number": meeting.bookmarks.count
            ],
            "Has Summary": [
                "checkbox": meeting.summary != nil
            ]
        ]

        return [
            "parent": ["type": "database_id", "database_id": databaseID],
            "properties": properties
        ]
    }

    // MARK: - Append Content Blocks

    /// Appends meeting content (summary, bookmarks, transcript) as blocks to the page.
    private func appendContentBlocks(pageID: String, meeting: Meeting, apiKey: String) async throws {
        var children: [[String: Any]] = []

        // Summary
        if let summary = meeting.summary {
            children.append(makeBlock(type: "heading_2", text: "Summary"))
            for paragraph in summary.split(separator: "\n\n", omittingEmptySubsequences: true) {
                let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("### ") {
                    children.append(makeBlock(type: "heading_3", text: String(trimmed.dropFirst(4))))
                } else if trimmed.hasPrefix("## ") {
                    children.append(makeBlock(type: "heading_2", text: String(trimmed.dropFirst(3))))
                } else if trimmed.hasPrefix("- ") {
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

        // Notion API limits to 100 blocks per request — send in batches
        let batches = stride(from: 0, to: children.count, by: 100).map {
            Array(children[$0..<min($0 + 100, children.count)])
        }

        for batch in batches {
            let body: [String: Any] = ["children": batch]
            let (data, response) = try await notionRequest(
                path: "/blocks/\(pageID)/children",
                method: "PATCH",
                apiKey: apiKey,
                body: body
            )

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.warning("Failed to append blocks batch: \(httpResponse.statusCode) \(errorBody)")
            }
        }
    }

    // MARK: - Network

    private func notionRequest(
        path: String,
        method: String,
        apiKey: String,
        body: [String: Any]? = nil
    ) async throws -> (Data, URLResponse) {
        let maxAttempts = 3
        var lastError: Error?

        for attempt in 1...maxAttempts {
            let url = URL(string: baseURL + path)!
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue(notionVersion, forHTTPHeaderField: "Notion-Version")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 30

            if let body {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            }

            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                // Check if we should retry on transient errors
                if let httpResponse = response as? HTTPURLResponse {
                    let code = httpResponse.statusCode
                    let isTransient = code == 429 || (code >= 500 && code <= 599)

                    if isTransient && attempt < maxAttempts {
                        let backoff = pow(2.0, Double(attempt - 1)) // 1s, 2s, 4s
                        logger.warning("Notion API transient error \(code) on attempt \(attempt)/\(maxAttempts), retrying in \(backoff)s...")
                        try await Task.sleep(for: .seconds(backoff))
                        continue
                    }
                }

                return (data, response)
            } catch {
                lastError = error
                // Retry network errors (timeout, connection reset, etc.)
                if attempt < maxAttempts {
                    let backoff = pow(2.0, Double(attempt - 1))
                    logger.warning("Notion request failed on attempt \(attempt)/\(maxAttempts): \(error.localizedDescription), retrying in \(backoff)s...")
                    try await Task.sleep(for: .seconds(backoff))
                    continue
                }
            }
        }

        throw lastError ?? ExportError.networkError("Notion request failed after \(maxAttempts) attempts")
    }

    // MARK: - Block Helpers

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

    // MARK: - API Key Resolution

    private func resolveAPIKey(override: String?) throws -> String {
        if let override, !override.isEmpty {
            return override
        }
        if let stored = try keychain.loadAPIKey(for: "notion") {
            return stored
        }
        throw ExportError.apiKeyMissing("notion")
    }

    // MARK: - Error Translation

    private func translateNotionError(code: Int, body: String) -> ExportError {
        switch code {
        case 401:
            return ExportError.networkError("Notion API key is invalid or expired. Check Settings > API Keys.")
        case 403:
            return ExportError.networkError("Notion integration doesn't have access to the target page. In Notion, open the page, click Share, and add your Clio integration.")
        case 404:
            return ExportError.networkError("Notion page or database not found. It may have been deleted or the integration lost access.")
        case 409:
            return ExportError.networkError("Notion conflict error. The page may have been modified. Please try again.")
        case 429:
            return ExportError.networkError("Notion rate limit reached. Please wait a moment and try again.")
        case 500...599:
            return ExportError.networkError("Notion is experiencing issues. Please try again later.")
        default:
            // Try to extract a message from the JSON body
            if let data = body.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                return ExportError.networkError("Notion error: \(message)")
            }
            return ExportError.apiError(code, body)
        }
    }
}
