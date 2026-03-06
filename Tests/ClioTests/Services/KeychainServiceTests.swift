import Testing
import Foundation
@testable import Clio

@Suite("KeychainService Tests")
struct KeychainServiceTests {
    // Note: These tests interact with the real Keychain.
    // In CI, they may need to run in a signed context.

    @Test("Save and load API key")
    func saveAndLoadAPIKey() throws {
        let service = KeychainService()
        let testKey = "test-api-key-\(UUID().uuidString)"

        try service.saveAPIKey(testKey, for: "test-service")
        let loaded = try service.loadAPIKey(for: "test-service")
        #expect(loaded == testKey)

        // Cleanup
        try service.delete(key: "apikey.test-service")
    }

    @Test("Load returns nil for missing key")
    func loadMissingKey() throws {
        let service = KeychainService()
        let loaded = try service.loadAPIKey(for: "nonexistent-service-\(UUID())")
        #expect(loaded == nil)
    }

    @Test("Delete removes key")
    func deleteKey() throws {
        let service = KeychainService()
        try service.saveAPIKey("temp-key", for: "temp-service")
        try service.delete(key: "apikey.temp-service")
        let loaded = try service.loadAPIKey(for: "temp-service")
        #expect(loaded == nil)
    }
}
