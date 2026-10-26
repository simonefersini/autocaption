import Foundation

/// Uno stile salvato: aspetto dei titoli + regole di impaginazione.
/// Si possono creare, rinominare e associare a un cliente.
public struct CaptionStyle: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    /// Cliente o progetto a cui appartiene lo stile (facoltativo, usato anche dalla ricerca).
    public var client: String
    public var title: TitleStyle
    public var segmentation: SegmentationOptions
    /// Posizione verticale in % dell'altezza: 0 = bordo inferiore, 50 = centro, 100 = bordo superiore.
    /// In percentuale così lo stesso stile funziona in 9:16, 16:9 e 1:1.
    public var verticalPercent: Double
    public var isFavorite: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        client: String = "",
        title: TitleStyle = TitleStyle(),
        segmentation: SegmentationOptions = .classic,
        verticalPercent: Double = 15,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.client = client
        self.title = title
        self.segmentation = segmentation
        self.verticalPercent = verticalPercent
        self.isFavorite = isFavorite
    }

    /// Stile dei titoli con la posizione convertita in pixel dal centro per un formato specifico.
    public func titleStyle(forHeight height: Int) -> TitleStyle {
        var t = title
        t.positionY = ((verticalPercent / 100 - 0.5) * Double(height)).rounded()
        return t
    }

    /// Copia con nuovo id, per "Duplica".
    public func duplicated(name: String? = nil) -> CaptionStyle {
        var copy = self
        copy.id = UUID()
        copy.name = name ?? "\(self.name) copia"
        copy.isFavorite = false
        return copy
    }

    /// Pochi stili di partenza: da duplicare e personalizzare per ogni cliente.
    public static let starters: [CaptionStyle] = [
        CaptionStyle(
            name: "Classico",
            title: TitleStyle(font: "Helvetica Neue", fontFace: "Bold", fontSize: 56, strokeWidth: 0, shadow: true),
            segmentation: .classic, verticalPercent: 12
        ),
        CaptionStyle(
            name: "Social bianco",
            title: TitleStyle(font: "Poppins", fontFace: "SemiBold", fontSize: 90, strokeWidth: 0, shadow: true),
            segmentation: .social, verticalPercent: 35
        ),
        CaptionStyle(
            name: "Social giallo",
            title: TitleStyle(font: "Poppins", fontFace: "Bold", fontSize: 96, textColor: .yellow, strokeWidth: 4, shadow: true),
            segmentation: .social, verticalPercent: 35
        ),
        CaptionStyle(
            name: "Parola per parola",
            title: TitleStyle(font: "Poppins", fontFace: "Black", fontSize: 120, strokeWidth: 6, shadow: true),
            segmentation: .wordByWord, verticalPercent: 35
        ),
    ]
}

public enum StyleSearch {
    /// Filtra per nome o cliente (senza distinguere maiuscole e accenti). Preferiti in cima, poi in ordine alfabetico.
    public static func filter(_ styles: [CaptionStyle], query: String, favoritesOnly: Bool = false) -> [CaptionStyle] {
        let terms = query
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split(separator: " ")
            .map(String.init)

        return styles
            .filter { !favoritesOnly || $0.isFavorite }
            .filter { style in
                let haystack = "\(style.name) \(style.client)"
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
                return terms.allSatisfy { haystack.contains($0) }
            }
            .sorted {
                if $0.isFavorite != $1.isFavorite { return $0.isFavorite }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }
}
