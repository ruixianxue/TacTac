import SwiftData
import SwiftUI
import AppIntents

@main
struct TacTacApp: App {
    // 使用 AppStorage 记录用户是否已经完成首次引导
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false

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
            .task {
                TacLocationService.shared.requestPermissionIfNeeded()
            }
        }
        .modelContainer(for: [Tac.self, SavedPlace.self])
    }
}
