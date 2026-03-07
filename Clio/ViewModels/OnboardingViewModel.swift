import AVFoundation
import AppKit
import Foundation
import ScreenCaptureKit
import os

@MainActor
@Observable
final class OnboardingViewModel {
    private let logger = Logger(subsystem: "com.willscuderi.Clio", category: "Onboarding")
    private let keychain: KeychainServiceProtocol

    // MARK: - Navigation

    enum Step: Int, CaseIterable {
        case permissions = 0
        case transcription
        case llm
        case integrations
        case complete
    }

    var currentStep: Step = .permissions

    var stepIndex: Int { currentStep.rawValue }
    var totalSteps: Int { Step.allCases.count - 1 } // exclude .complete from count

    var canGoBack: Bool { currentStep.rawValue > 0 && currentStep != .complete }

    func goNext() {
        guard let next = Step(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    func goBack() {
        guard let prev = Step(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = prev
    }

    // MARK: - Step 1: Permissions

    var micPermissionGranted = false
    var screenRecordingGranted = false
    var screenRecordingNeedsRestart = false
    private var permissionPollTimer: Timer?

    func checkPermissions() {
        micPermissionGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        checkScreenRecording()
    }

    private func checkScreenRecording() {
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                // If we get content with displays, permission is granted
                screenRecordingGranted = !content.displays.isEmpty
            } catch {
                screenRecordingGranted = false
            }
        }
    }

    /// Start polling permissions every 2 seconds (call when permissions step is visible)
    func startPermissionPolling() {
        stopPermissionPolling()
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkPermissions()
            }
        }
    }

    func stopPermissionPolling() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = nil
    }

    func requestMicPermission() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor in
                self?.micPermissionGranted = granted
            }
        }
    }

    func requestScreenRecording() {
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                screenRecordingGranted = !content.displays.isEmpty
            } catch {
                screenRecordingGranted = false
                screenRecordingNeedsRestart = true
                // Open System Settings to Screen & System Audio Recording pane
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    // MARK: - Step 2: Transcription

    enum TranscriptionChoice {
        case cloud
        case onDevice
    }

    var transcriptionChoice: TranscriptionChoice?
    var sttAPIKey = ""
    var useDeepgram = false
    var deepgramAPIKey = ""
    var modelDownloadProgress: Double = 0
    var isDownloadingModel = false
    var modelDownloaded = false

    func saveSTTKey() {
        guard !sttAPIKey.isEmpty else { return }
        do {
            let service = useDeepgram ? "deepgram" : "openai"
            try keychain.saveAPIKey(sttAPIKey, for: service)
            logger.info("Saved STT API key for \(service)")
        } catch {
            logger.error("Failed to save STT key: \(error.localizedDescription)")
        }
    }

    func saveDeepgramKey() {
        guard !deepgramAPIKey.isEmpty else { return }
        do {
            try keychain.saveAPIKey(deepgramAPIKey, for: "deepgram")
        } catch {
            logger.error("Failed to save Deepgram key: \(error.localizedDescription)")
        }
    }

    func downloadWhisperModel() {
        guard !isDownloadingModel else { return }
        isDownloadingModel = true
        modelDownloadProgress = 0

        // Check if model already exists in bundle
        if Bundle.main.url(forResource: "ggml-base.en", withExtension: "bin") != nil {
            modelDownloadProgress = 1.0
            modelDownloaded = true
            isDownloadingModel = false
            return
        }

        // Download to Application Support
        Task {
            do {
                let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                let modelsDir = appSupport.appendingPathComponent("com.willscuderi.Clio/Models", isDirectory: true)
                try FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)

                let destination = modelsDir.appendingPathComponent("ggml-base.en.bin")

                // If already downloaded
                if FileManager.default.fileExists(atPath: destination.path) {
                    modelDownloadProgress = 1.0
                    modelDownloaded = true
                    isDownloadingModel = false
                    return
                }

                let url = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin")!
                let (asyncBytes, response) = try await URLSession.shared.bytes(from: url)

                let expectedLength = (response as? HTTPURLResponse)
                    .flatMap { Int($0.value(forHTTPHeaderField: "Content-Length") ?? "") } ?? 148_000_000

                var data = Data()
                data.reserveCapacity(expectedLength)

                for try await byte in asyncBytes {
                    data.append(byte)
                    if data.count % 500_000 == 0 {
                        modelDownloadProgress = Double(data.count) / Double(expectedLength)
                    }
                }

                try data.write(to: destination)
                modelDownloadProgress = 1.0
                modelDownloaded = true
                logger.info("Whisper model downloaded to \(destination.path)")
            } catch {
                logger.error("Model download failed: \(error.localizedDescription)")
                modelDownloadProgress = 0
            }
            isDownloadingModel = false
        }
    }

    // MARK: - Step 3: LLM

    var selectedLLMProvider: LLMProvider?
    var llmAPIKey = ""

    func saveLLMKey() {
        guard let provider = selectedLLMProvider, !llmAPIKey.isEmpty else { return }
        do {
            try keychain.saveAPIKey(llmAPIKey, for: provider.keychainKey)
            logger.info("Saved LLM API key for \(provider.rawValue)")
        } catch {
            logger.error("Failed to save LLM key: \(error.localizedDescription)")
        }
    }

    // MARK: - Step 4: Integrations

    var calendarAccessGranted = false
    var enabledExports: Set<ExportFormat> = []
    var notionToken = ""
    var obsidianVaultPath: URL?
    var markdownFolderPath: URL?

    func requestCalendarAccess() {
        Task {
            let calendarService = CalendarService()
            calendarAccessGranted = await calendarService.requestAccess()
            UserDefaults.standard.set(calendarAccessGranted, forKey: "calendarAccessGranted")
        }
    }

    func checkCalendarAccess() {
        let calendarService = CalendarService()
        calendarService.checkAuthorizationStatus()
        calendarAccessGranted = calendarService.isAuthorized
    }

    func toggleExport(_ format: ExportFormat) {
        if enabledExports.contains(format) {
            enabledExports.remove(format)
        } else {
            enabledExports.insert(format)
        }
    }

    func saveIntegrationKeys() {
        do {
            if !notionToken.isEmpty {
                try keychain.saveAPIKey(notionToken, for: "notion")
            }
            if let path = obsidianVaultPath {
                UserDefaults.standard.set(path.path, forKey: "obsidianVaultPath")
            }
            if let path = markdownFolderPath {
                UserDefaults.standard.set(path.path, forKey: "markdownExportPath")
            }
        } catch {
            logger.error("Failed to save integration settings: \(error.localizedDescription)")
        }
    }

    // MARK: - Completion

    static let onboardingCompleteKey = "hasCompletedOnboarding"

    static var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: onboardingCompleteKey)
    }

    func completeOnboarding() {
        // Save any pending keys
        if transcriptionChoice == .cloud { saveSTTKey() }
        if !deepgramAPIKey.isEmpty { saveDeepgramKey() }
        saveLLMKey()
        saveIntegrationKeys()

        // Save preferred transcription source
        let source: TranscriptionSource = transcriptionChoice == .onDevice ? .local : .openAIWhisper
        UserDefaults.standard.set(source.rawValue, forKey: "preferredTranscriptionSource")

        // Save preferred LLM provider
        if let provider = selectedLLMProvider {
            UserDefaults.standard.set(provider.rawValue, forKey: "preferredLLMProvider")
        }

        // Save enabled export formats
        let formats = enabledExports.map(\.rawValue)
        UserDefaults.standard.set(formats, forKey: "enabledExportFormats")

        UserDefaults.standard.set(true, forKey: Self.onboardingCompleteKey)
        logger.info("Onboarding completed")
    }

    // MARK: - Init

    init(keychain: KeychainServiceProtocol) {
        self.keychain = keychain
        checkPermissions()

        // Check if model is already bundled or downloaded
        if Bundle.main.url(forResource: "ggml-base.en", withExtension: "bin") != nil {
            modelDownloaded = true
            modelDownloadProgress = 1.0
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let modelPath = appSupport.appendingPathComponent("com.willscuderi.Clio/Models/ggml-base.en.bin")
            if FileManager.default.fileExists(atPath: modelPath.path) {
                modelDownloaded = true
                modelDownloadProgress = 1.0
            }
        }
    }
}
