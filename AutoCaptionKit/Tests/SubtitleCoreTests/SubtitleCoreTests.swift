import XCTest
@testable import SubtitleCore

final class SubtitleCoreTests: XCTestCase {

    // "Ciao a tutti. Oggi vediamo come generare i sottotitoli in automatico con Final Cut."
    let words: [Word] = [
        Word(text: " Ciao", start: 0.00, end: 0.30),
        Word(text: " a", start: 0.30, end: 0.40),
        Word(text: " tutti.", start: 0.40, end: 0.90),
        Word(text: " Oggi", start: 1.10, end: 1.40),
        Word(text: " vediamo", start: 1.40, end: 1.80),
        Word(text: " come", start: 1.80, end: 2.00),
        Word(text: " generare", start: 2.00, end: 2.50),
        Word(text: " i", start: 2.50, end: 2.60),
        Word(text: " sottotitoli", start: 2.60, end: 3.20),
        Word(text: " in", start: 3.20, end: 3.30),
        Word(text: " automatico", start: 3.30, end: 3.90),
        Word(text: " con", start: 3.90, end: 4.00),
        Word(text: " Final", start: 4.00, end: 4.30),
        Word(text: " Cut.", start: 4.30, end: 4.80),
        Word(text: "<|endoftext|>", start: 4.80, end: 4.80),
        Word(text: " Dopo", start: 7.00, end: 7.40),
        Word(text: " pausa", start: 7.40, end: 7.90),
    ]

    func testClassicSplitsOnSentencesAndPauses() {
        let captions = Segmenter.captions(from: words, options: .classic)
        XCTAssertEqual(captions.map(\.text), [
            "Ciao a tutti.",
            "Oggi vediamo come generare i\nsottotitoli in automatico con Final Cut.",
            "Dopo pausa",
        ].map { $0 })
        // Pausa breve (0.2s) tra 1° e 2° chiusa; pausa lunga (2.2s) mantenuta.
        XCTAssertEqual(captions[0].end, captions[1].start, accuracy: 0.0001)
        XCTAssertEqual(captions[1].end, 4.80, accuracy: 0.0001)
    }

    func testLinesRespectMaxChars() {
        var options = SegmentationOptions.classic
        options.maxCharsPerLine = 20
        for caption in Segmenter.captions(from: words, options: options) {
            let lines = caption.text.split(separator: "\n")
            XCTAssertLessThanOrEqual(lines.count, 2)
            for line in lines { XCTAssertLessThanOrEqual(line.count, 20, "\(line)") }
        }
    }

    func testSocialPreset() {
        let captions = Segmenter.captions(from: words, options: .social)
        XCTAssertEqual(captions.first?.text, "CIAO A TUTTI")
        XCTAssertTrue(captions.allSatisfy { $0.text.split(separator: " ").count <= 3 })
        XCTAssertFalse(captions.contains { $0.text.contains(".") })
    }

    func testWordByWordNoOverlap() {
        let captions = Segmenter.captions(from: words, options: .wordByWord)
        XCTAssertEqual(captions.count, 16)
        for (a, b) in zip(captions, captions.dropFirst()) {
            XCTAssertLessThanOrEqual(a.end, b.start + 1e-9)
            XCTAssertGreaterThan(a.end, a.start)
        }
    }

    func testApostrophesKeptWhenRemovingPunctuation() {
        let w = [Word(text: " l'acqua,", start: 0, end: 0.5)]
        XCTAssertEqual(Segmenter.captions(from: w, options: .social).first?.text, "L'ACQUA")
    }

    func testSRT() {
        let srt = SRTWriter.srt(from: [
            Caption(text: "Ciao", start: 0, end: 1.5),
            Caption(text: "Riga 1\nRiga 2", start: 3661.25, end: 3662),
        ])
        XCTAssertEqual(srt, """
        1
        00:00:00,000 --> 00:00:01,500
        Ciao

        2
        01:01:01,250 --> 01:01:02,000
        Riga 1
        Riga 2

        """)
    }

    func testFrameRateTimes() {
        XCTAssertEqual(FrameRate.fps25.time(frames: 25), "2500/2500s")
        XCTAssertEqual(FrameRate.fps29_97.frame(at: 1.0), 30)
        XCTAssertEqual(FrameRate.fps29_97.time(frames: 30), "30030/30000s")
        XCTAssertEqual(FrameRate.fps25.time(frames: 0), "0s")
    }

