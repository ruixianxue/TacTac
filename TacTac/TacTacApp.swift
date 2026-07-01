import SwiftData
import SwiftUI
import AppIntents

@main
struct TacTacApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        TacShortcutsProvider.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    DashboardView()
                } else {
                    OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                }
            }
        }
        .modelContainer(for: [Tac.self, SavedPlace.self])
    }
}
