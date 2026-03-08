import AVFoundation
import Foundation

/// Shared WAV encoding utility used by API-based transcription services.
enum AudioEncoding {

    /// Encode an AVAudioPCMBuffer to 16-bit PCM WAV data.
    static func encodeToWAV(buffer: AVAudioPCMBuffer) throws -> Data {
        guard let channelData = buffer.floatChannelData?[0] else {
            throw AudioEncodingError.noChannelData
        }

        let sampleRate = UInt32(buffer.format.sampleRate)
        let channels: UInt16 = UInt16(buffer.format.channelCount)
        let bitsPerSample: UInt16 = 16 // Convert float32 to int16 for smaller uploads
        let frameLength = Int(buffer.frameLength)

        // Convert Float32 samples to Int16
        var int16Samples = [Int16](repeating: 0, count: frameLength)
        for i in 0..<frameLength {
            let clamped = max(-1.0, min(1.0, channelData[i]))
            int16Samples[i] = Int16(clamped * Float(Int16.max))
        }

        let dataSize = UInt32(frameLength * Int(channels) * Int(bitsPerSample / 8))
        let byteRate = UInt32(sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8))
        let blockAlign = UInt16(channels * (bitsPerSample / 8))

        var wav = Data()

        // RIFF header
        wav.append(contentsOf: "RIFF".utf8)
        wav.appendLittleEndian(UInt32(36 + dataSize))
        wav.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        wav.append(contentsOf: "fmt ".utf8)
        wav.appendLittleEndian(UInt32(16))       // chunk size
        wav.appendLittleEndian(UInt16(1))        // PCM format
        wav.appendLittleEndian(channels)
        wav.appendLittleEndian(sampleRate)
        wav.appendLittleEndian(byteRate)
        wav.appendLittleEndian(blockAlign)
        wav.appendLittleEndian(bitsPerSample)

        // data chunk
        wav.append(contentsOf: "data".utf8)
        wav.appendLittleEndian(dataSize)
        int16Samples.withUnsafeBufferPointer { ptr in
            wav.append(UnsafeBufferPointer(
                start: UnsafeRawPointer(ptr.baseAddress!).assumingMemoryBound(to: UInt8.self),
                count: Int(dataSize)
            ))
        }

        return wav
    }

    enum AudioEncodingError: LocalizedError {
        case noChannelData

        var errorDescription: String? {
            switch self {
            case .noChannelData: "No audio channel data available for encoding"
            }
        }
    }
}

// MARK: - Data Helpers

extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var le = value.littleEndian
        append(UnsafeBufferPointer(start: &le, count: 1))
    }

    mutating func appendMultipart(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func appendMultipart(boundary: String, name: String, filename: String, mimeType: String, data: Data) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}
