import AppIntents
import SwiftData

struct RememberTacIntent: AppIntent {
    static var title: LocalizedStringResource = "Remember Item Location"
    static var description = IntentDescription("Save where an item was placed.")
    static var openAppWhenRun = false

    @Parameter(title: "What did you put where?")
    var input: String

    static var parameterSummary: some ParameterSummary {
        Summary("Remember \(\.$input)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = try TacMemoryIntentServices.makeMemoryService()
        let tac = try await service.remember(input: input)

        return .result(
            dialog: IntentDialog("Saved \(tac.objectName) at \(tac.place).")
        )
    }
}

struct FindTacIntent: AppIntent {
    static var title: LocalizedStringResource = "Find Item Location"
    static var description = IntentDescription("Find the last saved location for an item.")
    static var openAppWhenRun = false

    @Parameter(title: "What are you looking for?")
    var query: String

    static var parameterSummary: some ParameterSummary {
        Summary("Find \(\.$query)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = try TacMemoryIntentServices.makeMemoryService()
        let answer = try await service.find(query: query)

        return .result(dialog: IntentDialog(stringLiteral: answer))
    }
}

struct TacShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RememberTacIntent(),
            phrases: [
                "Remember an item in \(.applicationName)",
                "Tell \(.applicationName) to remember an item"
            ],
            shortTitle: "Remember Item",
            systemImageName: "tray.and.arrow.down"
        )

        AppShortcut(
            intent: FindTacIntent(),
            phrases: [
                "Find an item in \(.applicationName)",
                "Ask \(.applicationName) where an item is"
            ],
            shortTitle: "Find Item",
            systemImageName: "magnifyingglass"
        )
    }
}

enum TacMemoryIntentServices {
    @MainActor
    static func makeMemoryService() throws -> TacMemoryService {
        let container = try ModelContainer(for: Tac.self)
        let repository = TacRepository(modelContext: ModelContext(container))

        return TacMemoryService(repository: repository)
    }
}
