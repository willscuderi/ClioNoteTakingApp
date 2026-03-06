import Combine

enum HotkeyAction: String, CaseIterable {
    case toggleRecording
    case pauseResume
    case addBookmark
}

protocol HotkeyServiceProtocol: AnyObject {
    var hotkeyTriggered: AnyPublisher<HotkeyAction, Never> { get }

    func register(keyCode: UInt16, modifiers: UInt, for action: HotkeyAction) throws
    func unregister(action: HotkeyAction)
    func unregisterAll()
}
