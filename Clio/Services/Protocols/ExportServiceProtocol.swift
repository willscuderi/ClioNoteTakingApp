import Foundation

protocol ExportServiceProtocol: AnyObject {
    func exportMarkdown(meeting: Meeting) throws -> URL
    func exportToAppleNotes(meeting: Meeting) async throws
    func exportToNotion(meeting: Meeting, apiKey: String) async throws
}
