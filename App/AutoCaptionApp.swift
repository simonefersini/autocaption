import SubtitleUI
import SwiftUI

/// App "contenitore": serve a installare l'estensione in Final Cut Pro,
/// ma funziona anche da sola (stessa interfaccia dell'estensione).
@main
struct AutoCaptionApp: App {
    var body: some Scene {
        WindowGroup("AutoCaption") {
            MainView()
        }
        .defaultSize(width: 560, height: 820)
    }
}
