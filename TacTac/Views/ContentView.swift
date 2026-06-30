import AppIntents
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tac.updatedAt, order: .reverse) private var memories: [Tac]

    @State private var rememberInput = "my keys are on the chair in my room"
    @State private var findInput = "my keys"
    @State private var result = "Ready"
    @State private var isWorking = false
    @State private var isRememberSiriTipVisible = true
    @State private var isFindSiriTipVisible = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Siri") {
                    SiriTipView(intent: RememberTacIntent(), isVisible: $isRememberSiriTipVisible)
                    SiriTipView(intent: FindTacIntent(), isVisible: $isFindSiriTipVisible)
                }

                Section("Remember") {
                    TextField("Example: my keys are on the chair in my room", text: $rememberInput, axis: .vertical)
                        .textInputAutocapitalization(.never)

                    Button {
                        Task {
                            await remember()
                        }
                    } label: {
                        Label("Save Location", systemImage: "tray.and.arrow.down")
                    }
                    .disabled(isWorking || rememberInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("Find") {
                    TextField("Example: my keys", text: $findInput, axis: .vertical)
                        .textInputAutocapitalization(.never)

                    Button {
                        Task {
                            await find()
                        }
                    } label: {
                        Label("Find Item", systemImage: "magnifyingglass")
                    }
                    .disabled(isWorking || findInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("Result") {
                    Text(result)
                }

                Section("Saved Items") {
                    if memories.isEmpty {
                        Text("No saved items yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(memories) { tac in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tac.objectName)
                                    .font(.headline)
                                Text(tac.place)
                                    .foregroundStyle(.secondary)
                                if let area = tac.area {
                                    Text("Specific: \(tac.specificPlace)  Area: \(area)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Specific: \(tac.specificPlace)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(tac.updatedAt, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("TacTac")
            .disabled(isWorking)
        }
    }

    private func remember() async {
        isWorking = true
        defer { isWorking = false }

        do {
            let service = makeMemoryService()
            let tac = try await service.remember(input: rememberInput)
            result = "Saved \(tac.objectName) at \(tac.place)."
        } catch {
            result = error.localizedDescription
        }
    }

    private func find() async {
        isWorking = true
        defer { isWorking = false }

        do {
            let service = makeMemoryService()
            result = try await service.find(query: findInput)
        } catch {
            result = error.localizedDescription
        }
    }

    private func makeMemoryService() -> TacMemoryService {
        let repository = TacRepository(modelContext: modelContext)
        return TacMemoryService(repository: repository)
    }
}
