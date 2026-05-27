import SwiftUI

struct CardView: View {
    let card: Flashcard
    @Binding var rotation: Double

    var body: some View {
        ZStack {
            CardFace(text: card.question, isFront: true)
                .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
                .opacity(rotation < 90 ? 1 : 0)

            CardFace(text: card.answer, isFront: false)
                .rotation3DEffect(.degrees(rotation + 180), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
                .opacity(rotation >= 90 ? 1 : 0)
        }
    }
}

private struct CardFace: View {
    let text: String
    let isFront: Bool

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var accentColor: Color { isFront ? .blue : .green }
    private var isIPad: Bool { sizeClass == .regular }

    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.6), lineWidth: 0.5)
            )
            .overlay {
                VStack(spacing: 0) {
                    // Label
                    HStack {
                        Text(isFront ? "Question" : "Answer")
                            .font(isIPad ? .subheadline.weight(.semibold) : .caption2.weight(.semibold))
                            .foregroundStyle(accentColor)
                            .textCase(.uppercase)
                            .tracking(1.5)
                        Spacer()
                        Image(systemName: isFront ? "questionmark.circle" : "checkmark.circle")
                            .font(isIPad ? .title3 : .caption)
                            .foregroundStyle(accentColor.opacity(0.7))
                    }
                    .padding(.horizontal, isIPad ? 32 : 24)
                    .padding(.top, isIPad ? 28 : 20)

                    Spacer()

                    // Main text
                    Text(text)
                        .font(isIPad ? .title.weight(.semibold) : .title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, isIPad ? 48 : 28)

                    Spacer()

                    // Bottom hint
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap")
                            .font(isIPad ? .subheadline : .caption2)
                        Text(isFront ? "Tap to see answer" : "Tap to go back")
                            .font(isIPad ? .subheadline : .caption2)
                    }
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, isIPad ? 28 : 18)
                }
            }
    }
}
