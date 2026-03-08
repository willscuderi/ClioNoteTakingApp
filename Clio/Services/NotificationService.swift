import Foundation
import UserNotifications
import os

/// Thin wrapper around UNUserNotificationCenter for recording state notifications.
/// Ensures the user always knows when Clio is recording, stops, or encounters issues.
///
/// All methods are safe to call even when `UNUserNotificationCenter` is unavailable
/// (e.g. in Xcode debug builds where the bundle identifier can't be resolved).
@MainActor
final class NotificationService {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "Notifications")

    /// Safely access UNUserNotificationCenter.
    /// Returns `nil` if the bundle identifier is unavailable (avoids NSException crash).
    private var center: UNUserNotificationCenter? {
        guard Bundle.main.bundleIdentifier != nil else {
            logger.debug("Skipping notification — no bundle identifier available")
            return nil
        }
        return UNUserNotificationCenter.current()
    }

    // MARK: - Permission

    func requestPermission() {
        guard let center else { return }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [logger] granted, error in
            if let error {
                logger.error("Notification permission error: \(error.localizedDescription)")
            } else {
                logger.info("Notification permission granted: \(granted)")
            }
        }
    }

    // MARK: - Recording Notifications

    func sendRecordingStarted(title: String) {
        let content = UNMutableNotificationContent()
        content.title = "Recording Started"
        content.body = title
        content.sound = nil // Silent — the UI already shows the recording indicator
        send(id: "recording-started", content: content)
    }

    func sendRecordingStopped(title: String, duration: String) {
        let content = UNMutableNotificationContent()
        content.title = "Recording Stopped"
        content.body = "\(title) — \(duration)"
        content.sound = .default
        send(id: "recording-stopped", content: content)
    }

    func sendAudioWarning(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Audio Warning"
        content.body = message
        content.sound = .default
        send(id: "audio-warning", content: content)
    }

    func sendCrashRecovered(meetingCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Meeting Recovered"
        content.body = "Clio recovered \(meetingCount) interrupted meeting\(meetingCount == 1 ? "" : "s"). Open Clio to review."
        content.sound = .default
        send(id: "crash-recovery", content: content)
    }

    func sendSummaryComplete(title: String) {
        let content = UNMutableNotificationContent()
        content.title = "Summary Ready"
        content.body = title
        content.sound = nil
        send(id: "summary-complete", content: content)
    }

    // MARK: - Private

    private func send(id: String, content: UNMutableNotificationContent) {
        guard let center else { return }

        let request = UNNotificationRequest(
            identifier: id + "-" + UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        center.add(request) { [logger] error in
            if let error {
                logger.error("Failed to send notification '\(id)': \(error.localizedDescription)")
            }
        }
    }
}
