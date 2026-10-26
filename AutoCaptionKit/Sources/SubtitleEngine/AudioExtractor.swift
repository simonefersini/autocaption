import AVFoundation
import Foundation

public enum AudioExtractorError: LocalizedError {
    case noAudioTrack
    case readerFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noAudioTrack: return "Il file non contiene una traccia audio."
        case .readerFailed(let message): return "Impossibile leggere l'audio: \(message)"
        }
    }
}

/// Estrae l'audio da qualsiasi file video/audio leggibile da AVFoundation
/// (mov, mp4, m4a, wav, mp3, ProRes, H.264/HEVC…) come PCM mono 16 kHz, il formato di Whisper.
public enum AudioExtractor {

    public static let sampleRate: Double = 16_000

    public static func duration(of url: URL) async throws -> Double {
        let asset = AVURLAsset(url: url)
        return try await asset.load(.duration).seconds
    }

    public static func monoSamples(from url: URL) async throws -> [Float] {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let track = tracks.first else { throw AudioExtractorError.noAudioTrack }

        let reader = try AVAssetReader(asset: asset)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        output.alwaysCopiesSampleData = false
        reader.add(output)

        guard reader.startReading() else {
            throw AudioExtractorError.readerFailed(reader.error?.localizedDescription ?? "errore sconosciuto")
        }

        var samples: [Float] = []
        while let buffer = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
            let length = CMBlockBufferGetDataLength(block)
            var chunk = [Float](repeating: 0, count: length / MemoryLayout<Float>.size)
            chunk.withUnsafeMutableBytes { raw in
                _ = CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: raw.baseAddress!)
            }
            samples.append(contentsOf: chunk)
        }

        if reader.status == .failed {
            throw AudioExtractorError.readerFailed(reader.error?.localizedDescription ?? "errore sconosciuto")
        }
        return samples
    }
}
