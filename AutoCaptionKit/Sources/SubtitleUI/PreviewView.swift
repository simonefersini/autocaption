import SubtitleCore
import SwiftUI

/// Anteprima del sottotitolo sopra il vero fotogramma del video, nella proporzione del progetto.
struct PreviewView: View {
    @ObservedObject var vm: CaptionViewModel
    var style: CaptionStyle

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let aspect = CGFloat(vm.width) / CGFloat(max(vm.height, 1))
                let fit = fittedSize(aspect: aspect, in: geo.size)
                let scale = fit.width / CGFloat(max(vm.width, 1))
                let titleStyle = style.titleStyle(forHeight: vm.height)

                ZStack {
                    Rectangle().fill(Color.black)
                    if let frame = vm.previewFrame {
                        Image(decorative: frame, scale: 1)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Text(vm.mediaURL == nil ? "Carica un video per vedere l'anteprima" : "…")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    StyledCaptionText(
                        text: vm.captionAtPreviewTime?.text ?? (vm.captions.isEmpty ? "Anteprima del sottotitolo" : ""),
                        style: titleStyle,
                        uppercase: style.segmentation.uppercase,
                        scale: scale,
                        maxWidth: fit.width * 0.92
                    )
                    // In Final Cut la Y cresce verso l'alto, in SwiftUI verso il basso.
                    .offset(y: -titleStyle.positionY * scale)
                }
                .frame(width: fit.width, height: fit.height)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.08)))
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }

            HStack(spacing: 8) {
                Button { jump(-1) } label: { Image(systemName: "backward.end.fill") }
                    .help("Sottotitolo precedente")
                Slider(value: $vm.previewTime, in: 0...max(vm.mediaDuration, 0.1))
                    .disabled(vm.mediaURL == nil)
                Button { jump(1) } label: { Image(systemName: "forward.end.fill") }
                    .help("Sottotitolo successivo")
                Text(timecode(vm.previewTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 78, alignment: .trailing)
            }
            .buttonStyle(.borderless)
            .disabled(vm.captions.isEmpty && vm.mediaURL == nil)
        }
    }

    private func fittedSize(aspect: CGFloat, in size: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return .zero }
        return size.width / size.height > aspect
            ? CGSize(width: size.height * aspect, height: size.height)
            : CGSize(width: size.width, height: size.width / aspect)
    }

    private func jump(_ direction: Int) {
        let t = vm.previewTime
        let target = direction > 0
            ? vm.captions.first { $0.start > t + 0.01 }
            : vm.captions.last { $0.start < t - 0.05 }
        if let target { vm.previewTime = target.start + 0.01 }
    }

    private func timecode(_ seconds: Double) -> String {
        let total = Int(seconds)
        let frames = Int((seconds - Double(total)) * vm.frameRate.framesPerSecond)
        return String(format: "%02d:%02d:%02d:%02d", total / 3600, total / 60 % 60, total % 60, frames)
    }
}
