import Foundation
import os

@MainActor
@Observable
final class ServiceContainer {
    let audioCapture: AudioCaptureServiceProtocol
    let transcription: TranscriptionServiceProtocol
    let llm: LLMServiceProtocol
    let export: ExportServiceProtocol
    let keychain: KeychainServiceProtocol
    let hotkey: HotkeyServiceProtocol
    let calendar: CalendarService
    let meetingDetector: MeetingAppDetector
    let audioDevices: AudioDeviceManager

    init(
        audioCapture: AudioCaptureServiceProtocol,
        transcription: TranscriptionServiceProtocol,
        llm: LLMServiceProtocol,
        export: ExportServiceProtocol,
        keychain: KeychainServiceProtocol,
        hotkey: HotkeyServiceProtocol,
        calendar: CalendarService,
        meetingDetector: MeetingAppDetector,
        audioDevices: AudioDeviceManager
    ) {
        self.audioCapture = audioCapture
        self.transcription = transcription
        self.llm = llm
        self.export = export
        self.keychain = keychain
        self.hotkey = hotkey
        self.calendar = calendar
        self.meetingDetector = meetingDetector
        self.audioDevices = audioDevices
    }

    static func makeDefault() -> ServiceContainer {
        let keychain = KeychainService()
        let local = LocalTranscriptionService()
        let api = APITranscriptionService(keychain: keychain)
        let openAI = OpenAIService(keychain: keychain)
        let claude = ClaudeService(keychain: keychain)
        let gemini = GeminiService(keychain: keychain)
        let ollama = OllamaService()
        let audioDevices = AudioDeviceManager()

        return ServiceContainer(
            audioCapture: AudioCaptureCoordinator(),
            transcription: TranscriptionCoordinator(local: local, api: api),
            llm: LLMCoordinator(openAI: openAI, claude: claude, gemini: gemini, ollama: ollama),
            export: ExportCoordinator(
                markdown: MarkdownExportService(),
                appleNotes: AppleNotesExportService(),
                notion: NotionExportService(keychain: keychain)
            ),
            keychain: keychain,
            hotkey: HotkeyService(),
            calendar: CalendarService(),
            meetingDetector: MeetingAppDetector(),
            audioDevices: audioDevices
        )
    }
}
