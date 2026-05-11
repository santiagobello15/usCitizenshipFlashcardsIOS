import SwiftUI

struct CardView: View {
    let card: Flashcard
    @Binding var rotation: Double

    var body: some View {
        ZStack {
            CardFace(text: card.question, label: "Question", accentColor: .blue)
                .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
                .opacity(rotation < 90 ? 1 : 0)

            CardFace(text: card.answer, label: "Answer", accentColor: .green)
                .rotation3DEffect(.degrees(rotation + 180), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
                .opacity(rotation >= 90 ? 1 : 0)
        }
    }
}

private struct CardFace: View {
    let text: String
    let label: String
    let accentColor: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(.background)
            .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.separator, lineWidth: 0.5)
            )
            .overlay {
                VStack(spacing: 0) {
                    Spacer()

                    Text(label)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(accentColor)
                        .textCase(.uppercase)
                        .tracking(2.4)

                    Spacer().frame(height: 24)

                    Text(text)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 28)

                    Spacer()

                    Text(accentColor == .blue ? "Hold to answer" : "Release for question")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .tracking(0.5)

                    Spacer().frame(height: 8)
                }
                .padding(.vertical, 32)
            }
    }
}
