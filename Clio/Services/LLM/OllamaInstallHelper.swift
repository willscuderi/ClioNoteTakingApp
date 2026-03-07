import AppKit
import Foundation
import os

/// Checks if Ollama is installed and helps users install it via Homebrew.
@MainActor
@Observable
final class OllamaInstallHelper {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "OllamaInstall")

    enum InstallState: Equatable {
        case unknown
        case checking
        case installed
        case notInstalled
        case installing
        case installFailed(String)
    }

    var state: InstallState = .unknown

    /// Whether Ollama is currently reachable (running and responding)
    var isReachable = false

    /// Check if Ollama is installed and reachable
    func check() async {
        state = .checking

        // First check if the binary exists
        let ollamaPath = "/usr/local/bin/ollama"
        let homebrewOllamaPath = "/opt/homebrew/bin/ollama"
        let appPath = "/Applications/Ollama.app"

        let binaryExists = FileManager.default.fileExists(atPath: ollamaPath)
            || FileManager.default.fileExists(atPath: homebrewOllamaPath)
            || FileManager.default.fileExists(atPath: appPath)

        // Also check if the API is reachable (Ollama could be installed but not running)
        let reachable = await checkReachable()
        isReachable = reachable

        if binaryExists || reachable {
            state = .installed
        } else {
            state = .notInstalled
        }
    }

    /// Open Terminal and run the Ollama install command via Homebrew
    func installViaHomebrew() {
        state = .installing
        logger.info("Opening Terminal to install Ollama via Homebrew")

        let script = """
        tell application "Terminal"
            activate
            do script "echo '🦙 Installing Ollama...' && brew install ollama && echo '' && echo '✅ Ollama installed! Starting Ollama...' && ollama serve &; sleep 2 && ollama pull llama3.2 && echo '' && echo '🎉 All done! You can close this window and go back to Clio.'"
        end tell
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            if let error {
                let msg = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                logger.error("Failed to open Terminal: \(msg)")
                state = .installFailed(msg)
            }
        }
    }

    /// Open the Ollama website download page as a fallback
    func openDownloadPage() {
        if let url = URL(string: "https://ollama.com/download/mac") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Check if Homebrew is installed
    func isHomebrewInstalled() -> Bool {
        FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew")
            || FileManager.default.fileExists(atPath: "/usr/local/bin/brew")
    }

    private func checkReachable() async -> Bool {
        guard let url = URL(string: "http://localhost:11434/api/tags") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
