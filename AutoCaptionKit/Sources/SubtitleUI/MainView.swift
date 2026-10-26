import SubtitleCore
import SubtitleEngine
import SwiftUI
import UniformTypeIdentifiers

/// Interfaccia condivisa tra l'app e l'estensione di Final Cut Pro.
/// Sinistra: video, lingua, formato, genera e trascina. Centro: anteprima sul video e testo.
/// Destra: libreria stili con ricerca ed editor dello stile selezionato.
public struct MainView: View {
    @StateObject private var vm = CaptionViewModel()
    @StateObject private var store = StyleStore()
    @State private var isDropTargeted = false
    @State private var rightTab = RightTab.styles

    enum RightTab: String, CaseIterable { case styles = "Stili", edit = "Modifica stile", text = "Testo" }

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            controls
                .frame(width: 260)
            Divider()
            PreviewView(vm: vm, style: store.selected)
                .padding(16)
                .frame(minWidth: 300, maxWidth: .infinity)
            Divider()
            rightPanel
                .frame(width: 320)
        }
        .frame(minWidth: 960, minHeight: 640)
        .onChange(of: store.selected.segmentation) { _, _ in
            vm.resegment(with: store.selected)
        }
    }

    // MARK: - Colonna sinistra

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            dropZone

            VStack(alignment: .leading, spacing: 6) {
                Text("Lingua").font(.caption).foregroundStyle(.secondary)
                Picker("Lingua", selection: $vm.language) {
                    ForEach(TranscriptionLanguage.all) { Text($0.name).tag($0) }
                }
                .labelsHidden()
                Text("Qualità").font(.caption).foregroundStyle(.secondary)
                Picker("Modello", selection: $vm.model) {
                    ForEach(WhisperModel.allCases) { Text($0.displayName).tag($0) }
                }
                .labelsHidden()
            }
            .disabled(vm.isWorking)

            VStack(alignment: .leading, spacing: 6) {
                Text("Risoluzione e FPS (letti dal video)").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    TextField("L", value: $vm.width, format: .number.grouping(.never)).frame(width: 58)
                    Text("×").foregroundStyle(.secondary)
                    TextField("A", value: $vm.height, format: .number.grouping(.never)).frame(width: 58)
                    Picker("FPS", selection: $vm.frameRate) {
                        ForEach(FrameRate.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden()
                }
                .textFieldStyle(.roundedBorder)
            }

            Button {
                vm.isWorking ? vm.cancel() : vm.generate(with: store.selected)
            } label: {
                Label(vm.isWorking ? "Annulla" : "Analizza audio", systemImage: vm.isWorking ? "stop.fill" : "waveform")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .disabled(vm.mediaURL == nil)
            .keyboardShortcut(.defaultAction)

            if vm.isWorking {
                if let p = vm.progress { ProgressView(value: p) } else { ProgressView().progressViewStyle(.linear) }
            }
            if !vm.status.isEmpty {
                Text(vm.status).font(.callout).foregroundStyle(.secondary)
            }
            if let error = vm.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill").font(.callout).foregroundStyle(.red)
            }

            Spacer()

            VStack(spacing: 8) {
                FinalCutDragSource(
                    title: "Trascina sulla timeline ↗",
                    isEnabled: !vm.captions.isEmpty && !vm.isWorking,
                    makeXML: { vm.timelineXML(style: store.selected) }
                )
                .frame(height: 40)
                .help("Trascina sopra la clip in Final Cut, all'inizio della timeline")

                Menu("Altri modi di importare") {
                    Button("Apri come progetto in Final Cut Pro") { vm.openInFinalCut(style: store.selected) }
                    Button("Esporta FCPXML…") { vm.exportFCPXML(style: store.selected) }
                    Button("Esporta SRT (sottotitoli nativi)…") { vm.exportSRT() }
                }
                .disabled(vm.captions.isEmpty || vm.isWorking)
            }
        }
        .padding(16)
    }

    private var dropZone: some View {
        Button { vm.chooseMedia() } label: {
            VStack(spacing: 4) {
                Image(systemName: vm.mediaURL == nil ? "square.and.arrow.down" : "film")
                    .font(.title2)
                Text(vm.mediaURL?.lastPathComponent ?? "Trascina qui il video")
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                if vm.mediaURL == nil {
                    Text("o clicca per sceglierlo").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 86)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(isDropTargeted ? Color.purple.opacity(0.25) : Color.purple.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.purple.opacity(isDropTargeted ? 0.9 : 0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5])))
        }
        .buttonStyle(.plain)
        .disabled(vm.isWorking)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url { Task { @MainActor in vm.setMedia(url) } }
            }
            return true
        }
    }

    // MARK: - Colonna destra

    private var rightPanel: some View {
        VStack(spacing: 0) {
            Picker("", selection: $rightTab) {
                ForEach(RightTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(12)

            switch rightTab {
            case .styles:
                StyleLibraryView(store: store)
                    .padding([.horizontal, .bottom], 12)
            case .edit:
                StyleEditorView(style: $store.selected)
            case .text:
                captionList
            }
        }
    }

    private var captionList: some View {
        Group {
            if vm.captions.isEmpty {
                Text("Dopo l'analisi qui trovi tutti i sottotitoli da correggere.")
                    .font(.callout).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(24)
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                List {
                    ForEach($vm.captions) { $caption in
                        HStack(alignment: .firstTextBaseline) {
                            Button(String(format: "%.1fs", caption.start)) { vm.previewTime = caption.start + 0.01 }
                                .buttonStyle(.borderless)
                                .font(.caption.monospacedDigit())
                                .frame(width: 46, alignment: .leading)
                            TextField("", text: $caption.text, axis: .vertical)
                                .textFieldStyle(.plain)
                        }
                    }
                    .onDelete { vm.captions.remove(atOffsets: $0) }
                }
                .listStyle(.inset)
            }
        }
    }
}