    func testFCPXMLContainsTitlesWithoutOverlap() {
        let captions = [
            Caption(text: "Tom & Jerry <3", start: 0, end: 1.01),
            Caption(text: "Secondo", start: 1.0, end: 2.0),
        ]
        let xml = FCPXMLWriter.fcpxml(captions: captions, projectName: "Test \"1\"")
        XCTAssertTrue(xml.contains("Tom &amp; Jerry &lt;3"))
        XCTAssertTrue(xml.contains("name=\"Test &quot;1&quot;\""))
        XCTAssertTrue(xml.contains("<title ref=\"r2\" lane=\"1\" offset=\"0s\" duration=\"2500/2500s\""))
        XCTAssertTrue(xml.contains("offset=\"2500/2500s\" duration=\"2500/2500s\""))
        XCTAssertTrue(xml.contains("<text-style-def id=\"ts2\">"))
    }

    func testTimelineClipHasGapsAndNoLanes() {
        let captions = [
            Caption(text: "Primo", start: 1.0, end: 2.0),
            Caption(text: "Secondo", start: 2.0, end: 3.0),
            Caption(text: "Terzo", start: 5.0, end: 6.0),
        ]
        let xml = FCPXMLWriter.timelineClip(captions: captions, format: ProjectFormat(width: 1080, height: 1920, frameRate: .fps30))
        XCTAssertTrue(xml.contains("<clip name=\"AutoCaption\" duration=\"18000/3000s\" format=\"r1\""))
        XCTAssertFalse(xml.contains("<library>"))
        XCTAssertFalse(xml.contains("lane="))
        // Gap iniziale (0–1 s), nessun gap tra 1° e 2°, gap 3–5 s.
        XCTAssertTrue(xml.contains("<gap name=\"Gap\" offset=\"0s\" start=\"0s\" duration=\"3000/3000s\"/>"))
        XCTAssertTrue(xml.contains("<gap name=\"Gap\" offset=\"9000/3000s\" start=\"0s\" duration=\"6000/3000s\"/>"))
        XCTAssertEqual(xml.components(separatedBy: "<gap ").count - 1, 2)
        XCTAssertEqual(xml.components(separatedBy: "<title ").count - 1, 3)
    }

    func testStyleSearchByNameAndClient() {
        var a = CaptionStyle(name: "Reel estate", client: "Lumine Apulia")
        a.isFavorite = true
        let b = CaptionStyle(name: "Intervista", client: "La Giudecca")
        let c = CaptionStyle(name: "Città", client: "")
        let all = [b, c, a]
        XCTAssertEqual(StyleSearch.filter(all, query: "").map(\.name), ["Reel estate", "Città", "Intervista"])
        XCTAssertEqual(StyleSearch.filter(all, query: "lumine").map(\.name), ["Reel estate"])
        XCTAssertEqual(StyleSearch.filter(all, query: "citta").map(\.name), ["Città"])
        XCTAssertEqual(StyleSearch.filter(all, query: "giudecca inter").map(\.name), ["Intervista"])
        XCTAssertEqual(StyleSearch.filter(all, query: "", favoritesOnly: true).count, 1)
    }

    func testVerticalPercentToPixels() {
        let style = CaptionStyle(name: "x", verticalPercent: 15)
        XCTAssertEqual(style.titleStyle(forHeight: 1920).positionY, -672)
        XCTAssertEqual(style.titleStyle(forHeight: 1080).positionY, -378)
        XCTAssertEqual(CaptionStyle(name: "c", verticalPercent: 50).titleStyle(forHeight: 1920).positionY, 0)
    }

    func testStylesRoundTripJSON() throws {
        let data = try JSONEncoder().encode(CaptionStyle.starters)
        XCTAssertEqual(try JSONDecoder().decode([CaptionStyle].self, from: data), CaptionStyle.starters)
    }

    func testApostropheFragmentsAreMerged() {
        let w = [
            Word(text: " dove", start: 0, end: 0.2), Word(text: " c", start: 0.2, end: 0.3),
            Word(text: "'è", start: 0.3, end: 0.4), Word(text: " l'", start: 0.4, end: 0.5),
            Word(text: "automatico", start: 0.5, end: 1.0), Word(text: " ok", start: 1.0, end: 1.2),
            Word(text: ",", start: 1.2, end: 1.2),
        ]
        XCTAssertEqual(Segmenter.captions(from: w, options: .classic).first?.text, "dove c'è l'automatico ok,")
    }

    func testSocialDoesNotEndOnWeakWord() {
        let text = "questi sono già dei sottotitoli ma non li considerare"
        let w = text.split(separator: " ").enumerated().map { i, t in
            Word(text: " " + t, start: Double(i) * 0.3, end: Double(i) * 0.3 + 0.28)
        }
        let captions = Segmenter.captions(from: w, options: .social)
        for c in captions.dropLast() {
            let lastWord = String(c.text.split(separator: " ").last ?? "").lowercased()
            XCTAssertFalse(Segmenter.isWeak(lastWord), "\(c.text)")
        }
        XCTAssertEqual(captions.map(\.text).joined(separator: " "), text.uppercased())
    }
}
