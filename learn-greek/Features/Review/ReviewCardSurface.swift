import SwiftUI

struct ReviewCardSurface: View {
    let note: CardNote
    let isBackFaceVisible: Bool
    let saveGlowColor: Color
    let saveGlowScale: CGFloat
    let saveGlowOpacity: Double
    let saveGlowBlur: CGFloat

    var body: some View {
        let cornerRadius: CGFloat = 28

        ZStack(alignment: .bottomTrailing) {
            saveGlow

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.08), radius: 24, y: 10)

            readOnlyContent
        }
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var saveGlow: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(saveGlowColor.opacity(0.42))
                .scaleEffect(saveGlowScale)
                .opacity(saveGlowOpacity * 0.82)
                .blur(radius: saveGlowBlur)

            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .strokeBorder(saveGlowColor.opacity(0.92), lineWidth: 10)
                .scaleEffect(saveGlowScale * 0.99)
                .opacity(saveGlowOpacity)
                .blur(radius: saveGlowBlur * 0.72)
        }
        .blendMode(.plusLighter)
    }

    private var readOnlyContent: some View {
        ZStack {
            if isBackFaceVisible {
                cardBackFaceText(CardNoteDisplay.backPlainText(for: note))
            } else {
                cardFaceText(CardNoteDisplay.frontPlainText(for: note))
            }
        }
    }

    private func cardFaceText(_ text: String) -> some View {
        AdaptiveCardText(text: text)
            .padding(.horizontal, 20)
    }

    private func cardBackFaceText(_ text: String) -> some View {
        cardFaceText(text)
            .modifier(BackFaceTilt())
    }
}
