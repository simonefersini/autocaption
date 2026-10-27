# AutoCaption: istruzioni per Claude

Rispondi all'utente in italiano, in modo semplice: è un videomaker, non uno sviluppatore.

## Cos'è
App per Mac + estensione per Final Cut Pro (Workflow Extension) che genera sottotitoli
automatici, simile a mCaption AI di MotionVFX. Trascrizione locale con WhisperKit, sottotitoli
esportati come titoli FCPXML da trascinare sulla timeline (oppure SRT).
Leggi `README.md` per il flusso d'uso e la struttura.

- `AutoCaptionKit/` Swift Package con tutta la logica e l'interfaccia (SwiftUI). I test di
  `SubtitleCore` girano con `swift test`.
- `App/AutoCaptionApp.swift` punto d'ingresso dell'app.
- `Extension/` view controller, blocco Info.plist ed entitlements dell'estensione.

Il codice è stato scritto su Linux: **app ed estensione non sono mai state compilate su un Mac**.
Aspettati errori di compilazione nelle parti macOS (SubtitleEngine, SubtitleUI) e correggili.

## Primo obiettivo sul Mac
1. Verifica gli strumenti: `xcodebuild -version` (serve Xcode completo, non solo i Command Line
   Tools; se manca, chiedi all'utente di installarlo dal Mac App Store).
2. Crea il progetto Xcode `AutoCaption.xcodeproj` nella root del repository. Il modo consigliato è
   XcodeGen (`brew install xcodegen`, chiedi prima di installare) con un `project.yml` che definisca:
   - target app macOS `AutoCaption` (sorgente `App/`, deployment target macOS 14, dipendenza dal
     pacchetto locale `AutoCaptionKit`, prodotto `SubtitleUI`);
   - App Sandbox con `network.client` e `files.user-selected.read-write`
     (vedi `Extension/AutoCaption.entitlements`);
   - firma: "Sign to Run Locally" finché l'utente non indica un Team.
3. Compila con `xcodebuild` e correggi gli errori finché la build va a buon fine.
4. Avvia l'app e chiedi all'utente di provarla: trascina un video, Analizza audio, prova gli stili,
   poi "Trascina sulla timeline" in Final Cut.
5. Solo dopo: aggiungi il target estensione (`com.apple.FinalCut.WorkflowExtension`, Info.plist da
   `Extension/Info-NSExtension.plist`, view controller `AutoCaptionExtensionViewController`),
   incorporato nell'app; installa l'app in /Applications, aprila una volta e riavvia Final Cut.

## Cose da verificare con l'utente
- Il trascinamento sulla timeline (`FinalCutDragSource` + `FCPXMLWriter.timelineClip`).
- Che posizione, contorno e ombra dei titoli in Final Cut corrispondano all'anteprima.

## Git
Fai commit piccoli con messaggi in italiano. Chiedi all'utente prima del push.
