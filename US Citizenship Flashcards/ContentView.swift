import SwiftUI

private enum CardGesturePhase { case idle, waitingForPeek, peeking, swiping }

// MARK: - Brand color
private extension Color {
    static let brand = Color(red: 204/255, green: 2/255, blue: 3/255)
}

struct ContentView: View {
    @State private var cards = allFlashcards
    @State private var currentIndex = 0
    @AppStorage("isShuffled") private var isShuffled = false
    @AppStorage("useLegacy")  private var useLegacy  = false
    @State private var selectedCategories: Set<String> = []
    @State private var results: [String: Assessment] = [:]

    @State private var rotation: Double = 0
    @State private var navigatingForward = true
    @State private var gesturePhase: CardGesturePhase = .idle
    @State private var peekTask: Task<Void, Never>? = nil

    @State private var showSettings = false
    @State private var categoriesExpanded = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var currentCard: Flashcard { cards[currentIndex] }
    private var currentAssessment: Assessment? { results[currentCard.id] }

    private var currentCategories: Set<String> {
        Set((useLegacy ? legacyFlashcards : allFlashcards).map(\.category))
    }

    private var availableCategories: [String] { currentCategories.sorted() }

    private var sourceCards: [Flashcard] {
        let all = useLegacy ? legacyFlashcards : allFlashcards
        let selected = selectedCategories.isEmpty ? currentCategories : selectedCategories
        return all.filter { selected.contains($0.category) }
    }

