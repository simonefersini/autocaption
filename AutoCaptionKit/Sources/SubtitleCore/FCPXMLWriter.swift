import Foundation

/// Frame rate del progetto, espresso come durata razionale di un fotogramma (come vuole FCPXML).
public enum FrameRate: String, CaseIterable, Codable, Identifiable, Sendable {
    case fps23_976 = "23.976"
    case fps24 = "24"
    case fps25 = "25"
    case fps29_97 = "29.97"
    case fps30 = "30"
    case fps50 = "50"
    case fps59_94 = "59.94"
    case fps60 = "60"

    public var id: String { rawValue }

    /// Durata di un fotogramma = numerator/denominator secondi.
    public var frameDuration: (numerator: Int, denominator: Int) {
        switch self {
        case .fps23_976: return (1001, 24000)
        case .fps24: return (100, 2400)
        case .fps25: return (100, 2500)
        case .fps29_97: return (1001, 30000)
        case .fps30: return (100, 3000)
        case .fps50: return (100, 5000)
        case .fps59_94: return (1001, 60000)
        case .fps60: return (100, 6000)
        }
    }

    public var framesPerSecond: Double {
        let d = frameDuration
        return Double(d.denominator) / Double(d.numerator)
    }

    /// Fotogramma più vicino a un tempo in secondi.
    public func frame(at seconds: Double) -> Int {
        Int((seconds * framesPerSecond).rounded())
    }

    /// Tempo FCPXML per un numero intero di fotogrammi, es. "3003/30000s".
    public func time(frames: Int) -> String {
        guard frames != 0 else { return "0s" }
        let d = frameDuration
        return "\(frames * d.numerator)/\(d.denominator)s"
    }
}

public struct RGBAColor: Codable, Hashable, Sendable {
    public var red, green, blue, alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let white = RGBAColor(red: 1, green: 1, blue: 1)
    public static let black = RGBAColor(red: 0, green: 0, blue: 0)
    public static let yellow = RGBAColor(red: 1, green: 0.85, blue: 0)

    var fcpxml: String {
        [red, green, blue, alpha].map { String(format: "%.4g", $0) }.joined(separator: " ")
    }
}

/// Aspetto dei titoli generati.
public struct TitleStyle: Codable, Hashable, Sendable {
    public var font: String
    public var fontFace: String
    public var fontSize: Double
    public var textColor: RGBAColor
    public var strokeColor: RGBAColor
    /// 0 = nessun contorno.
    public var strokeWidth: Double
    public var shadow: Bool
    /// Spostamento verticale dal centro, in pixel (negativo = verso il basso).
    public var positionY: Double

    public init(
        font: String = "Helvetica Neue",
        fontFace: String = "Bold",
        fontSize: Double = 64,
        textColor: RGBAColor = .white,
        strokeColor: RGBAColor = .black,
        strokeWidth: Double = 3,
        shadow: Bool = true,
        positionY: Double = -380
    ) {
        self.font = font
        self.fontFace = fontFace
        self.fontSize = fontSize
        self.textColor = textColor
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.shadow = shadow
        self.positionY = positionY
    }
}

/// Formato del progetto Final Cut generato.
public struct ProjectFormat: Codable, Hashable, Sendable {
    public var width: Int
    public var height: Int
    public var frameRate: FrameRate

    public init(width: Int = 1920, height: Int = 1080, frameRate: FrameRate = .fps25) {
        self.width = width
        self.height = height
        self.frameRate = frameRate
    }
}

/// Titolo Motion da usare per ogni sottotitolo. Di default il "Titolo base" di Final Cut,
/// ma si può puntare a un titolo personalizzato creato in Motion (con le sue animazioni).
public struct TitleTemplate: Codable, Hashable, Sendable {
    public var name: String
    public var uid: String
    /// Chiave del parametro Posizione nel template (quella del Titolo base è nota).
    public var positionParameterKey: String?

    public init(name: String, uid: String, positionParameterKey: String?) {
        self.name = name
        self.uid = uid
        self.positionParameterKey = positionParameterKey
    }

    public static let basicTitle = TitleTemplate(
        name: "Basic Title",
        uid: ".../Titles.localized/Bumper:Opener.localized/Basic Title.localized/Basic Title.moti",
        positionParameterKey: "9999/999166631/999166633/1/100/101"
    )
}

/// Crea un file .fcpxml con un progetto che contiene un titolo per ogni sottotitolo,
/// collegati (lane 1) sopra uno spazio vuoto lungo quanto il parlato.
///
/// In Final Cut: File ▸ Importa ▸ XML…, apri il progetto "Sottotitoli", seleziona tutti i titoli
/// (⌘A), copia (⌘C) e incolla (⌘V) nella tua timeline con la testina all'inizio della clip.
public enum FCPXMLWriter {

    public static func fcpxml(
        captions: [Caption],
        projectName: String,
        eventName: String = "AutoCaption",
        format: ProjectFormat = ProjectFormat(),
        style: TitleStyle = TitleStyle(),
        template: TitleTemplate = .basicTitle,
        mediaDuration: Double? = nil
    ) -> String {
        let rate = format.frameRate
        let (items, totalFrames) = frameItems(captions, rate: rate, mediaDuration: mediaDuration)

        var xml = header(format: format, template: template) + """
          <library>
            <event name="\(escape(eventName))">
              <project name="\(escape(projectName))">
                <sequence format="r1" duration="\(rate.time(frames: totalFrames))" tcStart="0s" tcFormat="NDF" audioLayout="stereo" audioRate="48k">
                  <spine>
                    <gap name="Gap" offset="0s" start="0s" duration="\(rate.time(frames: totalFrames))">

        """
        for (index, item) in items.enumerated() {
            xml += titleElement(item, index: index, lane: 1, offset: item.start, rate: rate,
                                style: style, template: template, indent: 14)
        }
        xml += """
                    </gap>
                  </spine>
                </sequence>
              </project>
            </event>
          </library>
        </fcpxml>

        """
        return xml
    }

