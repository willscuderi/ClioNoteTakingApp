import Foundation

enum TranscriptionSource: String, Codable, CaseIterable {
    case local
    case openAIWhisper
    case assemblyAI
}
