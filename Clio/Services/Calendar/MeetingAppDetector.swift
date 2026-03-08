import AppKit
import CoreAudio
import Foundation
import os

/// Detects when the user is actually in a meeting by monitoring microphone usage.
///
/// The key insight: just opening Teams/Zoom doesn't mean you're in a meeting.
/// A meeting starts when the microphone becomes active while a meeting app is running.
/// This also catches browser-based meetings (Google Meet, Zoom Web, etc.).
@MainActor
@Observable
final class MeetingAppDetector {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "MeetingDetect")

    // MARK: - Known Apps

    /// Apps that use voice/video calls. Only triggers when frontmost + mic active.
    private static let dedicatedMeetingApps: [String: String] = [
        // Video conferencing
        "us.zoom.xos": "Zoom",
        "com.microsoft.teams": "Microsoft Teams",
        "com.microsoft.teams2": "Microsoft Teams",
        "com.cisco.webexmeetingsapp": "Webex",
        "com.logmeininc.GoToMeeting": "GoToMeeting",
        // Communication apps with calling
        "com.tinyspeck.slackmacgap": "Slack",
        "com.hnc.Discord": "Discord",
        "com.apple.FaceTime": "FaceTime",
        "com.skype.skype": "Skype",
        "net.whatsapp.WhatsApp": "WhatsApp",
        "ru.keepcoder.Telegram": "Telegram",
        "com.ringcentral.glip": "RingCentral",
    ]

    /// Browsers that could be running Google Meet, Zoom Web, etc.
    private static let browserBundleIDs: Set<String> = [
        "com.google.Chrome",
        "com.apple.Safari",
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "org.mozilla.firefox",
        "company.thebrowser.Browser",  // Arc
        "com.operasoftware.Opera"
    ]

    // MARK: - Observable State

    var detectedMeetingApp: String?
    var shouldPromptRecording = false
    var isMonitoring = false

    // MARK: - Private State

    /// App name the user dismissed — reset when mic goes inactive (meeting ends)
    private var dismissedPromptForApp: String?

    /// Tracks whether Clio itself is recording (set by RecordingViewModel)
    var isRecordingInClio = false

    /// CoreAudio device we're monitoring
    private var micDeviceID: AudioObjectID = AudioObjectID(kAudioObjectUnknown)
    private var micListenerInstalled = false

    /// Stored listener blocks so we can remove them (CoreAudio requires same block reference)
    nonisolated(unsafe) private var micListenerBlock: AudioObjectPropertyListenerBlock?
    nonisolated(unsafe) private var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?

    /// Debounce task for mic activation
    private var micCheckTask: Task<Void, Never>?

    /// Tracks the frontmost app when the mic first activated (before debounce)
    private var frontmostAppAtMicActivation: String?

    /// Tracks extended mic sessions for unrecognized apps
    private var extendedMicTask: Task<Void, Never>?

    // MARK: - Detection Log File

    private static let logDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("com.willscuderi.Clio", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
    }()

    private static let logFileURL: URL = logDirectory.appendingPathComponent("detection.log")

    /// Append a timestamped entry to the detection log file.
    nonisolated private func logDetection(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"

        // Ensure directory exists (no-op if already present)
        try? FileManager.default.createDirectory(at: Self.logDirectory, withIntermediateDirectories: true)

        // Rotate if >1MB
        if let attrs = try? FileManager.default.attributesOfItem(atPath: Self.logFileURL.path),
           let size = attrs[.size] as? UInt64, size > 1_000_000 {
            let rotatedURL = Self.logDirectory.appendingPathComponent("detection.log.1")
            try? FileManager.default.removeItem(at: rotatedURL)
            try? FileManager.default.moveItem(at: Self.logFileURL, to: rotatedURL)
        }

        // Append
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: Self.logFileURL.path) {
                if let handle = try? FileHandle(forWritingTo: Self.logFileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: Self.logFileURL, options: .atomic)
            }
        }
    }

    // MARK: - Start / Stop

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        startMicrophoneMonitoring()

        // Also do an initial check in case a meeting is already in progress
        Task {
            try? await Task.sleep(for: .seconds(2))
            if isMicActiveOnDefaultDevice() {
                handleMicBecameActive()
            }
        }

        logger.info("Meeting detection started (mic-based)")
    }

    func stopMonitoring() {
        removeMicListener()
        removeDefaultDeviceListener()
        micCheckTask?.cancel()
        micCheckTask = nil
        isMonitoring = false
        logger.info("Meeting detection stopped")
    }

    private func removeDefaultDeviceListener() {
        guard let block = defaultDeviceListenerBlock else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main,
            block
        )
        defaultDeviceListenerBlock = nil
    }

    func dismissPrompt() {
        logDetection("[DETECT] User dismissed prompt for \(detectedMeetingApp ?? "unknown")")
        dismissedPromptForApp = detectedMeetingApp
        shouldPromptRecording = false
        detectedMeetingApp = nil
    }

    // MARK: - Microphone Monitoring (CoreAudio)

    private func startMicrophoneMonitoring() {
        // Get the default input device
        var deviceID = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        )

        guard status == noErr, deviceID != kAudioObjectUnknown else {
            logger.warning("Could not get default input device for meeting detection")
            return
        }

        micDeviceID = deviceID
        installMicListener()

        // Also listen for default device changes (user switches mic)
        var defaultDeviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let deviceBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                self?.handleDefaultDeviceChanged()
            }
        }
        defaultDeviceListenerBlock = deviceBlock

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            DispatchQueue.main,
            deviceBlock
        )

        logger.info("Monitoring mic device: \(deviceID)")
    }

    private func installMicListener() {
        guard micDeviceID != kAudioObjectUnknown else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                self?.handleMicStateChanged()
            }
        }
        micListenerBlock = block

        AudioObjectAddPropertyListenerBlock(
            micDeviceID,
            &address,
            DispatchQueue.main,
            block
        )

        micListenerInstalled = true
    }

    private func removeMicListener() {
        guard micListenerInstalled, micDeviceID != kAudioObjectUnknown,
              let block = micListenerBlock else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(micDeviceID, &address, DispatchQueue.main, block)
        micListenerBlock = nil
        micListenerInstalled = false
    }

    private func handleDefaultDeviceChanged() {
        removeMicListener()

        var deviceID = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        )

        guard status == noErr, deviceID != kAudioObjectUnknown else { return }
        micDeviceID = deviceID
        installMicListener()
        logDetection("[DETECT] Default input device changed to \(deviceID)")
        logger.info("Default input device changed, now monitoring: \(deviceID)")
    }

    // MARK: - Mic State Change Handler

    private func handleMicStateChanged() {
        let isActive = isMicActiveOnDefaultDevice()

        if isActive {
            handleMicBecameActive()
        } else {
            // Mic stopped — meeting likely ended
            micCheckTask?.cancel()
            micCheckTask = nil
            extendedMicTask?.cancel()
            extendedMicTask = nil

            if shouldPromptRecording {
                // Meeting ended while prompt was showing, dismiss it
                shouldPromptRecording = false
                detectedMeetingApp = nil
            }
            // Reset dismissed state so the NEXT meeting triggers a new prompt
            dismissedPromptForApp = nil
            frontmostAppAtMicActivation = nil

            logDetection("[DETECT] Mic became inactive, resetting")
            logger.info("Mic became inactive — resetting meeting detection")
        }
    }

    private func handleMicBecameActive() {
        // Don't prompt if Clio is already recording
        guard !isRecordingInClio else { return }

        // Snapshot the frontmost app right now (before debounce delay)
        frontmostAppAtMicActivation = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        logDetection("[DETECT] Mic became active, frontmost: \(frontmostAppAtMicActivation ?? "none")")

        // Debounce: wait 3 seconds to confirm mic is sustained (not a brief blip)
        micCheckTask?.cancel()
        micCheckTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            guard let self else { return }

            // Still active after 3 seconds? Check for meeting app.
            guard self.isMicActiveOnDefaultDevice(), !self.isRecordingInClio else { return }
            self.logDetection("[DETECT] Debounce passed, checking apps...")
            self.detectActiveMeeting()
        }
    }

    // MARK: - Meeting Detection

    /// Only prompts when the **frontmost app** is a meeting app or browser.
    ///
    /// This avoids false positives from apps like Wispr Flow or Siri activating
    /// the mic while Teams/Zoom happen to be running in the background.
    /// We check both the frontmost app at the moment the mic activated AND
    /// the current frontmost app (in case the user switched away briefly).
    private func detectActiveMeeting() {
        let currentFrontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let candidates = Set([frontmostAppAtMicActivation, currentFrontmost].compactMap { $0 })

        // 1. Check if the frontmost app (now or when mic activated) is a dedicated meeting app
        for bundleID in candidates {
            if let appName = Self.dedicatedMeetingApps[bundleID] {
                guard dismissedPromptForApp != appName else { continue }

                detectedMeetingApp = appName
                shouldPromptRecording = true
                logDetection("[DETECT] Meeting detected: \(appName)")
                logger.info("Meeting detected: \(appName) is frontmost with mic active")
                return
            }
        }

        // 2. Check if the frontmost app is a browser (Google Meet, Zoom Web, etc.)
        for bundleID in candidates {
            if Self.browserBundleIDs.contains(bundleID) {
                let appName = "Video call"
                guard dismissedPromptForApp != appName else { return }

                detectedMeetingApp = appName
                shouldPromptRecording = true
                logDetection("[DETECT] Browser-based meeting detected: \(bundleID)")
                logger.info("Browser-based meeting detected: \(bundleID) is frontmost with mic active")
                return
            }
        }

        let candidateStr = candidates.joined(separator: ", ")
        logDetection("[DETECT] Ignored: frontmost app not a meeting app (\(candidateStr))")
        logger.info("Mic active but frontmost app is not a meeting app — ignoring")

        // Fallback: if mic stays active for >60s without a known app, log for debugging
        extendedMicTask?.cancel()
        extendedMicTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled else { return }
            guard let self, self.isMicActiveOnDefaultDevice() else { return }
            self.logDetection("[DETECT] Unrecognized audio session >60s, frontmost: \(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none")")
        }
    }

    // MARK: - CoreAudio Helpers

    private func isMicActiveOnDefaultDevice() -> Bool {
        guard micDeviceID != kAudioObjectUnknown else { return false }

        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(micDeviceID, &address, 0, nil, &size, &isRunning)
        return status == noErr && isRunning != 0
    }

    // MARK: - Legacy API (for compatibility)

    /// Check if any meeting app is currently running
    func checkRunningMeetingApps() -> String? {
        let running = NSWorkspace.shared.runningApplications
        for app in running {
            if let bundleID = app.bundleIdentifier,
               Self.dedicatedMeetingApps[bundleID] != nil {
                return Self.dedicatedMeetingApps[bundleID] ?? app.localizedName
            }
        }
        return nil
    }
}
