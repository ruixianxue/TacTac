import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tac.updatedAt, order: .reverse) private var items: [Tac]

    @State private var searchText = ""
    @State private var isAddItemPresented = false
    @State private var editingItem: Tac?

    private var searchResults: [Tac] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return items
        }

        return items.filter {
            $0.objectName.localizedCaseInsensitiveContains(query)
                || $0.place.localizedCaseInsensitiveContains(query)
                || $0.specificPlace.localizedCaseInsensitiveContains(query)
                || ($0.area?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if items.isEmpty {
                    EmptyStateView()
                } else if searchResults.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(searchResults) { item in
                            Button {
                                editingItem = item
                            } label: {
                                MemoryItemRow(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("TacTac")
            .searchable(text: $searchText, prompt: "Search an item")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddItemPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add item")
                }
            }
            .sheet(isPresented: $isAddItemPresented) {
                MemoryItemFormView(
                    title: "Add Item",
                    saveTitle: "Save",
                    draft: .empty
                ) { draft in
                    addItem(draft)
                }
            }
            .sheet(item: $editingItem) { item in
                MemoryItemFormView(
                    title: "Edit Item",
                    saveTitle: "Done",
                    draft: MemoryItemDraft(item: item)
                ) { draft in
                    updateItem(item, with: draft)
                }
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(searchResults[index])
            }

            try? modelContext.save()
        }
    }

    private func addItem(_ draft: MemoryItemDraft) {
        let repository = TacRepository(modelContext: modelContext)
        let place = Tac.displayPlace(specificPlace: draft.specificLocation, area: draft.area)
        let rawInput = "\(draft.objectName) is \(place)"

        do {
            try repository.save(
                objectName: draft.objectName,
                place: place,
                specificPlace: draft.specificLocation,
                area: draft.area,
                rawInput: rawInput,
                tags: [Tac.iconTag(for: draft.iconName)]
            )
        } catch {
            assertionFailure("Could not save item: \(error.localizedDescription)")
        }
    }

    private func updateItem(_ item: Tac, with draft: MemoryItemDraft) {
        let place = Tac.displayPlace(specificPlace: draft.specificLocation, area: draft.area)
        let rawInput = "\(draft.objectName) is \(place)"

        item.updateLocation(
            objectName: draft.objectName,
            place: place,
            specificPlace: draft.specificLocation,
            area: draft.area,
            rawInput: rawInput,
            tags: [Tac.iconTag(for: draft.iconName)]
        )

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Could not update item: \(error.localizedDescription)")
        }
    }
}

private struct MemoryItemFormView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let saveTitle: String
    let onSave: (MemoryItemDraft) -> Void

    @State private var objectName: String
    @State private var specificLocation: String
    @State private var area: String
    @State private var selectedIconName: String

    init(title: String, saveTitle: String, draft: MemoryItemDraft, onSave: @escaping (MemoryItemDraft) -> Void) {
        self.title = title
        self.saveTitle = saveTitle
        self.onSave = onSave
        _objectName = State(initialValue: draft.objectName)
        _specificLocation = State(initialValue: draft.specificLocation)
        _area = State(initialValue: draft.area ?? "")
        _selectedIconName = State(initialValue: draft.iconName)
    }

    private var canSave: Bool {
        !objectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !specificLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Item name", text: $objectName)
                        .textInputAutocapitalization(.words)
                }

                Section("Location") {
                    TextField("Specific location", text: $specificLocation)
                        .textInputAutocapitalization(.sentences)
                    TextField("Area or room", text: $area)
                        .textInputAutocapitalization(.words)
                }

                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 12)], spacing: 12) {
                        ForEach(MemoryIconOption.all) { option in
                            Button {
                                selectedIconName = option.systemName
                            } label: {
                                Image(systemName: option.systemName)
                                    .font(.system(size: 22))
                                    .foregroundStyle(selectedIconName == option.systemName ? .white : Color.accentColor)
                                    .frame(width: 48, height: 48)
                                    .background(
                                        Circle()
                                            .fill(selectedIconName == option.systemName ? Color.accentColor : Color.accentColor.opacity(0.1))
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option.title)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(saveTitle) {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let draft = MemoryItemDraft(
            objectName: objectName.trimmingCharacters(in: .whitespacesAndNewlines),
            specificLocation: specificLocation.trimmingCharacters(in: .whitespacesAndNewlines),
            area: area.trimmingCharacters(in: .whitespacesAndNewlines),
            iconName: selectedIconName
        )

        onSave(draft)
        dismiss()
    }
}

private struct MemoryItemDraft {
    let objectName: String
    let specificLocation: String
    let area: String?
    let iconName: String

    static let empty = MemoryItemDraft(
        objectName: "",
        specificLocation: "",
        area: "",
        iconName: MemoryIconOption.defaultOption.systemName
    )

    init(objectName: String, specificLocation: String, area: String, iconName: String) {
        self.objectName = objectName
        self.specificLocation = specificLocation
        self.area = area.isEmpty ? nil : area
        self.iconName = iconName
    }

    init(item: Tac) {
        self.objectName = item.objectName
        self.specificLocation = item.specificPlace
        self.area = item.area
        self.iconName = item.savedIconName ?? MemoryIconOption.iconName(for: item)
    }
}

private struct MemoryIconOption: Identifiable {
    let title: String
    let systemName: String

    var id: String { systemName }

    static let defaultOption = MemoryIconOption(title: "Item", systemName: "cube.box.fill")

    static let all = [
        defaultOption,
        MemoryIconOption(title: "Keys", systemName: "key.fill"),
        MemoryIconOption(title: "Wallet", systemName: "wallet.pass.fill"),
        MemoryIconOption(title: "Glasses", systemName: "eyeglasses"),
        MemoryIconOption(title: "Phone", systemName: "iphone"),
        MemoryIconOption(title: "Laptop", systemName: "laptopcomputer"),
        MemoryIconOption(title: "Bag", systemName: "backpack.fill"),
        MemoryIconOption(title: "Book", systemName: "book.closed.fill"),
        MemoryIconOption(title: "Clothes", systemName: "tshirt.fill"),
        MemoryIconOption(title: "Charger", systemName: "cable.connector"),
        MemoryIconOption(title: "Remote", systemName: "appletvremote.gen4.fill"),
        MemoryIconOption(title: "Watch", systemName: "applewatch")
    ]

    static func iconName(for item: Tac) -> String {
        let normalizedName = item.normalizedObjectName

        if normalizedName.contains("key") {
            return "key.fill"
        } else if normalizedName.contains("wallet") {
            return "wallet.pass.fill"
        } else if normalizedName.contains("charger") || normalizedName.contains("cable") {
            return "cable.connector"
        } else if normalizedName.contains("glass") || normalizedName.contains("sunglass") {
            return "eyeglasses"
        } else if normalizedName.contains("phone") {
            return "iphone"
        }

        return defaultOption.systemName
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No items saved yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Say \"Hey Siri, TacTac\" and then tell TacTac where you put something, or tap + to add an item.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

struct MemoryItemRow: View {
    let item: Tac

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: iconName)
                    .foregroundStyle(Color.accentColor)
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.objectName)
                    .font(.headline)

                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(item.place)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Text(item.updatedAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }

    private var iconName: String {
        item.savedIconName ?? MemoryIconOption.iconName(for: item)
    }
}
