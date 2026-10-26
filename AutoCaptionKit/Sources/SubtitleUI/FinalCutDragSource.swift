import AppKit
import SwiftUI

/// Pulsante "Trascina sulla timeline": avvia un drag con l'FCPXML "promesso" sui tipi di pasteboard
/// di Final Cut Pro, come descritto da Apple in
/// "Supporting Drag and Drop for Data Sent to Final Cut Pro".
/// L'XML viene generato solo al momento del rilascio, con lo stile e il testo correnti.
struct FinalCutDragSource: NSViewRepresentable {
    var title: String
    var isEnabled: Bool
    var makeXML: () -> String

    func makeNSView(context: Context) -> DragView {
        let view = DragView()
        view.update(title: title, isEnabled: isEnabled, makeXML: makeXML)
        return view
    }

    func updateNSView(_ view: DragView, context: Context) {
        view.update(title: title, isEnabled: isEnabled, makeXML: makeXML)
    }

    final class DragView: NSView, NSDraggingSource, NSPasteboardItemDataProvider {
        /// Dal più recente al generico: Final Cut sceglie la versione più alta che conosce.
        /// Generiamo XML versione 1.10, quindi non dichiariamo versioni superiori.
        static let pasteboardTypes = ["com.apple.finalcutpro.xml.v1-10", "com.apple.finalcutpro.xml"]
            .map { NSPasteboard.PasteboardType($0) }

        private var makeXML: () -> String = { "" }
        private var isEnabled = true
        private let label = NSTextField(labelWithString: "")
        private var mouseDownEvent: NSEvent?

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            layer?.cornerRadius = 8
            label.font = .systemFont(ofSize: 13, weight: .semibold)
            label.textColor = .white
            label.alignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: centerXAnchor),
                label.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) non supportato") }

        func update(title: String, isEnabled: Bool, makeXML: @escaping () -> String) {
            label.stringValue = title
            self.isEnabled = isEnabled
            self.makeXML = makeXML
            layer?.backgroundColor = (isEnabled ? NSColor.systemPurple : NSColor.systemPurple.withAlphaComponent(0.3)).cgColor
            label.textColor = isEnabled ? .white : .white.withAlphaComponent(0.5)
        }

        override func resetCursorRects() {
            if isEnabled { addCursorRect(bounds, cursor: .openHand) }
        }

        override func mouseDown(with event: NSEvent) { mouseDownEvent = event }

        override func mouseDragged(with event: NSEvent) {
            guard isEnabled, let start = mouseDownEvent else { return }
            let distance = hypot(event.locationInWindow.x - start.locationInWindow.x,
                                 event.locationInWindow.y - start.locationInWindow.y)
            guard distance > 3 else { return }
            mouseDownEvent = nil

            let item = NSPasteboardItem()
            item.setDataProvider(self, forTypes: Self.pasteboardTypes)
            let draggingItem = NSDraggingItem(pasteboardWriter: item)
            draggingItem.setDraggingFrame(bounds, contents: snapshot())
            beginDraggingSession(with: [draggingItem], event: event, source: self)
        }

        // MARK: NSDraggingSource

        func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            context == .outsideApplication ? .copy : []
        }

        // MARK: NSPasteboardItemDataProvider

        func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
            guard Self.pasteboardTypes.contains(type) else { return }
            item.setData(Data(makeXML().utf8), forType: type)
        }

        private func snapshot() -> NSImage {
            let image = NSImage(size: bounds.size)
            if let rep = bitmapImageRepForCachingDisplay(in: bounds) {
                cacheDisplay(in: bounds, to: rep)
                image.addRepresentation(rep)
            }
            return image
        }
    }
}
