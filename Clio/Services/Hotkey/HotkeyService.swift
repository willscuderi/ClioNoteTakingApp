import AppKit
import Combine
import os

final class HotkeyService: HotkeyServiceProtocol {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "Hotkey")
    private let hotkeySubject = PassthroughSubject<HotkeyAction, Never>()
    private var monitors: [HotkeyAction: Any] = [:]
    private var registeredShortcuts: [HotkeyAction: (keyCode: UInt16, modifiers: UInt)] = [:]

    var hotkeyTriggered: AnyPublisher<HotkeyAction, Never> {
        hotkeySubject.eraseToAnyPublisher()
    }

    /// Register a global keyboard shortcut for an action.
    /// Uses NSEvent global monitor (works without accessibility permissions for modifier+key combos).
    func register(keyCode: UInt16, modifiers: UInt, for action: HotkeyAction) throws {
        // Remove existing monitor for this action
        unregister(action: action)

        let nsModifiers = NSEvent.ModifierFlags(rawValue: modifiers)

        // Local monitor (when app is frontmost)
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == keyCode && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == nsModifiers {
                self?.hotkeySubject.send(action)
                self?.logger.debug("Hotkey triggered (local): \(action.rawValue)")
                return nil // Consume the event
            }
            return event
        }

        // Global monitor (when app is in background)
        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == keyCode && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == nsModifiers {
                self?.hotkeySubject.send(action)
                self?.logger.debug("Hotkey triggered (global): \(action.rawValue)")
            }
        }

        monitors[action] = (localMonitor, globalMonitor) as AnyObject
        registeredShortcuts[action] = (keyCode, modifiers)
        logger.info("Registered hotkey for \(action.rawValue): keyCode=\(keyCode) modifiers=\(modifiers)")
    }

    func unregister(action: HotkeyAction) {
        if let monitor = monitors.removeValue(forKey: action) {
            if let pair = monitor as? (Any?, Any?) {
                if let local = pair.0 { NSEvent.removeMonitor(local) }
                if let global = pair.1 { NSEvent.removeMonitor(global) }
            }
        }
        registeredShortcuts.removeValue(forKey: action)
        logger.info("Unregistered hotkey for \(action.rawValue)")
    }

    func unregisterAll() {
        for action in HotkeyAction.allCases {
            unregister(action: action)
        }
        logger.info("Unregistered all hotkeys")
    }

    /// Register default keyboard shortcuts
    func registerDefaults() {
        // ⌘⇧R — Toggle Recording (keyCode 15 = R)
        try? register(
            keyCode: 15,
            modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue,
            for: .toggleRecording
        )

        // ⌘⇧P — Pause/Resume (keyCode 35 = P)
        try? register(
            keyCode: 35,
            modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue,
            for: .pauseResume
        )

        // ⌘⇧B — Add Bookmark (keyCode 11 = B)
        try? register(
            keyCode: 11,
            modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue,
            for: .addBookmark
        )

        logger.info("Registered default hotkeys")
    }

    deinit {
        unregisterAll()
    }
}
