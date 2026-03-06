import AVFoundation
import Foundation
import SwiftData
import Combine
import os

@MainActor
@Observable
final class RecordingViewModel {
    var isRecording = false
    var isPaused = false
    var elapsedTime: TimeInterval = 0
    var audioLevel: Float = 0
    var currentMeeting: Meeting?
    var errorMessage: String?
    var audioSource: AudioSource = .systemAudio

    private let services: ServiceContainer
    private var timerTask: Task<Void, Never>?
    private var audioLevelTask: Task<Void, Never>?
    private var transcriptionTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger.audio

    /// Running count of seconds transcribed, for segment timestamps
    private var transcribedSeconds: Double = 0

    init(services: ServiceContainer) {
        self.services = services
    }

    func startRecording(context: ModelContext) async {
        guard !isRecording else { return }

        do {
            let meeting = Meeting(title: "Meeting \(Date().meetingDateFormatted)")
            context.insert(meeting)
            currentMeeting = meeting

            try await services.audioCapture.startCapture(source: audioSource)
            try await services.transcription.startTranscription()

            isRecording = true
            isPaused = false
            elapsedTime = 0
            transcribedSeconds = 0
            errorMessage = nil

            startTimer()
            startAudioLevelPolling()
            startTranscriptionPipeline(context: context)

            logger.info("Recording started: \(meeting.title)")
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Failed to start recording: \(error.localizedDescription)")
        }
    }

    func stopRecording(context: ModelContext) async {
        guard isRecording else { return }

        do {
            // Stop pipeline
            stopTranscriptionPipeline()
            stopAudioLevelPolling()
            stopTimer()

            try await services.transcription.stopTranscription()
            try await services.audioCapture.stopCapture()

            isRecording = false
            isPaused = false

            if let meeting = currentMeeting {
                meeting.status = .completed
                meeting.endedAt = Date()
                meeting.durationSeconds = elapsedTime
                // Build raw transcript from segments
                meeting.rawTranscript = meeting.fullTranscript
                try? context.save()
            }

            logger.info("Recording stopped, duration: \(self.elapsedTime.durationFormatted)")
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Failed to stop recording: \(error.localizedDescription)")
        }
    }

    func togglePause() async {
        guard isRecording else { return }

        do {
            if isPaused {
                try await services.audioCapture.resumeCapture()
                startTimer()
                startAudioLevelPolling()
            } else {
                try await services.audioCapture.pauseCapture()
                stopTimer()
                stopAudioLevelPolling()
            }
            isPaused.toggle()
            currentMeeting?.status = isPaused ? .paused : .recording
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addBookmark(context: ModelContext, label: String = "") {
        guard let meeting = currentMeeting else { return }
        let bookmark = Bookmark(label: label, timestamp: elapsedTime)
        bookmark.meeting = meeting
        meeting.bookmarks.append(bookmark)
        try? context.save()
        logger.info("Bookmark added at \(self.elapsedTime.durationFormatted)")
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                self?.elapsedTime += 1
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    // MARK: - Audio Level Polling

    private func startAudioLevelPolling() {
        audioLevelTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { break }
                self?.audioLevel = self?.services.audioCapture.audioLevel ?? 0
            }
        }
    }

    private func stopAudioLevelPolling() {
        audioLevelTask?.cancel()
        audioLevelTask = nil
        audioLevel = 0
    }

    // MARK: - Transcription Pipeline

    /// Connect audio buffer chunks to transcription service
    private func startTranscriptionPipeline(context: ModelContext) {
        // Get the buffer manager from the audio coordinator
        guard let coordinator = services.audioCapture as? AudioCaptureCoordinator else {
            logger.warning("Audio capture is not an AudioCaptureCoordinator, transcription pipeline not connected")
            return
        }

        // Subscribe to audio chunks and send each to transcription
        coordinator.bufferManager.chunkPublisher
            .sink { [weak self] buffer in
                guard let self else { return }
                Task { @MainActor in
                    await self.transcribeChunk(buffer, context: context)
                }
            }
            .store(in: &cancellables)

        logger.info("Transcription pipeline connected")
    }

    private func stopTranscriptionPipeline() {
        cancellables.removeAll()
        transcriptionTask?.cancel()
        transcriptionTask = nil
    }

    private func transcribeChunk(_ buffer: AVAudioPCMBuffer, context: ModelContext) async {
        guard let meeting = currentMeeting else { return }

        do {
            let chunkDuration = Double(buffer.frameLength) / buffer.format.sampleRate

            if let segment = try await services.transcription.transcribeBuffer(buffer) {
                // Set accurate timestamps
                segment.startTime = transcribedSeconds
                segment.endTime = transcribedSeconds + chunkDuration
                segment.meeting = meeting
                meeting.segments.append(segment)
                context.insert(segment)
                try? context.save()
            }

            transcribedSeconds += chunkDuration
        } catch {
            logger.error("Transcription failed for chunk: \(error.localizedDescription)")
            // Don't set errorMessage for individual chunk failures — keep recording
        }
    }
}
