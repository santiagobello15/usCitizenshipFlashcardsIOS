import SwiftUI

private enum CardGesturePhase { case idle, waitingForPeek, peeking, swiping }

struct ContentView: View {
    @State private var cards = allFlashcards
    @State private var currentIndex = 0
    @State private var isShuffled = false
    @State private var useLegacy = false
    @State private var selectedCategories: Set<String> = []
    @State private var results: [String: Assessment] = [:]

    @State private var rotation: Double = 0
    @State private var navigatingForward = true
    @State private var gesturePhase: CardGesturePhase = .idle
    @State private var peekTask: Task<Void, Never>? = nil

    @State private var showSettings = false
    @State private var showLogin = false
    @State private var isAuthenticated = false
    @State private var userEmail: String?
    @State private var userName: String?
    @State private var userAvatarUrl: String?
    @State private var authLoading = false
    @State private var authError: String?
    @State private var showDeleteConfirm = false
    @Environment(\.scenePhase) var scenePhase

    private var currentCard: Flashcard { cards[currentIndex] }
    private var currentAssessment: Assessment? { results[currentCard.id] }

    private var currentCategories: Set<String> {
        Set((useLegacy ? legacyFlashcards : allFlashcards).map(\.category))
    }

    private var availableCategories: [String] {
        currentCategories.sorted()
    }

    private var sourceCards: [Flashcard] {
        let all = useLegacy ? legacyFlashcards : allFlashcards
        let selected = selectedCategories.isEmpty ? currentCategories : selectedCategories
        return all.filter { selected.contains($0.category) }
    }

