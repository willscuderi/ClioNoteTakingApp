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

    init(
        audioCapture: AudioCaptureServiceProtocol,
        transcription: TranscriptionServiceProtocol,
        llm: LLMServiceProtocol,
        export: ExportServiceProtocol,
        keychain: KeychainServiceProtocol,
        hotkey: HotkeyServiceProtocol
    ) {
        self.audioCapture = audioCapture
        self.transcription = transcription
        self.llm = llm
        self.export = export
        self.keychain = keychain
        self.hotkey = hotkey
    }

    static func makeDefault() -> ServiceContainer {
        let keychain = KeychainService()
        let local = LocalTranscriptionService()
        let api = APITranscriptionService(keychain: keychain)
        let openAI = OpenAIService(keychain: keychain)
        let claude = ClaudeService(keychain: keychain)

        return ServiceContainer(
            audioCapture: AudioCaptureCoordinator(),
            transcription: TranscriptionCoordinator(local: local, api: api),
            llm: LLMCoordinator(openAI: openAI, claude: claude),
            export: ExportCoordinator(
                markdown: MarkdownExportService(),
                appleNotes: AppleNotesExportService(),
                notion: NotionExportService(keychain: keychain)
            ),
            keychain: keychain,
            hotkey: HotkeyService()
        )
    }
}