    private var correctCount:  Int { results.values.filter { $0 == .correct }.count }
    private var wrongCount:    Int { results.values.filter { $0 == .wrong }.count }
    private var skippedCount:  Int { results.values.filter { $0 == .skipped }.count }
    private var totalAssessed: Int { results.count }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                cardArea
                    .padding(.vertical, 16)
                controls
            }
            .background(Color(.systemBackground))
            .tint(.brand)
            .toolbar {
                ToolbarItem(placement: trailingPlacement) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) { settingsSheet }
        }
        .onAppear { loadPersistedState() }
        .onChange(of: results)            { _, _ in saveResults() }
        .onChange(of: selectedCategories) { _, _ in saveSelectedCategories() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text(currentCard.category)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.brand)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.brand.opacity(0.08), in: Capsule())
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 2) {
                    Text("\(currentIndex + 1)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("/ \(cards.count)")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemFill))
                        .frame(height: 5)
                    Capsule()
                        .fill(Color.brand)
                        .frame(width: geo.size.width * CGFloat(currentIndex + 1) / CGFloat(cards.count),
                               height: 5)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentIndex)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Card area

    private var cardArea: some View {
        ZStack {
            CardView(card: cards[currentIndex], rotation: $rotation)
                .id(cards[currentIndex].id)
                .transition(.asymmetric(
                    insertion: .move(edge: navigatingForward ? .trailing : .leading),
                    removal:   .move(edge: navigatingForward ? .leading  : .trailing)
                ))
        }
        .padding(.horizontal, 20)
        .clipped()
        .contentShape(Rectangle())
        .gesture(cardGesture)
    }

    private func flipCard() {
        withAnimation(.interpolatingSpring(mass: 0.7, stiffness: 80, damping: 12, initialVelocity: 3)) {
            rotation = rotation < 90 ? 180 : 0
        }
    }

    private var cardGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let movement = max(abs(value.translation.width), abs(value.translation.height))
                switch gesturePhase {
                case .idle:
                    if movement > 12 {
                        gesturePhase = .swiping
                    } else {
                        gesturePhase = .waitingForPeek
                        peekTask = Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(180))
                            guard !Task.isCancelled, gesturePhase == .waitingForPeek else { return }
                            gesturePhase = .peeking
                            withAnimation(.interpolatingSpring(mass: 0.7, stiffness: 80, damping: 12, initialVelocity: 3)) {
                                rotation = 180
                            }
                        }
                    }
                case .waitingForPeek:
                    if movement > 12 {
                        gesturePhase = .swiping
                        peekTask?.cancel(); peekTask = nil
                    }
                case .peeking:
                    if movement > 12 {
                        gesturePhase = .swiping
                        withAnimation(.interpolatingSpring(mass: 0.7, stiffness: 80, damping: 12, initialVelocity: 3)) {
                            rotation = 0
                        }
                    }
                case .swiping:
                    break
                }
            }
            .onEnded { value in
                let dx = value.translation.width
                defer { gesturePhase = .idle; peekTask?.cancel(); peekTask = nil }
                switch gesturePhase {
                case .peeking:
                    withAnimation(.interpolatingSpring(mass: 0.7, stiffness: 80, damping: 12, initialVelocity: 3)) {
                        rotation = 0
                    }
                case .swiping:
                    if dx < -50, currentIndex < cards.count - 1 { navigatingForward = true;  nextCard() }
                    else if dx > 50, currentIndex > 0            { navigatingForward = false; previousCard() }
                case .idle, .waitingForPeek:
                    flipCard()
                }
            }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 16) {
            navigationRow
            assessmentRow
            bottomRow
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    // MARK: - Navigation row

    private var navigationRow: some View {
        HStack(spacing: 12) {
            if sizeClass == .regular { Spacer() }

            Button { previousCard() } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(currentIndex == 0 ? .tertiary : .primary)
                    .frame(width: 48, height: 48)
                    .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(currentIndex == 0)
            .buttonStyle(.plain)

            swipeDots
                .frame(maxWidth: sizeClass == .regular ? nil : .infinity)
                .padding(.horizontal, sizeClass == .regular ? 16 : 0)

            Button {
                if currentIndex == cards.count - 1 { resetToStart() }
                else { nextCard() }
            } label: {
                Image(systemName: currentIndex == cards.count - 1 ? "arrow.counterclockwise" : "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 48, height: 48)
                    .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            if sizeClass == .regular { Spacer() }
        }
    }

    private var swipeDots: some View {
        HStack(spacing: 5) {
            ForEach(dotRange, id: \.self) { i in
                Circle()
                    .fill(i == currentIndex ? Color.brand : Color(.systemFill))
                    .frame(width: i == currentIndex ? 7 : 5,
                           height: i == currentIndex ? 7 : 5)
                    .animation(.spring(response: 0.3), value: currentIndex)
            }
        }
    }

    private var dotRange: [Int] {
        let total = cards.count
        guard total > 1 else { return [0] }
        if total <= 9 { return Array(0..<total) }
        let half = 4
        let start = max(0, min(currentIndex - half, total - 9))
        return Array(start..<(start + 9))
    }

    // MARK: - Assessment row

    private var assessmentRow: some View {
        HStack(spacing: 8) {
            assessmentButton(.wrong)
            assessmentButton(.skipped)
            assessmentButton(.correct)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: results[currentCard.id])
    }

    private func assessmentButton(_ type: Assessment) -> some View {
        let isSelected = currentAssessment == type
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                if isSelected { results.removeValue(forKey: currentCard.id) }
                else          { results[currentCard.id] = type }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isSelected ? type.selectedSymbol : type.symbol)
                    .font(.subheadline.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                Text(type.label)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .foregroundStyle(isSelected ? type.color : Color(.label).opacity(0.5))
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? type.color.opacity(0.12) : Color(.secondarySystemFill))
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(type.color.opacity(0.5), lineWidth: 1.5)
                }
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom row

    private var shuffleButton: some View {
        Button {
            if isShuffled { cards = sourceCards }
            else          { cards = sourceCards.shuffled() }
            isShuffled.toggle()
            currentIndex = 0
        } label: {
            Image(systemName: "shuffle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isShuffled ? .white : Color(.label).opacity(0.6))
                .padding(10)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isShuffled ? Color.brand : Color(.secondarySystemFill))
                }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isShuffled)
    }

    private var bottomRow: some View {
        Group {
            if sizeClass == .regular {
                // iPad: stats centered + bigger, shuffle overlaid right
                ZStack {
                    HStack(spacing: 16) {
                        if totalAssessed > 0 {
                            StatChip(symbol: "checkmark.circle.fill", count: correctCount, color: .green, chipFont: .body.weight(.medium))
                            StatChip(symbol: "xmark.circle.fill",     count: wrongCount,   color: .red,   chipFont: .body.weight(.medium))
                            StatChip(symbol: "forward.circle.fill",   count: skippedCount, color: .orange, chipFont: .body.weight(.medium))
                            Button {
                                withAnimation { results.removeAll() }
                            } label: {
                                Text("Clear").font(.subheadline.weight(.medium)).foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("Mark each card to track your progress")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    HStack { Spacer(); shuffleButton }
                }
            } else {
                // iPhone: original layout
                HStack(spacing: 10) {
                    Group {
                        if totalAssessed > 0 {
                            HStack(spacing: 10) {
                                StatChip(symbol: "checkmark.circle.fill", count: correctCount, color: .green)
                                StatChip(symbol: "xmark.circle.fill",     count: wrongCount,   color: .red)
                                StatChip(symbol: "forward.circle.fill",   count: skippedCount, color: .orange)
                                Button {
                                    withAnimation { results.removeAll() }
                                } label: {
                                    Text("Clear").font(.caption.weight(.medium)).foregroundStyle(.tertiary)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            Text("Mark each card to track your progress")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                    shuffleButton
                }
            }
        }
    }

    // MARK: - Placements

    #if os(iOS)
    private var trailingPlacement: ToolbarItemPlacement { .topBarTrailing }
    #else
    private var trailingPlacement: ToolbarItemPlacement { .automatic }
    #endif

    // MARK: - Settings Sheet

    private var yearBinding: Binding<Bool> {
        Binding(get: { useLegacy }, set: { if $0 != useLegacy { switchSet(to: $0) } })
    }

    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section("Question Set") {
                    Picker("Version", selection: yearBinding) {
                        Text("2025 (128 questions)").tag(false)
                        Text("2008 (100 questions)").tag(true)
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    DisclosureGroup("Categories", isExpanded: $categoriesExpanded) {
                        ForEach(availableCategories, id: \.self) { (category: String) in
                            Button {
                                if selectedCategories.contains(category) { selectedCategories.remove(category) }
                                else { selectedCategories.insert(category) }
                                rebuildCards()
                                if currentIndex >= cards.count { currentIndex = max(0, cards.count - 1) }
                            } label: {
                                HStack {
                                    Text(category).foregroundStyle(.primary)
                                    Spacer()
                                    if selectedCategories.isEmpty || selectedCategories.contains(category) {
                                        Image(systemName: "checkmark").foregroundStyle(Color.brand)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Progress") {
                    LabeledContent("Assessed", value: "\(totalAssessed) of \(sourceCards.count)")
                    LabeledContent("Score") {
                        let pct = totalAssessed > 0 ? correctCount * 100 / totalAssessed : 0
                        Text("\(pct)%").foregroundStyle(.secondary)
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("Source", value: "USCIS.gov")
                }

                Section("Legal") {
                    Link(destination: URL(string: "https://www.bellosuite.com/flashcards/privacy")!) {
                        HStack {
                            Text("Privacy Policy").foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Link(destination: URL(string: "https://www.bellosuite.com/flashcards/terms")!) {
                        HStack {
                            Text("Terms of Use").foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button { showSettings = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.fraction(0.65), .large])
        .presentationDragIndicator(.hidden)
        #endif
    }

    // MARK: - Actions

    private func nextCard() {
        guard currentIndex < cards.count - 1 else { return }
        rotation = 0; navigatingForward = true
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { currentIndex += 1 }
    }

    private func previousCard() {
        guard currentIndex > 0 else { return }
        rotation = 0; navigatingForward = false
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { currentIndex -= 1 }
    }

    private func resetToStart() {
        rotation = 0; navigatingForward = true
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { currentIndex = 0 }
    }

    private func switchSet(to legacy: Bool) {
        useLegacy = legacy
        selectedCategories = currentCategories
        rebuildCards()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { currentIndex = 0; results.removeAll() }
        isShuffled = false
    }

    private func rebuildCards() {
        cards = isShuffled ? sourceCards.shuffled() : sourceCards
    }

    // MARK: - Local persistence

    private func loadPersistedState() {
        if let data = UserDefaults.standard.data(forKey: "results"),
           let decoded = try? JSONDecoder().decode([String: Assessment].self, from: data) {
            results = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "selectedCategories"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            // Only keep categories that are valid for the current set
            let valid = Set(decoded).intersection(currentCategories)
            selectedCategories = valid.isEmpty ? currentCategories : valid
        } else {
            selectedCategories = currentCategories
        }
        rebuildCards()
    }

    private func saveResults() {
        if let data = try? JSONEncoder().encode(results) {
            UserDefaults.standard.set(data, forKey: "results")
        }
    }

    private func saveSelectedCategories() {
        if let data = try? JSONEncoder().encode(Array(selectedCategories).sorted()) {
            UserDefaults.standard.set(data, forKey: "selectedCategories")
        }
    }
}

// MARK: - Sub-views

private struct StatChip: View {
    let symbol: String
    let count: Int
    let color: Color
    var chipFont: Font = .caption.weight(.medium)

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).foregroundStyle(color)
            Text("\(count)").monospacedDigit().contentTransition(.numericText()).foregroundStyle(.secondary)
        }
        .font(chipFont)
    }
}

#Preview { ContentView() }