    private var correctCount: Int { results.values.filter { $0 == .correct }.count }
    private var wrongCount: Int { results.values.filter { $0 == .wrong }.count }
    private var skippedCount: Int { results.values.filter { $0 == .skipped }.count }
    private var totalAssessed: Int { results.count }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Spacer()
                cardArea
                Spacer()
                controls
            }
            .background(Color(.systemBackground))
            .toolbar {
                ToolbarItem(placement: leadingPlacement) {
                    Button { showLogin = true } label: {
                        Image(systemName: isAuthenticated ? "person.circle.fill" : "person.circle")
                            .font(.title3)
                            .foregroundStyle(isAuthenticated ? .blue : .secondary)
                    }
                }
                ToolbarItem(placement: trailingPlacement) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                settingsSheet
            }
            .sheet(isPresented: $showLogin) {
                loginSheet
            }
        }
        .task {
            isAuthenticated = await SupabaseService.shared.isAuthenticated
            userEmail = await SupabaseService.shared.currentUserEmail
            userName = await SupabaseService.shared.currentUserFullName
            userAvatarUrl = await SupabaseService.shared.currentUserAvatarUrl
            if isAuthenticated {
                await restoreSettings()
            }
            if selectedCategories.isEmpty {
                selectedCategories = currentCategories
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background, isAuthenticated {
                Task { await saveCurrentSettings() }
            }
        }
    }

    // MARK: - Settings Sheet

    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section("Question Set") {
                    Picker("Test Version", selection: yearBinding) {
                        Text("2025 (128 questions)").tag(false)
                        Text("2008 (100 questions)").tag(true)
                    }
                    .pickerStyle(.menu)
                }

                Section("Categories") {
                    ForEach(availableCategories, id: \.self) { category in
                        Button {
                            if selectedCategories.contains(category) {
                                selectedCategories.remove(category)
                            } else {
                                selectedCategories.insert(category)
                            }
                            rebuildCards()
                            if currentIndex >= cards.count {
                                currentIndex = max(0, cards.count - 1)
                            }
                            Task { await saveCurrentSettings() }
                        } label: {
                            HStack {
                                Text(category)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedCategories.isEmpty || selectedCategories.contains(category) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }

                Section("Progress") {
                    HStack {
                        Text("Assessed")
                        Spacer()
                        Text("\(totalAssessed) of \(sourceCards.count)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Score")
                        Spacer()
                        let pct = totalAssessed > 0 ? correctCount * 100 / totalAssessed : 0
                        Text("\(pct)%")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Source")
                        Spacer()
                        Text("USCIS.gov")
                            .foregroundStyle(.secondary)
                    }
                }

                if isAuthenticated {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Account")
                                Spacer()
                            }
                        }
                        .confirmationDialog("Delete Account", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                            Button("Delete", role: .destructive) {
                                Task {
                                    try? await SupabaseService.shared.deleteAccount()
                                    isAuthenticated = false
                                    userEmail = nil
                                    userName = nil
                                    userAvatarUrl = nil
                                }
                            }
                            Button("Cancel", role: .cancel) { }
                        } message: {
                            Text("All your saved progress and settings will be permanently deleted. This cannot be undone.")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") { showSettings = false }
                }
            }
        }
    }

    // MARK: - Login Sheet

    private var loginSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                if isAuthenticated {
                    AsyncImage(url: userAvatarUrl.flatMap { URL(string: $0) }) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                        } else if phase.error != nil {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 72))
                                .foregroundStyle(.quaternary)
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(.circle)

                    if let name = userName {
                        Text(name)
                            .font(.title3.weight(.semibold))
                    }
                    Text(userEmail ?? "Unknown")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if authLoading {
                        ProgressView()
                            .padding(.top, 8)
                    }

                    Button(role: .destructive) {
                        Task {
                            authLoading = true
                            await saveCurrentSettings()
                            try? await SupabaseService.shared.signOut()
                            isAuthenticated = false
                            userEmail = nil
                            userName = nil
                            userAvatarUrl = nil
                            authLoading = false
                        }
                    } label: {
                        Text("Sign Out")
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.red)
                    }
                    .padding(.horizontal, 40)
                    .disabled(authLoading)
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.quaternary)

                    Text("Sign in to sync your progress across devices.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    if let error = authError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }

                    if authLoading {
                        ProgressView()
                    }

                    Button {
                        Task {
                            authLoading = true
                            authError = nil
                            do {
                                try await SupabaseService.shared.signInWithGoogle()
                                isAuthenticated = await SupabaseService.shared.isAuthenticated
                                userEmail = await SupabaseService.shared.currentUserEmail
                                userName = await SupabaseService.shared.currentUserFullName
                                userAvatarUrl = await SupabaseService.shared.currentUserAvatarUrl
                                if isAuthenticated {
                                    await restoreSettings()
                                }
                            } catch {
                                authError = error.localizedDescription
                            }
                            authLoading = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "globe")
                            Text("Sign in with Google")
                                .font(.body.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.black, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 40)
                    .disabled(authLoading)

                    Button {
                        showLogin = false
                    } label: {
                        Text("Maybe later")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .navigationTitle(isAuthenticated ? "Account" : "Sign In")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Close") { showLogin = false }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
        .task {
            isAuthenticated = await SupabaseService.shared.isAuthenticated
            userEmail = await SupabaseService.shared.currentUserEmail
            userName = await SupabaseService.shared.currentUserFullName
            userAvatarUrl = await SupabaseService.shared.currentUserAvatarUrl
        }
    }

    // MARK: - Year Binding

    #if os(iOS)
    private var leadingPlacement: ToolbarItemPlacement { .topBarLeading }
    private var trailingPlacement: ToolbarItemPlacement { .topBarTrailing }
    #else
    private var leadingPlacement: ToolbarItemPlacement { .automatic }
    private var trailingPlacement: ToolbarItemPlacement { .automatic }
    #endif

    private var yearBinding: Binding<Bool> {
        Binding(
            get: { useLegacy },
            set: { if $0 != useLegacy { switchSet(to: $0) } }
        )
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Text(currentCard.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(currentIndex + 1) / \(cards.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            ProgressView(value: Double(currentIndex + 1), total: Double(cards.count))
                .tint(.blue)
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
    }

    // MARK: - Card

    private var cardArea: some View {
        ZStack {
            CardView(card: cards[currentIndex], rotation: $rotation)
                .id(cards[currentIndex].id)
                .transition(.asymmetric(
                    insertion: .move(edge: navigatingForward ? .trailing : .leading),
                    removal: .move(edge: navigatingForward ? .leading : .trailing)
                ))
        }
        .padding(.horizontal, 16)
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
                        peekTask?.cancel()
                        peekTask = nil
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
                defer {
                    gesturePhase = .idle
                    peekTask?.cancel()
                    peekTask = nil
                }
                switch gesturePhase {
                case .peeking:
                    withAnimation(.interpolatingSpring(mass: 0.7, stiffness: 80, damping: 12, initialVelocity: 3)) {
                        rotation = 0
                    }
                case .swiping:
                    if dx < -50, currentIndex < cards.count - 1 {
                        navigatingForward = true
                        nextCard()
                    } else if dx > 50, currentIndex > 0 {
                        navigatingForward = false
                        previousCard()
                    }
                case .idle, .waitingForPeek:
                    flipCard()
                }
            }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 14) {
            navigationRow
            shuffleRow
            assessmentRow
            statsRow
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 20)
    }

    // MARK: - Navigation

    private var navigationRow: some View {
        HStack(spacing: 48) {
            Button {
                previousCard()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(currentIndex == 0 ? Color.blue.opacity(0.3) : .blue)
                    .frame(width: 52, height: 52)
                    .background(.quaternary.opacity(0.3), in: Circle())
            }
            .disabled(currentIndex == 0)
            .buttonStyle(.plain)

            Button {
                if currentIndex == cards.count - 1 {
                    resetToStart()
                } else {
                    nextCard()
                }
            } label: {
                if currentIndex == cards.count - 1 {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 52, height: 52)
                        .background(.quaternary.opacity(0.3), in: Circle())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 52, height: 52)
                        .background(.quaternary.opacity(0.3), in: Circle())
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Shuffle

    private var shuffleRow: some View {
        Button {
            if isShuffled {
                cards = sourceCards
            } else {
                cards = sourceCards.shuffled()
            }
            isShuffled.toggle()
            currentIndex = 0
            Task { await saveCurrentSettings() }
        } label: {
            Label("Shuffle Cards", systemImage: isShuffled ? "shuffle.circle.fill" : "shuffle.circle")
                .font(.subheadline)
                .foregroundStyle(.blue)
                .symbolRenderingMode(.hierarchical)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Assessment

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
            if isSelected {
                results.removeValue(forKey: currentCard.id)
            } else {
                results[currentCard.id] = type
            }
            Task { await saveCurrentSettings() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: type.symbol)
                Text(type.label)
                    .fontWeight(.medium)
            }
            .font(.subheadline)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(
                (isSelected ? type.color : Color.gray).opacity(0.15),
                in: Capsule()
            )
            .foregroundStyle(isSelected ? type.color : .secondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? type.color.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 0) {
            if totalAssessed == 0 {
                Text("Tap Wrong, Skip, or Got It to track your progress")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 12) {
                    StatItem(icon: "checkmark.circle.fill", count: correctCount, color: .green)
                    StatItem(icon: "xmark.circle.fill", count: wrongCount, color: .red)
                    StatItem(icon: "forward.fill", count: skippedCount, color: .orange)
                }

                Spacer()

                Button("Clear") {
                    withAnimation { results.removeAll() }
                    Task { await saveCurrentSettings() }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
                .buttonStyle(.plain)
            }
        }
        .frame(height: 24)
    }

    // MARK: - Actions

    private func nextCard() {
        guard currentIndex < cards.count - 1 else { return }
        rotation = 0
        navigatingForward = true
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            currentIndex += 1
        }
    }

    private func previousCard() {
        guard currentIndex > 0 else { return }
        rotation = 0
        navigatingForward = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            currentIndex -= 1
        }
    }

    private func resetToStart() {
        rotation = 0
        navigatingForward = true
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            currentIndex = 0
        }
    }

    // MARK: - Settings Sync

    private func restoreSettings() async {
        guard let userId = await SupabaseService.shared.currentUserId else { return }
        guard let settings = await SupabaseService.shared.fetchSettings(for: userId) else { return }
        useLegacy = settings.useLegacy
        isShuffled = settings.isShuffled
        if let data = settings.categoriesData {
            selectedCategories = SupabaseService.shared.decodeCategories(from: data) ?? currentCategories
        } else {
            selectedCategories = currentCategories
        }
        let filtered = sourceCards
        cards = isShuffled ? filtered.shuffled() : filtered
        currentIndex = 0
        if let data = settings.resultsData {
            results = SupabaseService.shared.decodeResults(from: data) ?? [:]
        }
    }

    private func saveCurrentSettings() async {
        guard let userId = await SupabaseService.shared.currentUserId else { return }
        let settings = SupabaseService.shared.buildSettings(useLegacy: useLegacy, isShuffled: isShuffled, results: results, categories: selectedCategories.isEmpty ? currentCategories : selectedCategories)
        try? await SupabaseService.shared.saveSettings(settings, for: userId)
    }

    private func switchSet(to legacy: Bool) {
        useLegacy = legacy
        selectedCategories = currentCategories
        rebuildCards()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            currentIndex = 0
            results.removeAll()
        }
        isShuffled = false
        Task { await saveCurrentSettings() }
    }

    private func rebuildCards() {
        let filtered = sourceCards
        cards = isShuffled ? filtered.shuffled() : filtered
    }
}

private struct StatItem: View {
    let icon: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text("\(count)")
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }
}

#Preview {
    ContentView()
}
