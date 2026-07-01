import MapKit
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tac.updatedAt, order: .reverse) private var items: [Tac]
    @Query(sort: \SavedPlace.name) private var savedPlaces: [SavedPlace]

    @State private var searchText = ""
    @State private var isAddItemPresented = false
    @State private var isPlacesPresented = false
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
                || ($0.namedPlace?.localizedCaseInsensitiveContains(query) ?? false)
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
                                MemoryItemRow(item: item, savedPlaces: savedPlaces)
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isPlacesPresented = true
                    } label: {
                        Image(systemName: "location.circle")
                    }
                    .accessibilityLabel("Saved places")
                }

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
                    draft: .empty,
                    savedPlaces: savedPlaces
                ) { draft in
                    await addItem(draft)
                }
            }
            .sheet(isPresented: $isPlacesPresented) {
                SavedPlacesView(savedPlaces: savedPlaces)
            }
            .sheet(item: $editingItem) { item in
                MemoryItemFormView(
                    title: "Edit Item",
                    saveTitle: "Done",
                    draft: MemoryItemDraft(item: item),
                    savedPlaces: savedPlaces
                ) { draft in
                    await updateItem(item, with: draft)
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

    private func addItem(_ draft: MemoryItemDraft) async {
        let repository = TacRepository(modelContext: modelContext)
        let place = Tac.displayPlace(specificPlace: draft.specificLocation, area: draft.area)
        let rawInput = "\(draft.objectName) is \(place)"
        let locationSnapshot = await locationSnapshot(for: draft)

        do {
            try repository.save(
                objectName: draft.objectName,
                place: place,
                specificPlace: draft.specificLocation,
                area: draft.area,
                rawInput: rawInput,
                tags: [Tac.iconTag(for: draft.iconName)],
                locationSnapshot: locationSnapshot
            )
        } catch {
            assertionFailure("Could not save item: \(error.localizedDescription)")
        }
    }

    private func updateItem(_ item: Tac, with draft: MemoryItemDraft) async {
        let place = Tac.displayPlace(specificPlace: draft.specificLocation, area: draft.area)
        let rawInput = "\(draft.objectName) is \(place)"
        let locationSnapshot = await locationSnapshot(for: draft)

        item.updateLocation(
            objectName: draft.objectName,
            place: place,
            specificPlace: draft.specificLocation,
            area: draft.area,
            rawInput: rawInput,
            tags: [Tac.iconTag(for: draft.iconName)],
            latitude: locationSnapshot?.latitude,
            longitude: locationSnapshot?.longitude,
            horizontalAccuracy: locationSnapshot?.horizontalAccuracy,
            namedPlace: locationSnapshot?.namedPlace
        )

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Could not update item: \(error.localizedDescription)")
        }
    }

    private func locationSnapshot(for draft: MemoryItemDraft) async -> TacLocationSnapshot? {
        switch draft.placeSelection {
        case .automatic:
            return await TacLocationService.shared.currentLocationSnapshot(namedPlaces: savedPlaces)
        case .none:
            return nil
        case .savedPlace(let normalizedName):
            guard let savedPlace = savedPlaces.first(where: { $0.normalizedName == normalizedName }) else {
                return nil
            }

            return TacLocationSnapshot(
                latitude: savedPlace.latitude,
                longitude: savedPlace.longitude,
                horizontalAccuracy: savedPlace.radiusMeters,
                namedPlace: savedPlace.name
            )
        }
    }
}

