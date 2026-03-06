import Foundation
import Security
import os

final class KeychainService: KeychainServiceProtocol {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "Keychain")
    private let serviceName = "com.willscuderi.Clio"

    func save(key: String, data: Data) throws {
        // Delete existing item first
        try? delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            logger.error("Failed to save keychain item '\(key)': \(status)")
            throw KeychainError.saveFailed(status)
        }
        logger.debug("Saved keychain item '\(key)'")
    }

    func load(key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            logger.error("Failed to load keychain item '\(key)': \(status)")
            throw KeychainError.loadFailed(status)
        }
    }

    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Failed to delete keychain item '\(key)': \(status)")
            throw KeychainError.deleteFailed(status)
        }
    }

    func saveAPIKey(_ apiKey: String, for service: String) throws {
        guard let data = apiKey.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        try save(key: "apikey.\(service)", data: data)
    }

    func loadAPIKey(for service: String) throws -> String? {
        guard let data = try load(key: "apikey.\(service)") else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status): "Failed to save to Keychain (status: \(status))"
        case .loadFailed(let status): "Failed to load from Keychain (status: \(status))"
        case .deleteFailed(let status): "Failed to delete from Keychain (status: \(status))"
        case .encodingFailed: "Failed to encode data for Keychain"
        }
    }
}
