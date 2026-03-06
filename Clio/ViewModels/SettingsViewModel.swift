import Foundation
import os

@MainActor
@Observable
final class SettingsViewModel {
    var openAIKey = ""
    var claudeKey = ""
    var notionKey = ""
    var deepgramKey = ""
    var preferredTranscriptionSource: TranscriptionSource = .local
    var preferredLLMProvider: LLMProvider = .openai
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
        notionKey = (try? keychain.loadAPIKey(for: "notion")) ?? ""
        deepgramKey = (try? keychain.loadAPIKey(for: "deepgram")) ?? ""
    }

    func saveKeys() {
        do {
            if !openAIKey.isEmpty {
                try keychain.saveAPIKey(openAIKey, for: "openai")
            } else {
                try keychain.delete(key: "apikey.openai")
            }

            if !claudeKey.isEmpty {
                try keychain.saveAPIKey(claudeKey, for: "claude")
            } else {
                try keychain.delete(key: "apikey.claude")
            }

            if !notionKey.isEmpty {
                try keychain.saveAPIKey(notionKey, for: "notion")
            } else {
                try keychain.delete(key: "apikey.notion")
            }

            if !deepgramKey.isEmpty {
                try keychain.saveAPIKey(deepgramKey, for: "deepgram")
            } else {
                try keychain.delete(key: "apikey.deepgram")
            }

            errorMessage = nil
            successMessage = "API keys saved successfully"
            logger.info("API keys saved")
        } catch {
            errorMessage = error.localizedDescription
            successMessage = nil
            logger.error("Failed to save API keys: \(error.localizedDescription)")
        }
    }
}
