import SwiftUI

@main
struct USCivicsFlashApp: App {
    init() {
        ReviewManager.startSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
