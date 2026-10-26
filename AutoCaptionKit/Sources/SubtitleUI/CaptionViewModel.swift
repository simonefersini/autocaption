import AppKit
import Foundation
import SubtitleCore
import SubtitleEngine
import UniformTypeIdentifiers

@MainActor
public final class CaptionViewModel: ObservableObject {

    // Sorgente
    @Published public private(set) var mediaURL: URL?
    @Published public private(set) var mediaDuration: Double = 0
    @Published public var width = 1080
    @Published public var height = 1920
    @Published public var frameRate: FrameRate = .fps30

    // Trascrizione
    @Published public var language: TranscriptionLanguage = TranscriptionLanguage.all[0]
    @Published public var model: WhisperModel = .largeTurbo
    @Published public private(set) var isWorking = false
    @Published public private(set) var status = ""
    @Published public private(set) var progress: Double?
    @Published public var errorMessage: String?

    // Risultato
    @Published public private(set) var words: [Word] = []
    @Published public var captions: [Caption] = []

    // Anteprima
    @Published public var previewTime: Double = 0 {
        didSet { schedulePreviewFrame() }
    }
    @Published public private(set) var previewFrame: CGImage?

    private let transcriber = Transcriber()
    private var task: Task<Void, Never>?
    private var grabber: FrameGrabber?
    private var frameTask: Task<Void, Never>?

    public init() {}

    var format: ProjectFormat { ProjectFormat(width: width, height: height, frameRate: frameRate) }

    var baseName: String { mediaURL?.deletingPathExtension().lastPathComponent ?? "Progetto" }

    /// Il sottotitolo visibile all'istante dell'anteprima.
    public var captionAtPreviewTime: Caption? {
        captions.first { previewTime >= $0.start && previewTime < $0.end }
    }

    // MARK: - Sorgente

    public func chooseMedia() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .audio, .audiovisualContent]
        panel.message = "Scegli il video da sottotitolare (es. il master esportato da Final Cut)"
        if panel.runModal() == .OK, let url = panel.url { setMedia(url) }
    }

    public func setMedia(_ url: URL) {
        mediaURL = url
        words = []
        captions = []
        errorMessage = nil
        status = ""
        grabber = FrameGrabber(url: url)
        Task {
            if let info = try? await MediaInfo.load(from: url) {
                width = info.width
                height = info.height
                frameRate = info.frameRate
                mediaDuration = info.duration
            }
            previewTime = min(1, mediaDuration / 2)
        }
    }

    // MARK: - Trascrizione

    public func generate(with style: CaptionStyle) {
        guard let url = mediaURL, !isWorking else { return }
        isWorking = true
        errorMessage = nil
        progress = nil
        let model = model, language = language

        task = Task {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let words = try await transcriber.transcribe(url: url, model: model, language: language) { stage in
                    Task { @MainActor in self.show(stage) }
                }
                self.words = words
                resegment(with: style)
                status = words.isEmpty ? "Nessun parlato trovato." : "Pronto: \(captions.count) sottotitoli. Trascinali sulla timeline."
                if let first = captions.first { previewTime = first.start + 0.01 }
            } catch is CancellationError {
                status = "Annullato."
            } catch {
                errorMessage = error.localizedDescription
                status = ""
            }
            progress = nil
            isWorking = false
        }
    }

    public func cancel() { task?.cancel() }

    /// Ridivide le parole con le regole dello stile (le correzioni manuali al testo si perdono).
    public func resegment(with style: CaptionStyle) {
        guard !words.isEmpty else { return }
        captions = Segmenter.captions(from: words, options: style.segmentation)
    }

    // MARK: - Export

    func timelineXML(style: CaptionStyle) -> String {
        FCPXMLWriter.timelineClip(
            captions: captions,
            clipName: "Sottotitoli – \(style.name)",
            format: format,
            style: style.titleStyle(forHeight: height)
        )
    }

    func projectXML(style: CaptionStyle) -> String {
        FCPXMLWriter.fcpxml(
            captions: captions,
            projectName: "Sottotitoli – \(baseName)",
            format: format,
            style: style.titleStyle(forHeight: height),
            mediaDuration: mediaDuration
        )
    }

    public func exportFCPXML(style: CaptionStyle) {
        save(projectXML(style: style), name: "Sottotitoli – \(baseName).fcpxml", type: UTType(filenameExtension: "fcpxml") ?? .xml)
    }

    public func exportSRT() {
        save(SRTWriter.srt(from: captions), name: "\(baseName).srt", type: UTType(filenameExtension: "srt") ?? .plainText)
    }

    /// Alternativa al trascinamento: importa un progetto con i titoli (File ▸ Importa ▸ XML).
    public func openInFinalCut(style: CaptionStyle) {
        do {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("AutoCaption", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent("Sottotitoli – \(baseName.replacingOccurrences(of: "/", with: "-")).fcpxml")
            try projectXML(style: style).write(to: url, atomically: true, encoding: .utf8)
            if let fcp = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.FinalCut") {
                NSWorkspace.shared.open([url], withApplicationAt: fcp, configuration: NSWorkspace.OpenConfiguration())
            } else {
                NSWorkspace.shared.open(url)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save(_ contents: String, name: String, type: UTType) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        panel.allowedContentTypes = [type]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try contents.write(to: url, atomically: true, encoding: .utf8) } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Helpers

    private func schedulePreviewFrame() {
        guard let grabber else { return }
        frameTask?.cancel()
        let time = previewTime
        frameTask = Task {
            try? await Task.sleep(nanoseconds: 60_000_000) // evita richieste a raffica mentre si trascina lo slider
            guard !Task.isCancelled else { return }
            let image = await grabber.frame(at: time)
            if !Task.isCancelled, let image { previewFrame = image }
        }
    }

    private func show(_ stage: TranscriptionStage) {
        switch stage {
        case .loadingModel:
            status = "Carico il modello (al primo avvio viene scaricato)…"
            progress = nil
        case .extractingAudio:
            status = "Estraggo l'audio…"
            progress = nil
        case .transcribing(let fraction):
            status = "Analizzo l'audio…"
            progress = fraction > 0 ? fraction : nil
        }
    }
}
