import Foundation

protocol KeychainServiceProtocol: AnyObject {
    func save(key: String, data: Data) throws
    func load(key: String) throws -> Data?
    func delete(key: String) throws
    func saveAPIKey(_ apiKey: String, for service: String) throws
    func loadAPIKey(for service: String) throws -> String?
}
