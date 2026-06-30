import Foundation
import SwiftData

@MainActor
final class TacRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @discardableResult
    func save(
        objectName: String,
        place: String,
        rawInput: String,
        confidence: Double = 1.0,
        tags: [String] = []
    ) throws -> Tac {
        let tac = Tac(
            objectName: objectName,
            place: place,
            rawInput: rawInput,
            confidence: confidence,
            tags: tags
        )

        modelContext.insert(tac)
        try modelContext.save()
        return tac
    }

    func fetchRecent(limit: Int? = nil) throws -> [Tac] {
        var descriptor = FetchDescriptor<Tac>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        if let limit {
            descriptor.fetchLimit = limit
        }

        return try modelContext.fetch(descriptor)
    }

    func findBestLocalMatch(for objectName: String) throws -> Tac? {
        let normalizedQuery = normalize(objectName)

        guard !normalizedQuery.isEmpty else {
            return nil
        }

        let records = try fetchRecent()

        return records.first { tac in
            let normalizedObject = normalize(tac.objectName)
            let normalizedTags = tac.tags.map(normalize)

            return normalizedObject == normalizedQuery
                || normalizedObject.contains(normalizedQuery)
                || normalizedQuery.contains(normalizedObject)
                || normalizedTags.contains(normalizedQuery)
        }
    }

    private func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
