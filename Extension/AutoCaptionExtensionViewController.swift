import Cocoa
import SubtitleUI
import SwiftUI

/// Classe principale dell'estensione: Final Cut Pro la istanzia e ne mostra la vista
/// in una finestra fluttuante (menu Estensioni nella barra strumenti).
/// Il nome Objective-C deve coincidere con `ProExtensionPrincipalViewControllerClass` in Info.plist.
@objc(AutoCaptionExtensionViewController)
final class AutoCaptionExtensionViewController: NSViewController {

    override func loadView() {
        let hosting = NSHostingView(rootView: MainView())
        hosting.frame = NSRect(x: 0, y: 0, width: 1040, height: 720)
        view = hosting
    }
}