    /// FCPXML da trascinare direttamente sulla timeline (pasteboard `com.apple.finalcutpro.xml`).
    ///
    /// Secondo Apple, sulla timeline si possono rilasciare solo *clip* (non progetti): qui c'è una clip
    /// che contiene una storyline di titoli, con spazi vuoti dove nessuno parla. Rilasciata sopra la
    /// storyline principale, all'inizio del video, diventa una storyline collegata di sottotitoli.
    public static func timelineClip(
        captions: [Caption],
        clipName: String = "AutoCaption",
        eventName: String = "AutoCaption",
        format: ProjectFormat = ProjectFormat(),
        style: TitleStyle = TitleStyle(),
        template: TitleTemplate = .basicTitle
    ) -> String {
        let rate = format.frameRate
        let (items, totalFrames) = frameItems(captions, rate: rate, mediaDuration: nil)

        var xml = header(format: format, template: template) + """
          <event name="\(escape(eventName))">
            <clip name="\(escape(clipName))" duration="\(rate.time(frames: totalFrames))" format="r1" tcFormat="NDF">
              <spine>

        """
        var cursor = 0
        for (index, item) in items.enumerated() {
            if item.start > cursor {
                xml += """
                        <gap name="Gap" offset="\(rate.time(frames: cursor))" start="0s" duration="\(rate.time(frames: item.start - cursor))"/>

                """
            }
            xml += titleElement(item, index: index, lane: nil, offset: item.start, rate: rate,
                                style: style, template: template, indent: 8)
            cursor = item.start + item.length
        }
        xml += """
              </spine>
            </clip>
          </event>
        </fcpxml>

        """
        return xml
    }

    // MARK: - Pezzi comuni

    typealias FrameItem = (text: String, start: Int, length: Int)

    /// Converte in fotogrammi interi, evitando sovrapposizioni dovute all'arrotondamento.
    static func frameItems(_ captions: [Caption], rate: FrameRate, mediaDuration: Double?) -> ([FrameItem], Int) {
        var items: [FrameItem] = []
        var previousEnd = 0
        for caption in captions {
            let start = max(rate.frame(at: caption.start), previousEnd)
            let end = max(rate.frame(at: caption.end), start + 1)
            items.append((caption.text, start, end - start))
            previousEnd = end
        }
        return (items, max(previousEnd, rate.frame(at: mediaDuration ?? 0), 1))
    }

    static func header(format: ProjectFormat, template: TitleTemplate) -> String {
        let fd = format.frameRate.frameDuration
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE fcpxml>
        <fcpxml version="1.10">
          <resources>
            <format id="r1" frameDuration="\(fd.numerator)/\(fd.denominator)s" width="\(format.width)" height="\(format.height)"/>
            <effect id="r2" name="\(escape(template.name))" uid="\(escape(template.uid))"/>
          </resources>

        """
    }

    static func titleElement(_ item: FrameItem, index: Int, lane: Int?, offset: Int, rate: FrameRate,
                             style: TitleStyle, template: TitleTemplate, indent: Int) -> String {
        let pad = String(repeating: " ", count: indent)
        let styleID = "ts\(index + 1)"
        let name = String(item.text.replacingOccurrences(of: "\n", with: " ").prefix(60))
        let laneAttribute = lane.map { " lane=\"\($0)\"" } ?? ""
        var lines = [
            "<title ref=\"r2\"\(laneAttribute) offset=\"\(rate.time(frames: offset))\" duration=\"\(rate.time(frames: item.length))\" name=\"\(escape(name))\">",
        ]
        if let key = template.positionParameterKey {
            lines.append("  <param name=\"Position\" key=\"\(key)\" value=\"0 \(number(style.positionY))\"/>")
        }
        lines += [
            "  <text>",
            "    <text-style ref=\"\(styleID)\">\(escape(item.text))</text-style>",
            "  </text>",
            "  <text-style-def id=\"\(styleID)\">",
            "    <text-style \(textStyleAttributes(style))/>",
            "  </text-style-def>",
            "</title>",
        ]
        return lines.map { pad + $0 + "\n" }.joined()
    }

    static func textStyleAttributes(_ style: TitleStyle) -> String {
        var attributes = [
            "font=\"\(escape(style.font))\"",
            "fontSize=\"\(number(style.fontSize))\"",
            "fontFace=\"\(escape(style.fontFace))\"",
            "fontColor=\"\(style.textColor.fcpxml)\"",
            "alignment=\"center\"",
        ]
        if style.strokeWidth > 0 {
            attributes.append("strokeColor=\"\(style.strokeColor.fcpxml)\"")
            attributes.append("strokeWidth=\"\(number(style.strokeWidth))\"")
        }
        if style.shadow {
            attributes.append("shadowColor=\"0 0 0 0.75\"")
            attributes.append("shadowOffset=\"5 315\"")
            attributes.append("shadowBlurRadius=\"4\"")
        }
        return attributes.joined(separator: " ")
    }

    static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.2f", value)
    }

    static func escape(_ string: String) -> String {
        var out = ""
        out.reserveCapacity(string.count)
        for ch in string {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&apos;"
            default: out.append(ch)
            }
        }
        return out
    }
}
