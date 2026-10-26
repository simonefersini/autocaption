import SubtitleCore
import SwiftUI

/// Libreria stili: ricerca per nome o cliente, preferiti, nuovo/duplica/elimina.
struct StyleLibraryView: View {
    @ObservedObject var store: StyleStore
    @State private var query = ""
    @State private var favoritesOnly = false
    @State private var pendingDelete: CaptionStyle?

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Cerca stile o cliente", text: $query)
                    .textFieldStyle(.plain)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless).foregroundStyle(.secondary)
                }
                Toggle(isOn: $favoritesOnly) { Image(systemName: favoritesOnly ? "star.fill" : "star") }
                    .toggleStyle(.button).buttonStyle(.borderless)
                    .help("Solo preferiti")
            }
            .padding(7)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color(nsColor: .textBackgroundColor).opacity(0.6)))

            let results = StyleSearch.filter(store.styles, query: query, favoritesOnly: favoritesOnly)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 8)], spacing: 8) {
                    ForEach(results) { style in
                        StyleCard(style: style, isSelected: style.id == store.selectedID)
                            .onTapGesture { store.selectedID = style.id }
                            .contextMenu {
                                Button(style.isFavorite ? "Togli dai preferiti" : "Aggiungi ai preferiti") { store.toggleFavorite(style.id) }
                                Button("Duplica") { store.selectedID = style.id; store.duplicateSelected() }
                                Divider()
                                Button("Elimina…", role: .destructive) { pendingDelete = style }
                                    .disabled(store.styles.count <= 1)
                            }
                    }
                }
                if results.isEmpty {
                    Text(query.isEmpty ? "Nessuno stile preferito." : "Nessuno stile trovato per “\(query)”.")
                        .font(.callout).foregroundStyle(.secondary).padding(.top, 24)
                }
            }

            HStack {
                Button { store.createStyle(client: query) } label: { Label("Nuovo stile", systemImage: "plus") }
                    .help("Crea uno stile partendo da quello selezionato")
                Button { store.duplicateSelected() } label: { Image(systemName: "plus.square.on.square") }
                    .help("Duplica lo stile selezionato")
                Spacer()
                Button(role: .destructive) { pendingDelete = store.selected } label: { Image(systemName: "trash") }
                    .disabled(store.styles.count <= 1)
                    .help("Elimina lo stile selezionato")
            }
            .buttonStyle(.borderless)
        }
        .confirmationDialog("Eliminare lo stile “\(pendingDelete?.name ?? "")”?",
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Elimina", role: .destructive) {
                if let style = pendingDelete { store.delete(style.id) }
                pendingDelete = nil
            }
        }
    }
}

/// Miniatura: il nome dello stile scritto con lo stile stesso, su nero (come in mCaption).
private struct StyleCard: View {
    var style: CaptionStyle
    var isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 8).fill(Color.black)
                StyledCaptionText(text: "Il tuo testo qui", style: style.title,
                                  uppercase: style.segmentation.uppercase, scale: 0.22, maxWidth: 116)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if style.isFavorite {
                    Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow).padding(6)
                }
            }
            .frame(height: 74)
            .overlay(RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color.purple : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1))

            Text(style.name).font(.caption.weight(.medium)).lineLimit(1)
            Text(style.client.isEmpty ? " " : style.client).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .contentShape(Rectangle())
    }
}
