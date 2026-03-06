import Testing
import Foundation
@testable import Clio

@Suite("RecordingViewModel Tests")
@MainActor
struct RecordingViewModelTests {
    @Test("Initial state is not recording")
    func initialState() {
        let services = ServiceContainer.makeDefault()
        let vm = RecordingViewModel(services: services)
        #expect(vm.isRecording == false)
        #expect(vm.isPaused == false)
        #expect(vm.elapsedTime == 0)
        #expect(vm.currentMeeting == nil)
        #expect(vm.errorMessage == nil)
    }
}
