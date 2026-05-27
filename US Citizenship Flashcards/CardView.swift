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

    private var accentColor: Color { isFront ? .blue : .green }

    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(.systemBackground))
            .shadow(color: .black.opacity(0.07), radius: 20, x: 0, y: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.6), lineWidth: 0.5)
            )
            // Top accent stripe
            .overlay(alignment: .top) {
                accentColor
                    .frame(height: 4)
                    .clipShape(
                        UnevenRoundedRectangle(
                            cornerRadii: RectangleCornerRadii(
                                topLeading: 24, bottomLeading: 0,
                                bottomTrailing: 0, topTrailing: 24
                            ),
                            style: .continuous
                        )
                    )
            }
            .overlay {
                VStack(spacing: 0) {
                    // Side label
                    HStack {
                        Text(isFront ? "Question" : "Answer")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(accentColor)
                            .textCase(.uppercase)
                            .tracking(1.5)
                        Spacer()
                        Image(systemName: isFront ? "questionmark.circle" : "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(accentColor.opacity(0.7))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    Spacer()

                    // Main text
                    Text(text)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 28)

                    Spacer()

                    // Bottom hint
                    HStack(spacing: 5) {
                        Image(systemName: "hand.tap")
                            .font(.caption2)
                        Text(isFront ? "Tap to see answer" : "Tap to go back")
                            .font(.caption2)
                    }
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 18)
                }
            }
    }
}
