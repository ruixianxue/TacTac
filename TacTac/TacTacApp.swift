import SwiftUI
import SwiftData

@main
struct TacTacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Tac.self)
    }
}
