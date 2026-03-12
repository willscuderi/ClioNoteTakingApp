import Foundation
import os

@MainActor
@Observable
final class SettingsViewModel {
    var openAIKey = ""
    var claudeKey = ""
    var geminiKey = ""
    var grokKey = ""
    var notionKey = ""
    var deepgramKey = ""
    var assemblyAIKey = ""
    var preferredTranscriptionSource: TranscriptionSource = .local
    var preferredLLMProvider: LLMProvider = .ollama
    var transcriptionAccuracy: TranscriptionAccuracy = .balanced {
        didSet {
            UserDefaults.standard.set(transcriptionAccuracy.rawValue, forKey: "transcriptionAccuracy")
        }
    }
    var enableRollingBuffer = false {
        didSet {
            UserDefaults.standard.set(enableRollingBuffer, forKey: "enableRollingBuffer")
        }
    }
    var rollingBufferMinutes = 3 {
        didSet {
            UserDefaults.standard.set(rollingBufferMinutes, forKey: "rollingBufferMinutes")
        }
    }
    var errorMessage: String?
    var successMessage: String?

    private let keychain: KeychainServiceProtocol
    private let logger = Logger.ui

    init(keychain: KeychainServiceProtocol) {
        self.keychain = keychain
    }

    func loadKeys() {
        openAIKey = (try? keychain.loadAPIKey(for: "openai")) ?? ""
        claudeKey = (try? keychain.loadAPIKey(for: "claude")) ?? ""
        geminiKey = (try? keychain.loadAPIKey(for: "gemini")) ?? ""
        grokKey = (try? keychain.loadAPIKey(for: "grok")) ?? ""
        notionKey = (try? keychain.loadAPIKey(for: "notion")) ?? ""
        deepgramKey = (try? keychain.loadAPIKey(for: "deepgram")) ?? ""
        assemblyAIKey = (try? keychain.loadAPIKey(for: "assemblyai")) ?? ""
        transcriptionAccuracy = TranscriptionAccuracy(rawValue: UserDefaults.standard.string(forKey: "transcriptionAccuracy") ?? "") ?? .balanced
        enableRollingBuffer = UserDefaults.standard.bool(forKey: "enableRollingBuffer")
        rollingBufferMinutes = max(1, min(5, UserDefaults.standard.integer(forKey: "rollingBufferMinutes")))
        if rollingBufferMinutes == 0 { rollingBufferMinutes = 3 }
    }

    /// Save a single key immediately when it changes.
    func saveKey(_ value: String, for provider: String) {
        do {
            if !value.isEmpty {
                try keychain.saveAPIKey(value, for: provider)
                logger.info("Saved \(provider) API key")
                showSuccess("Saved \(provider) key")
            }
            // Don't auto-delete on empty — that's what deleteKey is for
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Failed to save \(provider) key: \(error.localizedDescription)")
        }
    }

    /// Delete a specific API key.
    func deleteKey(for provider: String) {
        do {
            try keychain.delete(key: "apikey.\(provider)")
            // Clear the local property
            switch provider {
            case "openai": openAIKey = ""
            case "claude": claudeKey = ""
            case "gemini": geminiKey = ""
            case "grok": grokKey = ""
            case "notion": notionKey = ""
            case "deepgram": deepgramKey = ""
            case "assemblyai": assemblyAIKey = ""
            default: break
            }
            showSuccess("Removed \(provider) key")
            logger.info("Deleted \(provider) API key")
        } catch {
            // If key doesn't exist, that's fine
            switch provider {
            case "openai": openAIKey = ""
            case "claude": claudeKey = ""
            case "gemini": geminiKey = ""
            case "grok": grokKey = ""
            case "notion": notionKey = ""
            case "deepgram": deepgramKey = ""
            case "assemblyai": assemblyAIKey = ""
            default: break
            }
        }
    }

    /// Legacy bulk save — kept for compatibility but no longer the primary path.
    func saveKeys() {
        do {
            saveOrDelete(openAIKey, for: "openai")
            saveOrDelete(claudeKey, for: "claude")
            saveOrDelete(geminiKey, for: "gemini")
            saveOrDelete(grokKey, for: "grok")
            saveOrDelete(notionKey, for: "notion")
            saveOrDelete(deepgramKey, for: "deepgram")
            saveOrDelete(assemblyAIKey, for: "assemblyai")

            errorMessage = nil
            successMessage = "All API keys saved"
            logger.info("API keys saved")
        } catch {
            errorMessage = error.localizedDescription
            successMessage = nil
            logger.error("Failed to save API keys: \(error.localizedDescription)")
        }
    }

    private func saveOrDelete(_ value: String, for provider: String) {
        do {
            if !value.isEmpty {
                try keychain.saveAPIKey(value, for: provider)
            } else {
                try keychain.delete(key: "apikey.\(provider)")
            }
        } catch {
            logger.warning("Key operation for \(provider) failed: \(error.localizedDescription)")
        }
    }

    private func showSuccess(_ message: String) {
        successMessage = message
        // Auto-clear after 3 seconds
        Task {
            try? await Task.sleep(for: .seconds(3))
            if successMessage == message {
                successMessage = nil
            }
        }
    }
}
