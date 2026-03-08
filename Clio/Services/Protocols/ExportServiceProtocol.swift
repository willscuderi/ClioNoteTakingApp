import Foundation

protocol ExportServiceProtocol: AnyObject {
    func exportMarkdown(meeting: Meeting) throws -> URL
    func exportToAppleNotes(meeting: Meeting) async throws
    @discardableResult func exportToNotion(meeting: Meeting, apiKey: String) async throws -> String
    func testNotionConnection(apiKey: String?) async -> (success: Bool, message: String)
    func autoSaveMeetingNotes(meeting: Meeting)
    func buildMarkdownContent(meeting: Meeting) -> String
}
