import Foundation
import SwiftData
import os

/// Periodically checkpoints active recording state to disk so that if the app crashes
/// mid-meeting, the user never loses more than 30 seconds of transcript.
@MainActor
final class CrashRecoveryService {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "CrashRecovery")
    private var checkpointTask: Task<Void, Never>?

    /// Info written to the recovery file each checkpoint
    private var currentMeetingID: UUID?
    private var currentTitle: String = ""
    private var currentCreatedAt: Date = Date()
    private var currentElapsedTime: TimeInterval = 0
    private var currentSegmentCount: Int = 0
    private var currentAudioSource: String = "microphone"

    // MARK: - Directory

    static let recoveryDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("com.willscuderi.Clio", isDirectory: true)
            .appendingPathComponent("Recovery", isDirectory: true)
    }()

    private static func ensureDirectory() {
        try? FileManager.default.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true)
    }

    private func recoveryFileURL(for meetingID: UUID) -> URL {
        Self.recoveryDirectory.appendingPathComponent("recovery-\(meetingID.uuidString).json")
    }

    // MARK: - Checkpointing

    /// Start periodic checkpointing for an active recording.
    func startCheckpointing(meeting: Meeting, audioSource: String) {
        Self.ensureDirectory()
        currentMeetingID = meeting.id
        currentTitle = meeting.title
        currentCreatedAt = meeting.createdAt
        currentElapsedTime = 0
        currentSegmentCount = 0
        currentAudioSource = audioSource

        // Write initial checkpoint immediately
        writeCheckpoint()

        // Then every 30 seconds
        checkpointTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                self?.writeCheckpoint()
            }
        }

        logger.info("Checkpointing started for meeting: \(meeting.title)")
    }

    /// Update checkpoint data (called from RecordingViewModel after each segment)
    func updateCheckpoint(elapsedTime: TimeInterval, segmentCount: Int) {
        currentElapsedTime = elapsedTime
        currentSegmentCount = segmentCount
    }

    /// Stop checkpointing (clean recording stop)
    func stopCheckpointing() {
        checkpointTask?.cancel()
        checkpointTask = nil
        logger.info("Checkpointing stopped")
    }

    /// Delete recovery file after a clean stop
    func deleteRecoveryFile(for meeting: Meeting) {
        let url = recoveryFileURL(for: meeting.id)
        try? FileManager.default.removeItem(at: url)
        currentMeetingID = nil
        logger.info("Recovery file deleted for: \(meeting.title)")
    }

    // MARK: - Recovery

    /// Check for orphaned recordings on launch.
    /// Returns meetings stuck in `.recording` or `.paused` status.
    func findOrphanedRecordings(in context: ModelContext) -> [Meeting] {
        // #Predicate doesn't support enum comparisons directly;
        // fetch all and filter in memory (meetings list is small)
        let descriptor = FetchDescriptor<Meeting>()

        do {
            let all = try context.fetch(descriptor)
            let orphaned = all.filter { $0.status == .recording || $0.status == .paused }
            if !orphaned.isEmpty {
                logger.warning("Found \(orphaned.count) orphaned recording(s)")
            }
            return orphaned
        } catch {
            logger.error("Failed to query orphaned recordings: \(error.localizedDescription)")
            return []
        }
    }

    /// Recover a meeting that was interrupted by a crash.
    /// Sets it to `.completed`, builds transcript, and cleans up recovery files.
    func recoverMeeting(_ meeting: Meeting, context: ModelContext) {
        meeting.status = .completed
        meeting.endedAt = meeting.endedAt ?? Date()

        // Build raw transcript from whatever segments were saved
        let transcript = meeting.fullTranscript
        if !transcript.isEmpty {
            meeting.rawTranscript = transcript
        }

        // Estimate duration from segments if not set
        if meeting.durationSeconds <= 0, let lastSegment = meeting.segments.max(by: { $0.endTime < $1.endTime }) {
            meeting.durationSeconds = lastSegment.endTime
        }

        try? context.save()

        // Clean up recovery file
        let url = recoveryFileURL(for: meeting.id)
        try? FileManager.default.removeItem(at: url)

        logger.info("Recovered meeting: \(meeting.title) with \(meeting.segments.count) segments")
    }

    /// Discard an orphaned meeting and its recovery file.
    func discardMeeting(_ meeting: Meeting, context: ModelContext) {
        let url = recoveryFileURL(for: meeting.id)
        try? FileManager.default.removeItem(at: url)
        context.delete(meeting)
        try? context.save()
        logger.info("Discarded orphaned meeting: \(meeting.title)")
    }

    // MARK: - File I/O

    private func writeCheckpoint() {
        guard let meetingID = currentMeetingID else { return }

        let checkpoint: [String: Any] = [
            "meetingID": meetingID.uuidString,
            "title": currentTitle,
            "createdAt": ISO8601DateFormatter().string(from: currentCreatedAt),
            "elapsedTime": currentElapsedTime,
            "segmentCount": currentSegmentCount,
            "audioSource": currentAudioSource,
            "lastCheckpoint": ISO8601DateFormatter().string(from: Date())
        ]

        let url = recoveryFileURL(for: meetingID)

        do {
            let data = try JSONSerialization.data(withJSONObject: checkpoint, options: [.prettyPrinted])
            try data.write(to: url, options: .atomic)
            logger.debug("Checkpoint written: \(self.currentSegmentCount) segments, \(String(format: "%.0f", self.currentElapsedTime))s elapsed")
        } catch {
            logger.error("Failed to write checkpoint: \(error.localizedDescription)")
        }
    }
}
