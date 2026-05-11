import SwiftUI

@main
struct US_Citizenship_FlashcardsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    Task {
                        try? await SupabaseService.shared.handleAuthCallback(url: url)
                    }
                }
        }
    }
}
