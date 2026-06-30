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
        let normalizedObjectName = Tac.normalizeObjectName(objectName)

        guard !normalizedObjectName.isEmpty else {
            throw TacRepositoryError.emptyObjectName
        }

        if let existingTac = try findExactMatch(forNormalizedObjectName: normalizedObjectName) {
            existingTac.updateLocation(
                objectName: objectName,
                place: place,
                rawInput: rawInput,
                confidence: confidence,
                tags: tags
            )
            try modelContext.save()
            return existingTac
        }

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
        let normalizedQuery = Tac.normalizeObjectName(objectName)
        let queryTokens = Set(normalizedQuery.split(separator: " ").map(String.init))

        guard !normalizedQuery.isEmpty else {
            return nil
        }

        let records = try fetchRecent()

        if let exactMatch = records.first(where: { tac in
            normalizedName(for: tac) == normalizedQuery
                || tac.tags.map(Tac.normalizeObjectName).contains(normalizedQuery)
        }) {
            return exactMatch
        }

        return records.first { tac in
            let objectTokens = Set(normalizedName(for: tac).split(separator: " ").map(String.init))
            let tagTokens = Set(tac.tags.flatMap {
                Tac.normalizeObjectName($0).split(separator: " ").map(String.init)
            })
            let searchableTokens = objectTokens.union(tagTokens)

            guard !queryTokens.isEmpty, !searchableTokens.isEmpty else {
                return false
            }

            return queryTokens.isSubset(of: searchableTokens)
                || searchableTokens.isSubset(of: queryTokens)
        }
    }

    private func findExactMatch(forNormalizedObjectName normalizedObjectName: String) throws -> Tac? {
        try fetchRecent().first { tac in
            normalizedName(for: tac) == normalizedObjectName
        }
    }

    private func normalizedName(for tac: Tac) -> String {
        if tac.normalizedObjectName.isEmpty {
            return Tac.normalizeObjectName(tac.objectName)
        }

        return tac.normalizedObjectName
    }
}

enum TacRepositoryError: LocalizedError {
    case emptyObjectName

    var errorDescription: String? {
        switch self {
        case .emptyObjectName:
            return "The item name was empty."
        }
    }
}
