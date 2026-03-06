import os

extension Logger {
    static let audio = Logger(subsystem: "com.willscuderi.Clio", category: "Audio")
    static let transcription = Logger(subsystem: "com.willscuderi.Clio", category: "Transcription")
    static let llm = Logger(subsystem: "com.willscuderi.Clio", category: "LLM")
    static let export = Logger(subsystem: "com.willscuderi.Clio", category: "Export")
    static let ui = Logger(subsystem: "com.willscuderi.Clio", category: "UI")
}
