import AppKit
import SubtitleCore
import SwiftUI

/// Disegna un testo con lo stile dei titoli, in scala rispetto al formato del progetto.
/// Usato dall'anteprima sul video e dalle miniature della libreria stili.
struct StyledCaptionText: View {
    var text: String
    var style: TitleStyle
    var uppercase: Bool
    /// Pixel di anteprima per pixel di progetto.
    var scale: CGFloat
    var maxWidth: CGFloat

    var body: some View {
        let size = max(4, style.fontSize * scale)
        let stroke = style.strokeWidth * scale
        Text(uppercase ? text.uppercased() : text)
            .font(Font(FontCatalog.font(family: style.font, face: style.fontFace, size: size)))
            .foregroundStyle(style.textColor.color)
            .multilineTextAlignment(.center)
            .frame(maxWidth: maxWidth)
            // Contorno: ombre senza sfocatura in 8 direzioni (SwiftUI non ha uno stroke del testo).
            .modifier(OutlineModifier(color: style.strokeColor.color, width: stroke))
            .shadow(color: style.shadow ? .black.opacity(0.75) : .clear, radius: 4 * scale, x: 3.5 * scale, y: 3.5 * scale)
    }
}

private struct OutlineModifier: ViewModifier {
    var color: Color
    var width: CGFloat

    func body(content: Content) -> some View {
        if width <= 0 {
            content
        } else {
            let d = width
            content
                .shadow(color: color, radius: 0, x: d, y: 0)
                .shadow(color: color, radius: 0, x: -d, y: 0)
                .shadow(color: color, radius: 0, x: 0, y: d)
                .shadow(color: color, radius: 0, x: 0, y: -d)
        }
    }
}

extension RGBAColor {
    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha) }

    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .white
        self.init(red: ns.redComponent, green: ns.greenComponent, blue: ns.blueComponent, alpha: ns.alphaComponent)
    }
}

/// Font installati sul Mac (famiglie e stili), per i menu e per l'anteprima.
enum FontCatalog {
    static let families: [String] = NSFontManager.shared.availableFontFamilies.sorted()

    /// Nomi degli stili di una famiglia, es. ["Regular", "SemiBold", "Bold"].
    static func faces(of family: String) -> [String] {
        (NSFontManager.shared.availableMembers(ofFontFamily: family) ?? []).compactMap { $0[1] as? String }
    }

    static func font(family: String, face: String, size: CGFloat) -> NSFont {
        let members = NSFontManager.shared.availableMembers(ofFontFamily: family) ?? []
        let match = members.first { ($0[1] as? String)?.caseInsensitiveCompare(face) == .orderedSame } ?? members.first
        if let postScriptName = match?[0] as? String, let font = NSFont(name: postScriptName, size: size) {
            return font
        }
        return .systemFont(ofSize: size, weight: .bold)
    }

    static func isInstalled(_ family: String) -> Bool {
        NSFontManager.shared.availableMembers(ofFontFamily: family) != nil
    }
}
