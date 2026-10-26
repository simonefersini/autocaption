import Foundation

/// Raggruppa le parole trascritte in sottotitoli leggibili.
public enum Segmenter {

    public static func captions(from words: [Word], options: SegmentationOptions) -> [Caption] {
        let cleaned = mergeFragments(words).compactMap { clean($0, options: options) }
        guard !cleaned.isEmpty else { return [] }

        var groups: [[Word]] = []
        var current: [Word] = []

        for word in cleaned {
            if let last = current.last, let first = current.first {
                let pause = word.start - last.end
                let sentenceEnded = options.splitOnSentenceEnd && endsSentence(last.text)
                let tooManyWords = options.maxWords.map { current.count >= $0 } ?? false

                let hardBreak = pause > options.splitOnPause || sentenceEnded
                let softBreak = !fits(current + [word], options: options)
                    || word.end - first.start > options.maxDuration
                    || tooManyWords

                if hardBreak {
                    groups.append(current)
                    current = []
                } else if softBreak {
                    // Non chiudere un sottotitolo su "di", "la", "che"…: la parola passa al successivo
                    // (solo se ne restano almeno due, per non lasciare parole orfane).
                    var carried: [Word] = []
                    if current.count > 2, isWeak(last.text) { carried = [current.removeLast()] }
                    groups.append(current)
                    current = carried
                    if !carried.isEmpty && !fits(current + [word], options: options) {
                        groups.append(current)
                        current = []
                    }
                }
            }
            current.append(word)
        }
        if !current.isEmpty { groups.append(current) }

        var captions = groups.map { group -> Caption in
            let lines = wrap(group.map { displayText($0.text, options: options) },
                             maxCharsPerLine: options.maxCharsPerLine,
                             maxLines: options.maxLines)
            return Caption(text: lines.joined(separator: "\n"),
                           start: group.first!.start,
                           end: group.last!.end)
        }
        fixTimings(&captions, options: options)
        return captions
    }

    // MARK: - Testo

    /// Whisper a volte spezza le parole con l'apostrofo ("c" + "'è", "l'" + "automatico")
    /// o stacca la punteggiatura (" ciao" + ","): qui vengono riattaccate.
    static func mergeFragments(_ words: [Word]) -> [Word] {
        var result: [Word] = []
        for word in words {
            let trimmed = word.text.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("<|") { continue }
            if let previous = result.last {
                let prev = previous.text.trimmingCharacters(in: .whitespaces)
                let startsGlued = !word.text.hasPrefix(" ") && (trimmed.first.map { "'’.,;:!?…)".contains($0) } ?? false)
                let prevOpen = prev.last.map { "'’".contains($0) } ?? false
                if startsGlued || prevOpen {
                    result[result.count - 1].text = previous.text + trimmed
                    result[result.count - 1].end = max(previous.end, word.end)
                    continue
                }
            }
            result.append(word)
        }
        return result
    }

    /// Parole che non dovrebbero chiudere un sottotitolo (articoli, preposizioni, congiunzioni).
    static let weakWords: Set<String> = [
        // italiano
        "il", "lo", "la", "i", "gli", "le", "l'", "un", "uno", "una", "un'",
        "di", "a", "da", "in", "con", "su", "per", "tra", "fra",
        "del", "dello", "della", "dei", "degli", "delle", "dell'",
        "al", "allo", "alla", "ai", "agli", "alle", "all'",
        "dal", "dallo", "dalla", "dai", "dagli", "dalle", "dall'",
        "nel", "nello", "nella", "nei", "negli", "nelle", "nell'",
        "sul", "sullo", "sulla", "sui", "sugli", "sulle", "sull'",
        "e", "ed", "o", "ma", "che", "se", "come", "non", "mi", "ti", "ci", "si", "vi",
        // inglese
        "the", "a", "an", "of", "to", "and", "or", "but", "in", "on", "at", "for", "with", "my", "your",
    ]

    static func isWeak(_ text: String) -> Bool {
        if let last = text.last, ".,;:!?…".contains(last) { return false }
        return weakWords.contains(text.lowercased())
    }

    /// Normalizza una parola di Whisper (spazi iniziali, token speciali) e scarta quelle vuote.
    static func clean(_ word: Word, options: SegmentationOptions) -> Word? {
        var text = word.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("<|") && text.hasSuffix("|>") { return nil }
        if text.hasPrefix("[") && text.hasSuffix("]") { return nil } // es. [Musica]
        if options.removePunctuation {
            // Tiene apostrofi interni (l'acqua, dell'anno) e trattini.
            text = text.trimmingCharacters(in: CharacterSet.punctuationCharacters.subtracting(CharacterSet(charactersIn: "'’-")))
            text = text.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        }
        guard !text.isEmpty else { return nil }
        let end = max(word.end, word.start)
        return Word(text: text, start: word.start, end: end)
    }

    static func displayText(_ text: String, options: SegmentationOptions) -> String {
        options.uppercase ? text.uppercased() : text
    }

    static func endsSentence(_ text: String) -> Bool {
        guard let last = text.last else { return false }
        return ".?!…".contains(last)
    }

    /// True se le parole stanno nelle righe consentite senza superare la larghezza massima.
    static func fits(_ words: [Word], options: SegmentationOptions) -> Bool {
        let lines = wrap(words.map(\.text), maxCharsPerLine: options.maxCharsPerLine, maxLines: options.maxLines)
        return lines.count <= options.maxLines && lines.allSatisfy { $0.count <= options.maxCharsPerLine }
    }

    /// Divide le parole in al massimo `maxLines` righe il più possibile bilanciate.
    static func wrap(_ words: [String], maxCharsPerLine: Int, maxLines: Int) -> [String] {
        let single = words.joined(separator: " ")
        guard maxLines > 1, words.count > 1, single.count > maxCharsPerLine else { return [single] }

        // Due righe (il caso di gran lunga più comune): sceglie il taglio con le righe più simili.
        if maxLines == 2 {
            var best = (index: 1, score: Int.max)
            for i in 1..<words.count {
                let a = words[..<i].joined(separator: " ").count
                let b = words[i...].joined(separator: " ").count
                let overflow = max(0, a - maxCharsPerLine) + max(0, b - maxCharsPerLine)
                let score = overflow * 1000 + abs(a - b)
                if score < best.score { best = (i, score) }
            }
            return [words[..<best.index].joined(separator: " "),
                    words[best.index...].joined(separator: " ")]
        }

        // Più di due righe: riempimento greedy.
        var lines: [String] = []
        var line = ""
        for w in words {
            let candidate = line.isEmpty ? w : line + " " + w
            if candidate.count > maxCharsPerLine && !line.isEmpty && lines.count < maxLines - 1 {
                lines.append(line)
                line = w
            } else {
                line = candidate
            }
        }
        lines.append(line)
        return lines
    }

    // MARK: - Tempi

    static func fixTimings(_ captions: inout [Caption], options: SegmentationOptions) {
        for i in captions.indices {
            let nextStart = i + 1 < captions.count ? captions[i + 1].start : Double.infinity

            // Allunga i sottotitoli troppo brevi, senza invadere il successivo.
            if captions[i].duration < options.minDuration {
                captions[i].end = min(captions[i].start + options.minDuration, nextStart)
            }
            // Chiude le pause brevissime tra un sottotitolo e l'altro.
            if nextStart - captions[i].end < options.closeGapsShorterThan {
                captions[i].end = nextStart
            }
            // Nessuna sovrapposizione.
            if captions[i].end > nextStart { captions[i].end = nextStart }
            if captions[i].end <= captions[i].start { captions[i].end = captions[i].start + 0.04 }
        }
    }
}
