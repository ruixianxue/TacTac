import AppIntents
import SwiftData
import SwiftUI

@main
struct TacTacApp: App {
    init() {
        TacShortcutsProvider.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Tac.self)
    }
}
