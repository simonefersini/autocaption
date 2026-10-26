import Foundation

/// Esporta in SubRip (.srt). In Final Cut Pro: File ▸ Importa ▸ Sottotitoli…
public enum SRTWriter {

    public static func srt(from captions: [Caption]) -> String {
        captions.enumerated().map { index, caption in
            "\(index + 1)\n\(timestamp(caption.start)) --> \(timestamp(caption.end))\n\(caption.text)\n"
        }.joined(separator: "\n")
    }

    static func timestamp(_ seconds: Double) -> String {
        let totalMs = Int((max(0, seconds) * 1000).rounded())
        let h = totalMs / 3_600_000
        let m = (totalMs % 3_600_000) / 60_000
        let s = (totalMs % 60_000) / 1000
        let ms = totalMs % 1000
        return String(format: "%02d:%02d:%02d,%03d", h, m, s, ms)
    }
}
