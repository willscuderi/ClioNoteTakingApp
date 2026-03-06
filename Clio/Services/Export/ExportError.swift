import Foundation

enum ExportError: LocalizedError {
    case scriptCreationFailed
    case appleScriptError(String)
    case apiKeyMissing(String)
    case networkError(String)
    case apiError(Int, String)
    case fileWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case .scriptCreationFailed: "Failed to create AppleScript"
        case .appleScriptError(let msg): "AppleScript error: \(msg)"
        case .apiKeyMissing(let provider): "API key not configured for \(provider)"
        case .networkError(let msg): "Network error: \(msg)"
        case .apiError(let code, let msg): "API error (\(code)): \(msg)"
        case .fileWriteFailed(let path): "Failed to write file: \(path)"
        }
    }
}
