import SubtitleCore
import SwiftUI

/// Modifica dello stile selezionato. Ogni modifica si salva da sola e si vede subito nell'anteprima.
struct StyleEditorView: View {
    @Binding var style: CaptionStyle
    @State private var fontQuery = ""

    var body: some View {
        Form {
            Section("Stile") {
                TextField("Nome", text: $style.name)
                TextField("Cliente", text: $style.client, prompt: Text("es. Lumine Apulia"))
            }

            Section("Testo") {
                Picker("Font", selection: $style.title.font) {
                    if !FontCatalog.isInstalled(style.title.font) {
                        Text("\(style.title.font) (non installato)").tag(style.title.font)
                    }
                    ForEach(FontCatalog.families, id: \.self) { Text($0).tag($0) }
                }
                Picker("Stile font", selection: $style.title.fontFace) {
                    let faces = FontCatalog.faces(of: style.title.font)
                    if !faces.contains(style.title.fontFace) { Text(style.title.fontFace).tag(style.title.fontFace) }
                    ForEach(faces, id: \.self) { Text($0).tag($0) }
                }
                LabeledContent("Dimensione") {
                    Slider(value: $style.title.fontSize, in: 20...240)
                    Text("\(Int(style.title.fontSize))").monospacedDigit().frame(width: 34, alignment: .trailing)
                }
                ColorPicker("Colore", selection: colorBinding(\.textColor))
                Toggle("Tutto maiuscolo", isOn: $style.segmentation.uppercase)
            }

            Section("Contorno e ombra") {
                ColorPicker("Colore contorno", selection: colorBinding(\.strokeColor))
                LabeledContent("Spessore contorno") {
                    Slider(value: $style.title.strokeWidth, in: 0...20, step: 1)
                    Text("\(Int(style.title.strokeWidth))").monospacedDigit().frame(width: 34, alignment: .trailing)
                }
                Toggle("Ombra", isOn: $style.title.shadow)
            }

            Section("Posizione e righe") {
                LabeledContent("Altezza dal basso") {
                    Slider(value: $style.verticalPercent, in: 0...100, step: 1)
                    Text("\(Int(style.verticalPercent))%").monospacedDigit().frame(width: 40, alignment: .trailing)
                }
                Picker("Righe", selection: $style.segmentation.maxLines) {
                    Text("Una riga").tag(1)
                    Text("Due righe").tag(2)
                    Text("Tre righe").tag(3)
                }
                Stepper("Caratteri per riga: \(style.segmentation.maxCharsPerLine)",
                        value: $style.segmentation.maxCharsPerLine, in: 6...60)
                Picker("Parole per sottotitolo", selection: $style.segmentation.maxWords) {
                    Text("Automatico").tag(Int?.none)
                    ForEach(1...6, id: \.self) { Text("Massimo \($0)").tag(Int?.some($0)) }
                }
                Toggle("Togli la punteggiatura", isOn: $style.segmentation.removePunctuation)
                    .help("Lasciala attiva per i sottotitoli classici: Whisper mette già virgole, punti e maiuscole")
            }
        }
        .formStyle(.grouped)
    }

    private func colorBinding(_ keyPath: WritableKeyPath<TitleStyle, RGBAColor>) -> Binding<Color> {
        Binding(
            get: { style.title[keyPath: keyPath].color },
            set: { style.title[keyPath: keyPath] = RGBAColor($0) }
        )
    }
}
