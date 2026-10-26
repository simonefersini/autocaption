import AVFoundation
import CoreGraphics
import Foundation
import SubtitleCore

/// Formato del video caricato, letto in automatico (come mCaption: "1080 × 1920, 30 fps").
public struct MediaInfo: Sendable {
    public var width: Int
    public var height: Int
    public var frameRate: FrameRate
    public var duration: Double

    public static func load(from url: URL) async throws -> MediaInfo {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds

        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            // Solo audio: verticale 1080×1920 a 30 fps come default.
            return MediaInfo(width: 1080, height: 1920, frameRate: .fps30, duration: duration)
        }
        let (size, transform, fps) = try await track.load(.naturalSize, .preferredTransform, .nominalFrameRate)
        let rotated = size.applying(transform)
        return MediaInfo(
            width: Int(abs(rotated.width).rounded()),
            height: Int(abs(rotated.height).rounded()),
            frameRate: nearestFrameRate(Double(fps)),
            duration: duration
        )
    }

    static func nearestFrameRate(_ fps: Double) -> FrameRate {
        FrameRate.allCases.min { abs($0.framesPerSecond - fps) < abs($1.framesPerSecond - fps) } ?? .fps30
    }
}

/// Estrae fotogrammi del video per l'anteprima dei sottotitoli.
public final class FrameGrabber: @unchecked Sendable {
    private let generator: AVAssetImageGenerator

    public init(url: URL, maximumSize: CGSize = CGSize(width: 720, height: 720)) {
        generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maximumSize
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
    }

    public func frame(at seconds: Double) async -> CGImage? {
        try? await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image
    }
}
