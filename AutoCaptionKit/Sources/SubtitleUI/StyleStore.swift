import Foundation
import SubtitleCore

/// Libreria degli stili dell'utente, salvata su disco in JSON.
///
/// App ed estensione hanno sandbox separati: per condividere gli stessi stili tra le due,
/// aggiungi la capability "App Groups" a entrambi i target con l'identificativo `appGroupID`.
/// Senza App Group ognuna usa la propria libreria.
@MainActor
public final class StyleStore: ObservableObject {

    public static let appGroupID = "group.autocaption.shared" // ⚠️ cambialo col tuo (es. "TEAMID.group.autocaption")

    @Published public var styles: [CaptionStyle] = [] {
        didSet { scheduleSave() }
    }
    @Published public var selectedID: CaptionStyle.ID?

    private let fileURL: URL
    private var saveTask: Task<Void, Never>?

    public init() {
        fileURL = Self.storageDirectory().appendingPathComponent("styles.json")
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([CaptionStyle].self, from: data),
           !saved.isEmpty {
            styles = saved
        } else {
            styles = CaptionStyle.starters
        }
        selectedID = styles.first?.id
    }

    public var selected: CaptionStyle {
        get { styles.first { $0.id == selectedID } ?? styles.first ?? CaptionStyle.starters[0] }
        set {
            if let i = styles.firstIndex(where: { $0.id == newValue.id }) { styles[i] = newValue }
        }
    }

    /// Crea un nuovo stile partendo da quello selezionato.
    public func createStyle(client: String = "") {
        var style = selected.duplicated(name: "Nuovo stile")
        style.client = client
        styles.append(style)
        selectedID = style.id
    }

    public func duplicateSelected() {
        let copy = selected.duplicated()
        styles.append(copy)
        selectedID = copy.id
    }

    public func delete(_ id: CaptionStyle.ID) {
        guard styles.count > 1 else { return } // ne resta sempre almeno uno
        styles.removeAll { $0.id == id }
        if selectedID == id { selectedID = styles.first?.id }
    }

    public func toggleFavorite(_ id: CaptionStyle.ID) {
        if let i = styles.firstIndex(where: { $0.id == id }) { styles[i].isFavorite.toggle() }
    }

    // MARK: - Salvataggio

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = styles
        let url = fileURL
        saveTask = Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(snapshot) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    private static func storageDirectory() -> URL {
        let fm = FileManager.default
        let base = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("AutoCaption", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
