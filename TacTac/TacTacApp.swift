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
            if hasCompletedOnboarding {
                DashboardView()
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
        // 配置本地 SwiftData 数据库以供 UI 预览
        .modelContainer(for: [Tac.self, MemoryItem.self])
    }
}
