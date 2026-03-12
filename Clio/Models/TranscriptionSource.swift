import Foundation

enum TranscriptionSource: String, Codable, CaseIterable {
    case local
    case openAIWhisper
    case assemblyAI
}

enum TranscriptionAccuracy: String, Codable, CaseIterable {
    case fast       // Greedy sampling, 10s chunks
    case balanced   // Beam search, 30s chunks (default)
    case maximum    // Beam search, 30s chunks, 2s overlap with dedup

    var chunkDuration: Double {
        switch self {
        case .fast: 10.0
        case .balanced, .maximum: 30.0
        }
    }

    var useBeamSearch: Bool {
        switch self {
        case .fast: false
        case .balanced, .maximum: true
        }
    }

    var useOverlap: Bool {
        self == .maximum
    }

    var displayName: String {
        switch self {
        case .fast: "Fast"
        case .balanced: "Balanced"
        case .maximum: "Maximum"
        }
    }

    var description: String {
        switch self {
        case .fast: "Greedy decoding, 10s chunks. Fastest but lowest accuracy."
        case .balanced: "Beam search, 30s chunks. Good balance of speed and accuracy."
        case .maximum: "Beam search, 30s chunks with overlap stitching. Best accuracy, slower."
        }
    }
}
