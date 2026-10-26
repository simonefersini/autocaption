# AutoCaption: sottotitoli automatici per Final Cut Pro

Un'app per Mac con estensione per Final Cut Pro, simile a mCaption AI. Trascrive il parlato
**in locale** con Whisper (WhisperKit), divide il testo in sottotitoli leggibili e li esporta in
due formati da importare in Final Cut:

| Export | Cosa ottieni in Final Cut | Come si importa |
|---|---|---|
| **FCPXML** | Un progetto con un **titolo per ogni sottotitolo** (font, colore, contorno, posizione), modificabili come qualsiasi titolo | "Apri in Final Cut Pro" oppure *File ▸ Importa ▸ XML…* |
| **SRT** | **Sottotitoli nativi** di Final Cut (ruolo Sottotitoli), esportabili e attivabili/disattivabili | *File ▸ Importa ▸ Sottotitoli…* |

Stili di impaginazione: **Classico** (2 righe, TV/YouTube), **Social** (2–3 parole in maiuscolo,
Reels/TikTok) e **Parola per parola**. Formati di progetto 16:9, 9:16, 1:1, 4:5 e 4K, a qualsiasi frame rate.

## Struttura

```
AutoCaption/
├── AutoCaptionKit/              Swift Package con tutta la logica
│   ├── Sources/SubtitleCore/    segmentazione, stili e ricerca, SRT, FCPXML (puro Foundation, con test)
│   ├── Sources/SubtitleEngine/  audio, formato del video, fotogrammi (AVFoundation) + trascrizione (WhisperKit)
│   ├── Sources/SubtitleUI/      interfaccia SwiftUI condivisa da app ed estensione:
│   │                            anteprima sul video, libreria stili, editor, trascinamento in Final Cut
│   └── Tests/
├── App/AutoCaptionApp.swift     app contenitore (funziona anche da sola)
└── Extension/                   estensione per Final Cut Pro
    ├── AutoCaptionExtensionViewController.swift
    ├── Info-NSExtension.plist   blocco NSExtension da mettere nell'Info.plist
    └── AutoCaption.entitlements
```

## Requisiti

