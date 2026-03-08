import Foundation
import os

final class ObsidianExportService {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "ObsidianExport")

    static let vaultPathKey = "obsidianVaultPath"

    /// Exports a meeting as a Markdown file to the configured Obsidian vault.
    /// Returns the file URL of the exported file.
    @discardableResult
    func export(meeting: Meeting, markdownContent: String) throws -> URL {
        guard let vaultPath = UserDefaults.standard.string(forKey: Self.vaultPathKey),
              !vaultPath.isEmpty else {
            throw ExportError.networkError("No Obsidian vault path configured. Set it in Settings > Export.")
        }

        let vaultURL = URL(fileURLWithPath: vaultPath)
        let folderURL = vaultURL.appendingPathComponent("Clio Meeting Notes", isDirectory: true)

        // Create the folder if it doesn't exist
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }

        let fileName = sanitizeFileName(meeting.title) + ".md"
        let fileURL = folderURL.appendingPathComponent(fileName)

        try markdownContent.write(to: fileURL, atomically: true, encoding: .utf8)

        logger.info("Exported meeting to Obsidian: \(fileURL.path)")
        return fileURL
    }

    private func sanitizeFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: invalid).joined(separator: "_")
    }
}