private struct MemoryItemFormView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let saveTitle: String
    let savedPlaces: [SavedPlace]
    let onSave: (MemoryItemDraft) async -> Void

    @State private var objectName: String
    @State private var specificLocation: String
    @State private var area: String
    @State private var selectedIconName: String
    @State private var placeSelection: MemoryPlaceSelection

    init(
        title: String,
        saveTitle: String,
        draft: MemoryItemDraft,
        savedPlaces: [SavedPlace],
        onSave: @escaping (MemoryItemDraft) async -> Void
    ) {
        self.title = title
        self.saveTitle = saveTitle
        self.savedPlaces = savedPlaces
        self.onSave = onSave
        _objectName = State(initialValue: draft.objectName)
        _specificLocation = State(initialValue: draft.specificLocation)
        _area = State(initialValue: draft.area ?? "")
        _selectedIconName = State(initialValue: draft.iconName)
        _placeSelection = State(initialValue: draft.placeSelection)
    }

    private var canSave: Bool {
        !objectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !specificLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var placeSelectionOptions: [MemoryPlaceSelectionOption] {
        [
            MemoryPlaceSelectionOption(title: "Automatic", iconName: "location.viewfinder", selection: .automatic),
            MemoryPlaceSelectionOption(title: "No saved place", iconName: "location.slash", selection: .none)
        ] + savedPlaces.map { place in
            MemoryPlaceSelectionOption(title: place.name, iconName: place.iconName, selection: .savedPlace(place.normalizedName))
        }
    }

    private var selectedPlaceOption: MemoryPlaceSelectionOption {
        placeSelectionOptions.first { $0.selection == placeSelection }
            ?? MemoryPlaceSelectionOption(title: "Saved place", iconName: "mappin.circle.fill", selection: placeSelection)
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

                    Picker(selection: $placeSelection) {
                        ForEach(placeSelectionOptions) { option in
                            Label(option.title, systemImage: option.iconName)
                                .tag(option.selection)
                        }
                    } label: {
                        Label(selectedPlaceOption.title, systemImage: selectedPlaceOption.iconName)
                    }
                    .pickerStyle(.menu)
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
                        Task {
                            await save()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func save() async {
        let draft = MemoryItemDraft(
            objectName: objectName.trimmingCharacters(in: .whitespacesAndNewlines),
            specificLocation: specificLocation.trimmingCharacters(in: .whitespacesAndNewlines),
            area: area.trimmingCharacters(in: .whitespacesAndNewlines),
            iconName: selectedIconName,
            placeSelection: placeSelection
        )

        await onSave(draft)
        dismiss()
    }
}

private struct MemoryItemDraft {
    let objectName: String
    let specificLocation: String
    let area: String?
    let iconName: String
    let placeSelection: MemoryPlaceSelection

    static let empty = MemoryItemDraft(
        objectName: "",
        specificLocation: "",
        area: "",
        iconName: MemoryIconOption.defaultOption.systemName,
        placeSelection: .automatic
    )

    init(
        objectName: String,
        specificLocation: String,
        area: String,
        iconName: String,
        placeSelection: MemoryPlaceSelection
    ) {
        self.objectName = objectName
        self.specificLocation = specificLocation
        self.area = area.isEmpty ? nil : area
        self.iconName = iconName
        self.placeSelection = placeSelection
    }

    init(item: Tac) {
        self.objectName = item.objectName
        self.specificLocation = item.specificPlace
        self.area = item.area
        self.iconName = item.savedIconName ?? MemoryIconOption.iconName(for: item)

        if let namedPlace = item.namedPlace {
            self.placeSelection = .savedPlace(SavedPlace.normalizeName(namedPlace))
        } else {
            self.placeSelection = .automatic
        }
    }
}

private enum MemoryPlaceSelection: Hashable {
    case automatic
    case none
    case savedPlace(String)
}

private struct MemoryPlaceSelectionOption: Identifiable {
    let title: String
    let iconName: String
    let selection: MemoryPlaceSelection

    var id: MemoryPlaceSelection { selection }
}

private struct SavedPlacesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let savedPlaces: [SavedPlace]

    @State private var placeName = "Home"
    @State private var address = ""
    @State private var radiusMeters = 150.0
    @State private var selectedIconName = SavedPlaceIconOption.iconName(for: "Home")
    @State private var source = SavedPlaceSource.currentLocation
    @State private var statusMessage: String?
    @State private var isSaving = false
    @State private var isIconManuallySelected = false

    private let suggestedPlaceNames = ["Home", "Work", "School", "Gym", "Shop", "Cafe", "Park", "Car", "Transit"]

    private var cleanedPlaceName: String {
        placeName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanedAddress: String {
        address.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !cleanedPlaceName.isEmpty && (source == .currentLocation || !cleanedAddress.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Place") {
                    if !TacLocationService.isUsageDescriptionConfigured {
                        Text("Location permission is not configured in the app target yet.")
                            .foregroundStyle(.secondary)
                    }

                    TextField("Place name", text: $placeName)
                        .textInputAutocapitalization(.words)
                        .onChange(of: placeName) { _, newValue in
                            guard !isIconManuallySelected else {
                                return
                            }

                            selectedIconName = SavedPlaceIconOption.iconName(for: newValue)
                        }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suggestedPlaceNames, id: \.self) { name in
                                Button {
                                    placeName = name
                                    selectedIconName = SavedPlaceIconOption.iconName(for: name)
                                    isIconManuallySelected = false
                                } label: {
                                    Label(name, systemImage: SavedPlaceIconOption.iconName(for: name))
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    Picker("Location source", selection: $source) {
                        ForEach(SavedPlaceSource.allCases) { source in
                            Label(source.title, systemImage: source.iconName)
                                .tag(source)
                        }
                    }
                    .pickerStyle(.segmented)

                    if source == .address {
                        TextField("Address", text: $address, axis: .vertical)
                            .lineLimit(2, reservesSpace: true)
                            .textInputAutocapitalization(.words)
                    }

                    Stepper("Radius: \(Int(radiusMeters)) m", value: $radiusMeters, in: 50...500, step: 25)

                    Button {
                        Task {
                            await savePlace()
                        }
                    } label: {
                        Label(source.saveTitle, systemImage: source.iconName)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving || !canSave)
                }

                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 12)], spacing: 12) {
                        ForEach(SavedPlaceIconOption.all) { option in
                            Button {
                                selectedIconName = option.systemName
                                isIconManuallySelected = true
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

                if let statusMessage {
                    Section {
                        Text(statusMessage)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Saved Places") {
                    if savedPlaces.isEmpty {
                        Text("No saved places yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(savedPlaces) { place in
                            HStack(spacing: 12) {
                                Image(systemName: place.iconName)
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.1))
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(place.name)
                                        .font(.headline)
                                    Text("Radius \(Int(place.radiusMeters)) m")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(place.updatedAt, style: .relative)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.tertiary)
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete(perform: deletePlaces)
                    }
                }
            }
            .navigationTitle("Saved Places")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await savePlace()
                        }
                    }
                    .disabled(isSaving || !canSave)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func savePlace() async {
        isSaving = true
        defer { isSaving = false }

        guard !cleanedPlaceName.isEmpty else {
            statusMessage = "Enter a place name."
            return
        }

        let resolvedCoordinate: CLLocationCoordinate2D

        switch source {
        case .currentLocation:
            TacLocationService.shared.requestPermissionIfNeeded()

            guard let snapshot = await TacLocationService.shared.currentLocationSnapshot(namedPlaces: []) else {
                statusMessage = "Location is unavailable. Check location permission and try again."
                return
            }

            resolvedCoordinate = CLLocationCoordinate2D(latitude: snapshot.latitude, longitude: snapshot.longitude)
        case .address:
            guard !cleanedAddress.isEmpty else {
                statusMessage = "Enter an address."
                return
            }

            guard let addressCoordinate = await coordinate(for: cleanedAddress) else {
                statusMessage = "I could not find that address."
                return
            }

            resolvedCoordinate = addressCoordinate
        }

        let normalizedName = SavedPlace.normalizeName(cleanedPlaceName)
        let existingPlace = savedPlaces.first { $0.normalizedName == normalizedName }

        if let existingPlace {
            existingPlace.update(
                name: cleanedPlaceName,
                latitude: resolvedCoordinate.latitude,
                longitude: resolvedCoordinate.longitude,
                radiusMeters: radiusMeters,
                iconName: selectedIconName
            )
        } else {
            let place = SavedPlace(
                name: cleanedPlaceName,
                latitude: resolvedCoordinate.latitude,
                longitude: resolvedCoordinate.longitude,
                radiusMeters: radiusMeters,
                iconName: selectedIconName
            )
            modelContext.insert(place)
        }

        do {
            try modelContext.save()
            statusMessage = "Saved \(cleanedPlaceName)."
            resetForm()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func resetForm() {
        placeName = ""
        address = ""
        selectedIconName = SavedPlaceIconOption.defaultOption.systemName
        isIconManuallySelected = false
    }

    private func coordinate(for address: String) async -> CLLocationCoordinate2D? {
        guard let request = MKGeocodingRequest(addressString: address) else {
            return nil
        }

        let mapItems = try? await request.mapItems
        return mapItems?.first?.location.coordinate
    }

    private func deletePlaces(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(savedPlaces[index])
            }

            try? modelContext.save()
        }
    }
}

private enum SavedPlaceSource: String, CaseIterable, Identifiable {
    case currentLocation
    case address

    var id: String { rawValue }

    var title: String {
        switch self {
        case .currentLocation:
            return "Current"
        case .address:
            return "Address"
        }
    }

    var saveTitle: String {
        switch self {
        case .currentLocation:
            return "Save Current Location"
        case .address:
            return "Save Address"
        }
    }

    var iconName: String {
        switch self {
        case .currentLocation:
            return "location.fill"
        case .address:
            return "map.fill"
        }
    }
}

private struct SavedPlaceIconOption: Identifiable {
    let title: String
    let systemName: String

    var id: String { systemName }

    static let defaultOption = SavedPlaceIconOption(title: "Place", systemName: "mappin.circle.fill")

    static let all = [
        SavedPlaceIconOption(title: "Place", systemName: "mappin.circle.fill"),
        SavedPlaceIconOption(title: "Home", systemName: "house.fill"),
        SavedPlaceIconOption(title: "Work", systemName: "building.2.fill"),
        SavedPlaceIconOption(title: "School", systemName: "graduationcap.fill"),
        SavedPlaceIconOption(title: "Gym", systemName: "figure.strengthtraining.traditional"),
        SavedPlaceIconOption(title: "Shop", systemName: "cart.fill"),
        SavedPlaceIconOption(title: "Cafe", systemName: "cup.and.saucer.fill"),
        SavedPlaceIconOption(title: "Park", systemName: "tree.fill"),
        SavedPlaceIconOption(title: "Car", systemName: "car.fill"),
        SavedPlaceIconOption(title: "Transit", systemName: "tram.fill")
    ]

    static func iconName(for placeName: String) -> String {
        let normalizedName = SavedPlace.normalizeName(placeName)

        if normalizedName.contains("home") || normalizedName.contains("house") || normalizedName.contains("apartment") {
            return "house.fill"
        } else if normalizedName.contains("work") || normalizedName.contains("office") || normalizedName.contains("studio") {
            return "building.2.fill"
        } else if normalizedName.contains("school") || normalizedName.contains("university") || normalizedName.contains("college") || normalizedName.contains("campus") {
            return "graduationcap.fill"
        } else if normalizedName.contains("gym") || normalizedName.contains("fitness") || normalizedName.contains("sport") {
            return "figure.strengthtraining.traditional"
        } else if normalizedName.contains("shop") || normalizedName.contains("store") || normalizedName.contains("market") || normalizedName.contains("mall") {
            return "cart.fill"
        } else if normalizedName.contains("cafe") || normalizedName.contains("coffee") || normalizedName.contains("restaurant") {
            return "cup.and.saucer.fill"
        } else if normalizedName.contains("park") || normalizedName.contains("garden") {
            return "tree.fill"
        } else if normalizedName.contains("car") || normalizedName.contains("parking") || normalizedName.contains("garage") {
            return "car.fill"
        } else if normalizedName.contains("transit") || normalizedName.contains("station") || normalizedName.contains("train") || normalizedName.contains("tram") || normalizedName.contains("metro") {
            return "tram.fill"
        }

        return defaultOption.systemName
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
        MemoryIconOption(title: "Watch", systemName: "applewatch"),
        MemoryIconOption(title: "Headphones", systemName: "headphones"),
        MemoryIconOption(title: "Passport", systemName: "person.text.rectangle.fill"),
        MemoryIconOption(title: "Umbrella", systemName: "umbrella.fill"),
        MemoryIconOption(title: "Pills", systemName: "pills.fill"),
        MemoryIconOption(title: "Gift", systemName: "gift.fill")
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
        } else if normalizedName.contains("headphone") || normalizedName.contains("earbud") {
            return "headphones"
        } else if normalizedName.contains("passport") || normalizedName.contains("id") {
            return "person.text.rectangle.fill"
        } else if normalizedName.contains("umbrella") {
            return "umbrella.fill"
        } else if normalizedName.contains("pill") || normalizedName.contains("medicine") {
            return "pills.fill"
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
    let savedPlaces: [SavedPlace]

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: iconName)
                .foregroundStyle(Color.accentColor)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 46, height: 46)
                .background {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                }

            VStack(alignment: .leading, spacing: 7) {
                Text(item.objectName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Label {
                    Text(item.place)
                        .lineLimit(2)
                } icon: {
                    Image(systemName: "mappin.and.ellipse")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)

                if let namedPlace = item.displayLocationContext {
                    Label(namedPlace, systemImage: namedPlaceIconName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background {
                            Capsule()
                                .fill(Color.accentColor.opacity(0.10))
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.updatedAt, style: .relative)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
                .monospacedDigit()
                .lineLimit(1)
                .frame(minWidth: 52, alignment: .trailing)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 6)
    }

    private var iconName: String {
        item.savedIconName ?? MemoryIconOption.iconName(for: item)
    }

    private var namedPlaceIconName: String {
        guard let namedPlace = item.namedPlace else {
            return "location.fill"
        }

        let normalizedName = SavedPlace.normalizeName(namedPlace)
        return savedPlaces.first { $0.normalizedName == normalizedName }?.iconName
            ?? SavedPlaceIconOption.iconName(for: namedPlace)
    }
}
