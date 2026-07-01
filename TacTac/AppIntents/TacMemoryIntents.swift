import AppIntents
import SwiftData

struct RememberTacIntent: AppIntent {
    static var title: LocalizedStringResource = "Remember Where I Put Something"
    static var description = IntentDescription("Save where an item was placed so TacTac can find it later.")
    static var openAppWhenRun = false
    static var supportedModes: IntentModes = .background

    @Parameter(
        title: "Item and Location",
        description: "For example, my keys are on the kitchen counter.",
        requestValueDialog: "What should TacTac remember?",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var itemName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Remember \(\.$itemName)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        do {
            let service = try TacMemoryIntentServices.makeMemoryService()
            let tac = try await service.remember(input: itemName)
            let dialog = "Saved \(tac.objectName) at \(tac.place)."

            return .result(value: dialog, dialog: IntentDialog(stringLiteral: dialog))
        } catch {
            let message = error.localizedDescription
            return .result(value: message, dialog: IntentDialog(stringLiteral: message))
        }
    }
}

struct FindTacIntent: AppIntent {
    static var title: LocalizedStringResource = "Find Where I Put Something"
    static var description = IntentDescription("Find the last saved location for an item.")
    static var openAppWhenRun = false
    static var supportedModes: IntentModes = .background

    @Parameter(
        title: "Item",
        description: "For example, my keys or my phone charger.",
        requestValueDialog: "What item should TacTac find?",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var query: String

    static var parameterSummary: some ParameterSummary {
        Summary("Find \(\.$query)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        do {
            let service = try TacMemoryIntentServices.makeMemoryService()
            let answer = try await service.findForSiriDemo(query: query)

            return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
        } catch {
            let message = error.localizedDescription
            return .result(value: message, dialog: IntentDialog(stringLiteral: message))
        }
    }
}

struct HandleTacCommandIntent: AppIntent {
    static var title: LocalizedStringResource = "Handle TacTac Command"
    static var description = IntentDescription("Remember or find an item from one dictated command.")
    static var openAppWhenRun = false
    static var supportedModes: IntentModes = .background

    @Parameter(
        title: "Command",
        description: "For example, remember my jacket is in my room, or where is my jacket.",
        requestValueDialog: "Yes?",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var command: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Handle \(\.$command)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        var command = command?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if command.isEmpty {
            command = try await $command.requestValue("Yes?")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard !command.isEmpty else {
            return .result(value: "I did not hear a command.")
        }

        do {
            let service = try TacMemoryIntentServices.makeMemoryService()
            let normalizedCommand = command.lowercased()

            if Self.isFindCommand(normalizedCommand) {
                let answer = try await service.findForSiriDemo(query: command)
                return .result(value: answer)
            }

            let rememberInput = Self.rememberInput(from: command)
            let tac = try await service.remember(input: rememberInput)
            let dialog = "Saved \(tac.objectName) at \(tac.place)."

            return .result(value: dialog)
        } catch {
            return .result(value: error.localizedDescription)
        }
    }

    private static func isFindCommand(_ command: String) -> Bool {
        command.hasPrefix("where ")
            || command.hasPrefix("find ")
            || command.hasPrefix("look for ")
    }

    private static func rememberInput(from command: String) -> String {
        var cleaned = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercase = cleaned.lowercased()
        let prefixes = [
            "remember that ",
            "remember ",
            "i put ",
            "put "
        ]

        for prefix in prefixes where lowercase.hasPrefix(prefix) {
            cleaned.removeFirst(prefix.count)
            break
        }

        return cleaned
    }
}

struct TacShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RememberTacIntent(),
            phrases: [
                "Remember where I put something in \(.applicationName)",
                "Tell \(.applicationName) where I put something",
                "Save an item location in \(.applicationName)"
            ],
            shortTitle: "Remember Item",
            systemImageName: "tray.and.arrow.down",
            parameterPresentation: ParameterPresentation(
                for: \.$itemName,
                summary: Summary("Remember \(\.$itemName)")
            ) {
                OptionsCollection(RememberItemOptionsProvider(), title: "Examples")
            }
        )

        AppShortcut(
            intent: FindTacIntent(),
            phrases: [
                "Find where I put something in \(.applicationName)",
                "Ask \(.applicationName) where I put something",
                "Find an item in \(.applicationName)"
            ],
            shortTitle: "Find Item",
            systemImageName: "magnifyingglass"
        )

        AppShortcut(
            intent: HandleTacCommandIntent(),
            phrases: [
                "Use \(.applicationName)",
                "Start \(.applicationName)",
                "Talk to \(.applicationName)"
            ],
            shortTitle: "TacTac",
            systemImageName: "bubble.left.and.text.bubble.right"
        )
    }
}

private struct RememberItemOptionsProvider: DynamicOptionsProvider {
    nonisolated func results() async throws -> [String] {
        [
            "my keys are on the kitchen counter",
            "my wallet is in my backpack",
            "my charger is on my desk"
        ]
    }
}

enum TacMemoryIntentServices {
    @MainActor
    static func makeMemoryService() throws -> TacMemoryService {
        let container = try ModelContainer(for: Tac.self, SavedPlace.self)
        let repository = TacRepository(modelContext: ModelContext(container))

        return TacMemoryService(repository: repository)
    }
}
