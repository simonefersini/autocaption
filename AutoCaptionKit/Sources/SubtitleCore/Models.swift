import Foundation

/// Una parola trascritta con i suoi tempi (in secondi dall'inizio del media).
public struct Word: Codable, Hashable, Sendable {
    public var text: String
    public var start: Double
    public var end: Double

    public init(text: String, start: Double, end: Double) {
        self.text = text
        self.start = start
        self.end = end
    }
}

/// Un sottotitolo: una o più righe di testo visibili tra `start` e `end`.
public struct Caption: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var text: String
    public var start: Double
    public var end: Double

    public init(id: UUID = UUID(), text: String, start: Double, end: Double) {
        self.id = id
        self.text = text
        self.start = start
        self.end = end
    }

    public var duration: Double { end - start }
}

/// Regole con cui le parole vengono raggruppate in sottotitoli.
public struct SegmentationOptions: Codable, Hashable, Sendable {
    /// Caratteri massimi per riga.
    public var maxCharsPerLine: Int
    /// Righe massime per sottotitolo.
    public var maxLines: Int
    /// Se impostato, parole massime per sottotitolo (stile "social": 1–4 parole).
    public var maxWords: Int?
    /// Durata massima di un sottotitolo, in secondi.
    public var maxDuration: Double
    /// Durata minima: i sottotitoli troppo brevi vengono allungati se c'è spazio.
    public var minDuration: Double
    /// Una pausa più lunga di questa (secondi) forza un nuovo sottotitolo.
    public var splitOnPause: Double
    /// Le pause più brevi di questa (secondi) vengono chiuse per evitare lo "sfarfallio".
    public var closeGapsShorterThan: Double
    /// Va a capo dopo un punto, punto interrogativo o esclamativo.
    public var splitOnSentenceEnd: Bool
    public var uppercase: Bool
    /// Rimuove la punteggiatura (tipico delle caption social).
    public var removePunctuation: Bool

    public init(
        maxCharsPerLine: Int = 42,
        maxLines: Int = 2,
        maxWords: Int? = nil,
        maxDuration: Double = 6,
        minDuration: Double = 0.8,
        splitOnPause: Double = 0.7,
        closeGapsShorterThan: Double = 0.3,
        splitOnSentenceEnd: Bool = true,
        uppercase: Bool = false,
        removePunctuation: Bool = false
    ) {
        self.maxCharsPerLine = maxCharsPerLine
        self.maxLines = maxLines
        self.maxWords = maxWords
        self.maxDuration = maxDuration
        self.minDuration = minDuration
        self.splitOnPause = splitOnPause
        self.closeGapsShorterThan = closeGapsShorterThan
        self.splitOnSentenceEnd = splitOnSentenceEnd
        self.uppercase = uppercase
        self.removePunctuation = removePunctuation
    }

    /// Sottotitoli classici da TV/YouTube: due righe da 42 caratteri.
    public static let classic = SegmentationOptions()

    /// Caption brevi e incisive per Reels/TikTok/Shorts (stile mCaption).
    public static let social = SegmentationOptions(
        maxCharsPerLine: 18, maxLines: 1, maxWords: 3, maxDuration: 2.5,
        minDuration: 0.3, splitOnPause: 0.4, closeGapsShorterThan: 0.4,
        uppercase: true, removePunctuation: true
    )

    /// Una parola alla volta.
    public static let wordByWord = SegmentationOptions(
        maxCharsPerLine: 20, maxLines: 1, maxWords: 1, maxDuration: 1.5,
        minDuration: 0.15, splitOnPause: 0.3, closeGapsShorterThan: 0.3,
        uppercase: true, removePunctuation: true
    )
}
