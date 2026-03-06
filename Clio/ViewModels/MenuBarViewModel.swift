import Foundation
import os

@MainActor
@Observable
final class MenuBarViewModel {
    var isRecording = false
    var isPaused = false
    var elapsedTimeFormatted = "00:00"
    var currentMeetingTitle: String?

    private let logger = Logger.ui

    /// Sync state from the main RecordingViewModel
    func syncState(from recording: RecordingViewModel) {
        isRecording = recording.isRecording
        isPaused = recording.isPaused
        elapsedTimeFormatted = recording.elapsedTime.durationFormatted
        currentMeetingTitle = recording.currentMeeting?.title
    }
}
