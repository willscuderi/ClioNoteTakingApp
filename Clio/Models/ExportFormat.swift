import Foundation

enum ExportFormat: String, CaseIterable, Identifiable {
    case markdown
    case appleNotes
    case notion
    case obsidian
    case googleDocs

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .markdown: "Markdown"
        case .appleNotes: "Apple Notes"
        case .notion: "Notion"
        case .obsidian: "Obsidian"
        case .googleDocs: "Google Docs"
        }
    }

    var iconName: String {
        switch self {
        case .markdown: "doc.text"
        case .appleNotes: "note.text"
        case .notion: "square.and.arrow.up"
        case .obsidian: "diamond"
        case .googleDocs: "doc.richtext"
        }
    }

    var setupDescription: String {
        switch self {
        case .appleNotes: "No setup needed"
        case .notion: "Paste your integration token"
        case .obsidian: "Pick your vault folder"
        case .markdown: "Pick a folder to save notes"
        case .googleDocs: "Sign in with Google"
        }
    }

    var requiresSetup: Bool {
        switch self {
        case .appleNotes: false
        default: true
        }
    }
}
