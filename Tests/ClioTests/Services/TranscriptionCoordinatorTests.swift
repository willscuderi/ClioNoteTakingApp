import Testing
import Foundation
@testable import Clio

@Suite("TranscriptionCoordinator Tests")
struct TranscriptionCoordinatorTests {
    @Test("Routes to local service by default")
    func defaultLocal() async throws {
        let keychain = KeychainService()
        let local = LocalTranscriptionService()
        let api = APITranscriptionService(keychain: keychain)
        let coordinator = TranscriptionCoordinator(local: local, api: api)

        #expect(coordinator.preferredSource == .local)
    }

    @Test("Switches preferred source")
    func switchSource() {
        let keychain = KeychainService()
        let local = LocalTranscriptionService()
        let api = APITranscriptionService(keychain: keychain)
        let coordinator = TranscriptionCoordinator(local: local, api: api)

        coordinator.preferredSource = .openAIWhisper
        #expect(coordinator.preferredSource == .openAIWhisper)
    }
}
