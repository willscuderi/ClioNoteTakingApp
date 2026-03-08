import Foundation
import os

/// Auto-backs up meeting notes to a user-chosen folder (iCloud Drive, Google Drive, etc.)
/// Folder structure: {backupFolder}/{YYYY}/{MM - MonthName}/{YYYY-MM-DD}/{sanitized-title}.md
@MainActor
@Observable
final class BackupService {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "Backup")

    var backupFolderPath: String? {
        get { UserDefaults.standard.string(forKey: "backupFolderPath") }
        set { UserDefaults.standard.set(newValue, forKey: "backupFolderPath") }
    }

    var isEnabled: Bool {
        backupFolderPath != nil
    }

    /// Backup a meeting's markdown content to the configured backup folder
    func backupMeeting(_ meeting: Meeting, export: ExportServiceProtocol) {
        guard let basePath = backupFolderPath else {
            logger.info("Backup skipped: no backup folder configured")
            return
        }

        let baseURL = URL(fileURLWithPath: basePath)
        let date = meeting.createdAt

        // Build folder path: Year/MM - MonthName/YYYY-MM-DD
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"
        let monthName = monthFormatter.string(from: date)
        let monthFolder = String(format: "%02d - %@", month, monthName)

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let dayFolder = dayFormatter.string(from: date)

        let folderURL = baseURL
            .appendingPathComponent(String(year))
            .appendingPathComponent(monthFolder)
            .appendingPathComponent(dayFolder)

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

            let markdown = export.buildMarkdownContent(meeting: meeting)
            let fileName = sanitizeFileName(meeting.title) + ".md"
            let fileURL = folderURL.appendingPathComponent(fileName)

            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
            logger.info("Meeting backed up to: \(fileURL.path)")
        } catch {
            logger.error("Backup failed for '\(meeting.title)': \(error.localizedDescription)")
        }
    }

    // MARK: - Suggested Paths

    /// Returns detected cloud storage paths that exist on this Mac
    var suggestedBackupPaths: [(name: String, path: String)] {
        var paths: [(String, String)] = []

        // iCloud Drive
        let iCloudPath = NSHomeDirectory() + "/Library/Mobile Documents/com~apple~CloudDocs/Clio Meeting Notes"
        let iCloudParent = NSHomeDirectory() + "/Library/Mobile Documents/com~apple~CloudDocs"
        if FileManager.default.fileExists(atPath: iCloudParent) {
            paths.append(("iCloud Drive", iCloudPath))
        }

        // Google Drive
        let cloudStoragePath = NSHomeDirectory() + "/Library/CloudStorage"
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: cloudStoragePath) {
            for folder in contents where folder.hasPrefix("GoogleDrive") {
                let gdrivePath = cloudStoragePath + "/\(folder)/My Drive/Clio Meeting Notes"
                paths.append(("Google Drive", gdrivePath))
                break
            }
        }

        // Dropbox
        let dropboxPath = NSHomeDirectory() + "/Library/CloudStorage/Dropbox/Clio Meeting Notes"
        let dropboxParent = NSHomeDirectory() + "/Library/CloudStorage/Dropbox"
        if FileManager.default.fileExists(atPath: dropboxParent) {
            paths.append(("Dropbox", dropboxPath))
        }

        // OneDrive
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: cloudStoragePath) {
            for folder in contents where folder.hasPrefix("OneDrive") {
                let oneDrivePath = cloudStoragePath + "/\(folder)/Clio Meeting Notes"
                paths.append(("OneDrive", oneDrivePath))
                break
            }
        }

        return paths
    }

    private func sanitizeFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: invalid).joined(separator: "_")
    }
}