- Mac con Apple Silicon (consigliato; su Intel funziona ma è lento)
- macOS 14 o successivo, Final Cut Pro 10.6 o successivo
- Xcode 16 o successivo
- **Workflow Extensions SDK** di Apple: <https://developer.apple.com/download/all/?q=WorkflowExtensions>
  (basta l'Apple ID gratuito; installalo **prima** di creare il progetto: aggiunge il template a Xcode)

## Creare il progetto in Xcode (una volta sola, circa 10 minuti)

1. **Nuovo progetto**: Xcode ▸ File ▸ New ▸ Project ▸ macOS ▸ **App**.
   Nome `AutoCaption`, Interface **SwiftUI**, Language **Swift**. Salvalo nella cartella `AutoCaption/`.
2. **Codice dell'app**: elimina il file `AutoCaptionApp.swift` / `ContentView.swift` generati e
   trascina dentro `App/AutoCaptionApp.swift`.
3. **Pacchetto**: File ▸ Add Package Dependencies… ▸ **Add Local…** ▸ scegli la cartella `AutoCaptionKit`.
   Aggiungi il prodotto **SubtitleUI** al target dell'app. WhisperKit viene scaricato in automatico.
4. **Estensione**: File ▸ New ▸ Target ▸ macOS ▸ **Final Cut Pro Workflow Extension**.
   Nome `AutoCaptionExtension`, *Embed in Application* = `AutoCaption`.
   - Elimina il view controller e lo storyboard/xib creati dal template (se il template è
     Objective-C, elimina anche i file `.h`/`.m`).
   - Aggiungi `Extension/AutoCaptionExtensionViewController.swift` al target dell'estensione.
   - Nel tab *General* dell'estensione, sotto *Frameworks and Libraries*, aggiungi **SubtitleUI**.
   - Apri l'`Info.plist` dell'estensione e fai coincidere il blocco `NSExtension` con
     `Extension/Info-NSExtension.plist` (soprattutto `ProExtensionPrincipalViewControllerClass` =
     `AutoCaptionExtensionViewController`).
5. **Sandbox**: per **entrambi** i target, in *Signing & Capabilities* ▸ App Sandbox spunta
   *Outgoing Connections (Client)* e *User Selected File: Read/Write*
   (oppure usa `Extension/AutoCaption.entitlements`).
6. **Firma**: imposta il tuo Team per i due target (va bene anche un account sviluppatore gratuito).
7. **Build**: Product ▸ Archive, oppure costruisci in Release, poi copia `AutoCaption.app` in
   **/Applications** e **aprila una volta**. Riavvia Final Cut Pro: AutoCaption compare nel menu
   **Estensioni** della barra strumenti (icona a forma di puzzle).

## Uso (stesso flusso di mCaption)

1. In Final Cut esporta il progetto: *Condividi ▸ File master*. Così i tempi partono da 00:00 come la timeline.
2. Apri AutoCaption (menu **Estensioni** di Final Cut) e trascina il file nel riquadro viola.
   Risoluzione e fps vengono letti in automatico dal video.
3. Scegli la lingua (oppure *Rileva automaticamente*) e premi **Analizza audio**.
   Al primo avvio il modello viene scaricato.
4. Scegli uno stile dalla libreria a destra: l'**anteprima al centro mostra il sottotitolo sopra il
   vero fotogramma del video**. Con lo slider e le frecce scorri tra i sottotitoli.
5. Tieni premuto **Trascina sulla timeline** e rilascialo sopra la clip, all'inizio della timeline:
   arriva una storyline collegata con un titolo per ogni sottotitolo.
6. In Final Cut ogni sottotitolo resta un titolo normale: lo selezioni e cambi testo, ombra,
   contorno ed effetti dall'inspector (anche su più titoli insieme).

Se il trascinamento non dovesse funzionare, nel menu **Altri modi di importare** trovi:
*Apri come progetto in Final Cut Pro* (poi ⌘A, ⌘C e ⌘V nella tua timeline), *Esporta FCPXML* ed
*Esporta SRT* (sottotitoli nativi, *File ▸ Importa ▸ Sottotitoli…*).

### Stili (uno per cliente)

- La libreria parte con **4 stili** (Classico, Social bianco, Social giallo, Parola per parola), da
  duplicare e modificare. Non ci sono decine di stili preimpostati da scorrere.
- **Nuovo stile**, **Duplica**, **Elimina**, ⭐ **Preferiti** (anche dal clic destro su uno stile).
- Nel tab **Modifica stile** imposti il nome, il **cliente**, il font (tutti quelli installati sul Mac),
  lo stile del font, la dimensione, il colore, il contorno, l'ombra, l'altezza dal basso (in %, così lo
  stesso stile va bene in 9:16 e in 16:9), le righe, i caratteri per riga, le parole per sottotitolo,
  il maiuscolo e la punteggiatura.
- La **barra di ricerca** cerca nel nome e nel cliente (es. "lumine" trova tutti gli stili di Lumine Apulia).
- Gli stili si salvano da soli in `styles.json`. Per avere gli stessi stili nell'app e nell'estensione,
  aggiungi a entrambi i target la capability **App Groups** con lo stesso identificativo e scrivilo in
  `StyleStore.appGroupID`.

### Punteggiatura e divisione delle frasi

- Whisper mette già **virgole, punti, punti interrogativi e maiuscole**. Il modello *Massima qualità*
  è il più preciso in italiano.
- Negli stili classici la punteggiatura resta e si va a capo a fine frase.
- Gli stili social e "parola per parola" la tolgono (si può riattivare nello stile).
- Le parole con l'apostrofo restano unite ("c'è", "l'automatico").
- Un sottotitolo non finisce mai su articoli, preposizioni o congiunzioni ("dei", "la", "che", "e"…):
  la parola passa al sottotitolo successivo.

## Test

La logica (segmentazione, SRT, FCPXML) si può testare anche senza Xcode:

```bash
cd AutoCaptionKit && swift test
```

## Limiti attuali e cose da verificare su Mac

Questo codice è stato scritto e la parte `SubtitleCore` è stata testata su Linux. **App,
estensione e trascrizione non sono ancora state compilate su un Mac**, quindi al primo build
potrebbe servire qualche piccola correzione. Da verificare:

- **Posizione dei titoli**: il parametro Posizione del *Titolo base* (chiave
  `9999/999166631/999166633/1/100/101`) viene scritto in pixel dal centro. Controlla che il
  risultato in Final Cut corrisponda.
- **Contorno**: in alcune versioni di Final Cut `strokeWidth` positivo rende il testo "vuoto"
  con il solo contorno. Se succede, usa un valore negativo in `FCPXMLWriter.textStyleAttributes`.
- **Trascina sulla timeline**: segue la guida di Apple (*Supporting Drag and Drop for Data Sent to
  Final Cut Pro*). Sulla timeline si possono rilasciare solo clip, quindi viene trascinata una clip
  che contiene una storyline di titoli. È la prima cosa da provare su Mac: se Final Cut la rifiuta,
  la struttura si sistema in `FCPXMLWriter.timelineClip`.
- I font devono essere installati sul Mac. Poppins, usato negli stili di partenza, si scarica gratis
  da Google Fonts.
- I modelli vengono scaricati due volte, una per l'app e una per l'estensione, perché i due
  sandbox sono separati. Si risolve con lo stesso App Group (`downloadBase` in `WhisperKitConfig`).

## Prossimi passi possibili (per avvicinarsi a mCaption)

- **Bagliore (glow) e animazioni**: il Titolo base di Final Cut non ha il glow via FCPXML. Serve un
  **titolo Motion personalizzato** con animazioni (pop, evidenziazione della parola corrente):
  si crea in Motion, lo si pubblica in Final Cut e si passa il suo `uid` a `TitleTemplate`.
- **Evidenziazione parola per parola** (stile "karaoke"): i tempi delle singole parole sono già
  disponibili in `words`.
- **Leggere i tempi direttamente dalla timeline** (FCPXML trascinato dalla Libreria all'estensione,
  oppure le API `ProExtensionHost` per frame rate e testina), così non serve esportare l'audio.
- Emoji automatiche e parole chiave colorate.
- Traduzione dei sottotitoli in altre lingue.
