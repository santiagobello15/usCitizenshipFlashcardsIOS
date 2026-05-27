import SwiftUI

enum Assessment: String, CaseIterable, Codable {
    case correct
    case wrong
    case skipped

    var label: String {
        switch self {
        case .correct: return "Got It"
        case .wrong: return "Wrong"
        case .skipped: return "Skip"
        }
    }

    var symbol: String {
        switch self {
        case .correct: return "checkmark.circle"
        case .wrong:   return "xmark.circle"
        case .skipped: return "forward.circle"
        }
    }

    var selectedSymbol: String {
        switch self {
        case .correct: return "checkmark.circle.fill"
        case .wrong:   return "xmark.circle.fill"
        case .skipped: return "forward.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .correct: return .green
        case .wrong: return .red
        case .skipped: return .orange
        }
    }
}

struct Flashcard: Identifiable {
    var id: String { question }
    let question: String
    let answer: String
    let category: String
}
