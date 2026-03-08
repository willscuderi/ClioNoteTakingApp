import AVFoundation
import Foundation
import ScreenCaptureKit
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
    var audioSource: AudioSource = .microphone
    var segmentCount: Int = 0
    var transcriptionStatus: String?

    private let services: ServiceContainer
    private var timerTask: Task<Void, Never>?
    private var audioLevelTask: Task<Void, Never>?
    private var transcriptionTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger.audio

    /// Running count of seconds transcribed per channel, for segment timestamps
    private var transcribedSeconds: Double = 0
    private var micTranscribedSeconds: Double = 0
    private var systemTranscribedSeconds: Double = 0

    /// Tracks when the last audio chunk was received (for watchdog)
    private var lastAudioChunkTime: Date = Date()
    /// Whether the audio warning has been shown (to avoid spamming)
    private var audioWarningShown = false

    init(services: ServiceContainer) {
        self.services = services
    }

    func startRecording(context: ModelContext) async {
        guard !isRecording else { return }

        // Check permissions before attempting capture
        let effectiveSource = await resolveAudioSource()
        guard let source = effectiveSource else {
            errorMessage = "No audio permissions granted. Open System Settings \u{2192} Privacy & Security to grant Microphone and Screen Recording access, then restart Clio."
            logger.error("No audio permissions available")
            return
        }

        do {
            let meeting = Meeting(title: "Meeting \(Date().meetingDateFormatted)")
            context.insert(meeting)
            currentMeeting = meeting

            // Set selected microphone device before starting capture
            if let coordinator = services.audioCapture as? AudioCaptureCoordinator {
                coordinator.microphone.deviceID = services.audioDevices.selectedDeviceID
            }

            try await services.audioCapture.startCapture(source: source)
            audioSource = source
            try await services.transcription.startTranscription()

            isRecording = true
            services.meetingDetector.isRecordingInClio = true
            isPaused = false
            elapsedTime = 0
            transcribedSeconds = 0
            micTranscribedSeconds = 0
            systemTranscribedSeconds = 0
            segmentCount = 0
            transcriptionStatus = "Waiting for audio..."
            errorMessage = nil

            lastAudioChunkTime = Date()
            audioWarningShown = false

            startTimer()
            startAudioLevelPolling()
            startTranscriptionPipeline(context: context)
            startWatchdog()

            // Crash recovery: start checkpointing
            services.recovery.startCheckpointing(meeting: meeting, audioSource: source.rawValue)

            // System notification
            services.notifications.sendRecordingStarted(title: meeting.title)

            logger.info("Recording started: \(meeting.title)")
        } catch {
            if let meeting = currentMeeting {
                context.delete(meeting)
                currentMeeting = nil
            }
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            logger.error("Failed to start recording: \(error.localizedDescription)")
        }
    }

    /// Check which audio sources are actually available and fall back gracefully.
    /// Requests permissions if not yet determined.
    private func resolveAudioSource() async -> AudioSource? {
        // Request mic permission if not yet determined
        var micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        if !micGranted && AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            micGranted = await AVCaptureDevice.requestAccess(for: .audio)
            logger.info("Microphone permission requested, granted: \(micGranted)")
        }

        // Check screen recording (SCShareableContent triggers its own system prompt)
        var screenGranted = false
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            screenGranted = !content.displays.isEmpty
        } catch {
            screenGranted = false
        }

        logger.info("Permissions — mic: \(micGranted), screen: \(screenGranted)")

        switch audioSource {
        case .systemAudio:
            if screenGranted { return .systemAudio }
            if micGranted {
                logger.warning("Screen recording not available, falling back to microphone")
                errorMessage = "Screen recording permission not detected. Recording with microphone only. You may need to restart Clio after granting Screen Recording in System Settings."
                return .microphone
            }
            return nil
        case .microphone:
            if micGranted { return .microphone }
            return nil
        case .both:
            if screenGranted && micGranted { return .both }
            if screenGranted { return .systemAudio }
            if micGranted { return .microphone }
            return nil
        }
    }

    func stopRecording(context: ModelContext) async {
        guard isRecording else { return }

        do {
            stopAudioLevelPolling()
            stopTimer()
            stopWatchdog()

            // Stop crash recovery checkpointing
            services.recovery.stopCheckpointing()

            // Flush remaining audio BEFORE disconnecting the transcription subscribers.
            // stopCapture() calls bufferManager.flush() which emits any partial chunk,
            // and the Combine sink is still active to receive and transcribe it.
            try await services.audioCapture.stopCapture()

            // Give the flushed chunk time to be transcribed
            try? await Task.sleep(for: .milliseconds(500))

            // Now disconnect the pipeline
            stopTranscriptionPipeline()
            try await services.transcription.stopTranscription()

            isRecording = false
            services.meetingDetector.isRecordingInClio = false
            isPaused = false

            if let meeting = currentMeeting {
                meeting.status = .completed
                meeting.endedAt = Date()
                meeting.durationSeconds = elapsedTime
                // Build raw transcript from segments
                meeting.rawTranscript = meeting.fullTranscript
                try? context.save()

                // Clean up recovery file (clean stop)
                services.recovery.deleteRecoveryFile(for: meeting)

                // System notification
                services.notifications.sendRecordingStopped(
                    title: meeting.title,
                    duration: elapsedTime.durationFormatted
                )

                // Auto-save markdown to local MeetingNotes folder
                services.export.autoSaveMeetingNotes(meeting: meeting)

                // Auto-backup to user-configured backup folder
                services.backup.backupMeeting(meeting, export: services.export)

                // Auto-generate summary if transcript is available
                if !meeting.fullTranscript.isEmpty {
                    await autoGenerateSummary(for: meeting, context: context)
                }
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

    // MARK: - Audio Watchdog

    /// Monitors for audio pipeline stalls — warns if no audio chunks arrive for >10 seconds.
    private func startWatchdog() {
        watchdogTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                guard let self, self.isRecording, !self.isPaused else { continue }

                let silenceDuration = Date().timeIntervalSince(self.lastAudioChunkTime)
                if silenceDuration > 10 && !self.audioWarningShown {
                    self.audioWarningShown = true
                    self.transcriptionStatus = "⚠️ No audio detected for \(Int(silenceDuration))s — check your microphone"
                    self.services.notifications.sendAudioWarning(
                        message: "Clio may have lost audio input. Check your microphone."
                    )
                    self.logger.warning("Audio watchdog: no chunks for \(Int(silenceDuration))s")
                }
            }
        }
    }

    private func stopWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = nil
    }

    // MARK: - Transcription Pipeline

    /// Connect audio buffer chunks to transcription service
    private func startTranscriptionPipeline(context: ModelContext) {
        // Get the buffer manager from the audio coordinator
        guard let coordinator = services.audioCapture as? AudioCaptureCoordinator else {
            logger.warning("Audio capture is not an AudioCaptureCoordinator, transcription pipeline not connected")
            return
        }

        if audioSource == .both {
            // In "Both" mode, subscribe to each channel separately for speaker separation
            coordinator.micBufferManager.chunkPublisher
                .sink { [weak self] buffer in
                    guard let self else { return }
                    Task { @MainActor in
                        await self.transcribeChunk(buffer, context: context, speakerLabel: "You")
                    }
                }
                .store(in: &cancellables)

            coordinator.systemBufferManager.chunkPublisher
                .sink { [weak self] buffer in
                    guard let self else { return }
                    Task { @MainActor in
                        await self.transcribeChunk(buffer, context: context, speakerLabel: "Remote")
                    }
                }
                .store(in: &cancellables)

            logger.info("Transcription pipeline connected (dual-channel: You + Remote)")
        } else {
            // Single source — use combined buffer manager, no speaker label
            coordinator.bufferManager.chunkPublisher
                .sink { [weak self] buffer in
                    guard let self else { return }
                    Task { @MainActor in
                        await self.transcribeChunk(buffer, context: context, speakerLabel: nil)
                    }
                }
                .store(in: &cancellables)

            logger.info("Transcription pipeline connected (single channel)")
        }
    }

    private func stopTranscriptionPipeline() {
        cancellables.removeAll()
        transcriptionTask?.cancel()
        transcriptionTask = nil
    }

    private func transcribeChunk(_ buffer: AVAudioPCMBuffer, context: ModelContext, speakerLabel: String?) async {
        guard let meeting = currentMeeting else { return }

        // Update watchdog — we got audio
        lastAudioChunkTime = Date()
        audioWarningShown = false

        let chunkDuration = Double(buffer.frameLength) / buffer.format.sampleRate
        let channelTag = speakerLabel.map { "[\($0)] " } ?? ""
        logger.info("\(channelTag)Processing audio chunk: \(String(format: "%.1f", chunkDuration))s, frames: \(buffer.frameLength)")

        do {
            transcriptionStatus = "Transcribing..."

            // Use diarization path for AssemblyAI (returns multiple speaker-labeled segments)
            if let coordinator = services.transcription as? TranscriptionCoordinator,
               coordinator.preferredSource == .assemblyAI {
                let segments = try await coordinator.transcribeBufferWithDiarization(buffer)
                if segments.isEmpty {
                    transcriptionStatus = "Listening... (no speech detected)"
                    logger.info("\(channelTag)No speech detected in chunk")
                } else {
                    let chunkStartTime = elapsedTime - chunkDuration
                    for segment in segments {
                        // Adjust timestamps relative to recording session
                        let relativeStart = segment.startTime // Already in seconds from AssemblyAI
                        let relativeEnd = segment.endTime
                        segment.startTime = chunkStartTime + relativeStart
                        segment.endTime = chunkStartTime + relativeEnd
                        // Don't override speakerLabel — AssemblyAI already set "Speaker A" etc.
                        segment.meeting = meeting
                        meeting.segments.append(segment)
                        context.insert(segment)
                        segmentCount += 1
                        logger.info("[\(segment.speakerLabel ?? "?")] Transcribed segment \(self.segmentCount): \(segment.text.prefix(60))")
                    }
                    try? context.save()
                    transcriptionStatus = "\(segmentCount) segment\(segmentCount == 1 ? "" : "s") transcribed"
                    services.recovery.updateCheckpoint(elapsedTime: elapsedTime, segmentCount: segmentCount)
                }
            } else {
                // Standard single-segment path for local/OpenAI
                if let segment = try await services.transcription.transcribeBuffer(buffer) {
                    // Use elapsed time for ordering (so mic and system segments interleave correctly)
                    segment.startTime = elapsedTime - chunkDuration
                    segment.endTime = elapsedTime
                    segment.speakerLabel = speakerLabel
                    segment.meeting = meeting
                    meeting.segments.append(segment)
                    context.insert(segment)
                    try? context.save()
                    segmentCount += 1
                    transcriptionStatus = "\(segmentCount) segment\(segmentCount == 1 ? "" : "s") transcribed"

                    // Update crash recovery checkpoint
                    services.recovery.updateCheckpoint(elapsedTime: elapsedTime, segmentCount: segmentCount)

                    logger.info("\(channelTag)Transcribed segment \(self.segmentCount): \(segment.text.prefix(60))")
                } else {
                    transcriptionStatus = "Listening... (no speech detected)"
                    logger.info("\(channelTag)No speech detected in chunk")
                }
            }

            // Advance per-channel counters
            switch speakerLabel {
            case "You":     micTranscribedSeconds += chunkDuration
            case "Remote":  systemTranscribedSeconds += chunkDuration
            default:        transcribedSeconds += chunkDuration
            }
        } catch {
            logger.error("\(channelTag)Transcription error: \(error.localizedDescription)")
            transcriptionStatus = "Transcription error: \(error.localizedDescription)"
            if errorMessage == nil {
                errorMessage = "Transcription error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Auto Summary & Export

    /// Status for the post-recording processing pipeline
    var postProcessingStatus: String?
    var isPostProcessing = false

    private func autoGenerateSummary(for meeting: Meeting, context: ModelContext) async {
        let provider = LLMProvider(rawValue: UserDefaults.standard.string(forKey: "preferredLLMProvider") ?? "") ?? .ollama
        let modelID = UserDefaults.standard.string(forKey: "preferredLLMModel") ?? ""
        let model = provider.availableModels.first(where: { $0.id == modelID }) ?? provider.defaultModel

        guard services.llm.isConfigured(provider: provider) else {
            logger.info("Skipping auto-summary: \(provider.displayName) not configured")
            return
        }

        isPostProcessing = true
        postProcessingStatus = "Generating summary with \(model.displayName)..."
        logger.info("Auto-generating summary with \(provider.displayName) / \(model.id)")

        do {
            let summary = try await services.llm.summarize(
                transcript: meeting.fullTranscript,
                provider: provider,
                model: model
            )
            meeting.summary = summary
            meeting.rawTranscript = meeting.fullTranscript
            try? context.save()

            // Re-export markdown now that we have summary
            services.export.autoSaveMeetingNotes(meeting: meeting)

            logger.info("Auto-summary complete for: \(meeting.title)")

            // Auto-export to configured destinations
            await autoExport(meeting: meeting)

            postProcessingStatus = "Done"
            try? await Task.sleep(for: .seconds(2))
        } catch {
            logger.error("Auto-summary failed: \(error.localizedDescription)")
            postProcessingStatus = "Summary failed: \(error.localizedDescription)"
            try? await Task.sleep(for: .seconds(3))
        }

        postProcessingStatus = nil
        isPostProcessing = false
    }

    private func autoExport(meeting: Meeting) async {
        let autoExportAppleNotes = UserDefaults.standard.bool(forKey: "autoExportAppleNotes")
        let autoExportNotion = UserDefaults.standard.bool(forKey: "autoExportNotion")
        var failures: [String] = []

        if autoExportAppleNotes {
            postProcessingStatus = "Exporting to Apple Notes..."
            do {
                try await services.export.exportToAppleNotes(meeting: meeting)
                logger.info("Auto-exported to Apple Notes: \(meeting.title)")
            } catch {
                failures.append("Apple Notes: \(error.localizedDescription)")
                logger.error("Auto-export to Apple Notes failed: \(error.localizedDescription)")
            }
        }

        if autoExportNotion {
            postProcessingStatus = "Exporting to Notion..."
            do {
                let apiKey = try services.keychain.loadAPIKey(for: "notion") ?? ""
                try await services.export.exportToNotion(meeting: meeting, apiKey: apiKey)
                logger.info("Auto-exported to Notion: \(meeting.title)")
            } catch {
                failures.append("Notion: \(error.localizedDescription)")
                logger.error("Auto-export to Notion failed: \(error.localizedDescription)")
            }
        }

        if !failures.isEmpty {
            errorMessage = "Auto-export issues: " + failures.joined(separator: "; ")
        }
    }
}
