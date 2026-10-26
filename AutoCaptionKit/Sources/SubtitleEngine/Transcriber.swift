import Foundation
import SubtitleCore
import WhisperKit

/// Modelli Whisper disponibili. Vengono scaricati da Hugging Face al primo utilizzo
/// e poi girano interamente in locale sul Mac (Neural Engine / GPU), senza inviare l'audio a nessuno.
public enum WhisperModel: String, CaseIterable, Identifiable, Sendable {
    case base = "base"
    case small = "small"
    case largeTurbo = "large-v3-v20240930_turbo"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .base: return "Veloce (base, ~150 MB)"
        case .small: return "Bilanciato (small, ~500 MB)"
        case .largeTurbo: return "Massima qualità (large-v3 turbo, ~1,6 GB)"
        }
    }
}

public struct TranscriptionLanguage: Hashable, Identifiable, Sendable {
    /// Codice ISO 639-1, `nil` = rilevamento automatico.
    public let code: String?
    public let name: String
    public var id: String { code ?? "auto" }

    public static let all: [TranscriptionLanguage] = [
        .init(code: nil, name: "Rileva automaticamente"),
        .init(code: "it", name: "Italiano"),
        .init(code: "en", name: "Inglese"),
        .init(code: "es", name: "Spagnolo"),
        .init(code: "fr", name: "Francese"),
        .init(code: "de", name: "Tedesco"),
        .init(code: "pt", name: "Portoghese"),
    ]
}

public enum TranscriptionStage: Sendable {
    case loadingModel
    case extractingAudio
    case transcribing(fraction: Double)
}

/// Trascrive un file audio/video in parole con tempi, usando WhisperKit.
public actor Transcriber {

    private var pipeline: WhisperKit?
    private var loadedModel: WhisperModel?

    public init() {}

    public func transcribe(
        url: URL,
        model: WhisperModel,
        language: TranscriptionLanguage,
        onStage: @escaping @Sendable (TranscriptionStage) -> Void
    ) async throws -> [Word] {
        onStage(.loadingModel)
        let whisper = try await loadPipeline(model)

        onStage(.extractingAudio)
        let samples = try await AudioExtractor.monoSamples(from: url)

        var options = DecodingOptions()
        options.task = .transcribe
        options.language = language.code
        options.detectLanguage = language.code == nil
        options.wordTimestamps = true
        options.skipSpecialTokens = true
        options.chunkingStrategy = .vad // spezza l'audio lungo sulle pause

        onStage(.transcribing(fraction: 0))
        let progressTask = Task {
            while !Task.isCancelled {
                onStage(.transcribing(fraction: whisper.progress.fractionCompleted))
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
        defer { progressTask.cancel() }

        let results = try await whisper.transcribe(audioArray: samples, decodeOptions: options)
        try Task.checkCancellation()

        return results
            .flatMap(\.segments)
            .flatMap { $0.words ?? [] }
            .map { Word(text: $0.word, start: Double($0.start), end: Double($0.end)) }
            .sorted { $0.start < $1.start }
    }

    private func loadPipeline(_ model: WhisperModel) async throws -> WhisperKit {
        if let pipeline, loadedModel == model { return pipeline }
        let config = WhisperKitConfig(model: model.rawValue, verbose: false, prewarm: true, load: true, download: true)
        let whisper = try await WhisperKit(config)
        pipeline = whisper
        loadedModel = model
        return whisper
    }
}
