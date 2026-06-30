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
        specificPlace: String? = nil,
        area: String? = nil,
        rawInput: String,
        confidence: Double = 1.0,
        tags: [String] = []
    ) throws -> Tac {
        let normalizedObjectName = Tac.normalizeObjectName(objectName)

        guard !normalizedObjectName.isEmpty else {
            throw TacRepositoryError.emptyObjectName
        }

        if let existingTac = try findEquivalentMatch(forNormalizedObjectName: normalizedObjectName) {
            existingTac.updateLocation(
                objectName: objectName,
                place: place,
                specificPlace: specificPlace,
                area: area,
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
            specificPlace: specificPlace,
            area: area,
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

        let queryTokens = expandedTokens(for: normalizedQuery)

        return records.first { tac in
            let searchableTokens = searchableTokens(for: tac)

            guard !queryTokens.isEmpty, !searchableTokens.isEmpty else {
                return false
            }

            return queryTokens.isSubset(of: searchableTokens)
                || searchableTokens.isSubset(of: queryTokens)
        }
    }

    private func findEquivalentMatch(forNormalizedObjectName normalizedObjectName: String) throws -> Tac? {
        let queryTokens = expandedTokens(for: normalizedObjectName)

        return try fetchRecent().first { tac in
            normalizedName(for: tac) == normalizedObjectName
                || expandedTokens(for: normalizedName(for: tac)).isSubset(of: queryTokens)
                || queryTokens.isSubset(of: expandedTokens(for: normalizedName(for: tac)))
        }
    }

    private func normalizedName(for tac: Tac) -> String {
        if tac.normalizedObjectName.isEmpty {
            return Tac.normalizeObjectName(tac.objectName)
        }

        return tac.normalizedObjectName
    }

    private func searchableTokens(for tac: Tac) -> Set<String> {
        let objectTokens = expandedTokens(for: normalizedName(for: tac))
        let tagTokens = tac.tags.reduce(into: Set<String>()) { tokens, tag in
            tokens.formUnion(expandedTokens(for: Tac.normalizeObjectName(tag)))
        }

        return objectTokens.union(tagTokens)
    }

    private func expandedTokens(for normalizedValue: String) -> Set<String> {
        let tokens = normalizedValue.split(separator: " ").map(String.init)

        return tokens.reduce(into: Set<String>()) { result, token in
            result.formUnion(tokenVariants(for: token))
        }
    }

    private func tokenVariants(for token: String) -> Set<String> {
        var variants: Set<String> = [token]

        if token.hasSuffix("ies"), token.count > 3 {
            variants.insert(String(token.dropLast(3)) + "y")
        } else if token.hasSuffix("es"), token.count > 3 {
            variants.insert(String(token.dropLast(2)))
        } else if token.hasSuffix("s"), token.count > 3 {
            variants.insert(String(token.dropLast()))
        }

        return variants
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
