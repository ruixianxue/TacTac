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
        tags: [String] = [],
        locationSnapshot: TacLocationSnapshot? = nil
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
                tags: tags,
                latitude: locationSnapshot?.latitude,
                longitude: locationSnapshot?.longitude,
                horizontalAccuracy: locationSnapshot?.horizontalAccuracy,
                namedPlace: locationSnapshot?.namedPlace
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
            tags: tags,
            latitude: locationSnapshot?.latitude,
            longitude: locationSnapshot?.longitude,
            horizontalAccuracy: locationSnapshot?.horizontalAccuracy,
            namedPlace: locationSnapshot?.namedPlace
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

    func fetchSavedPlaces() throws -> [SavedPlace] {
        let descriptor = FetchDescriptor<SavedPlace>(
            sortBy: [SortDescriptor(\.name)]
        )

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

        let queryTokens = canonicalTokens(for: normalizedQuery)

        return records.first { tac in
            let itemTokens = canonicalTokens(for: normalizedName(for: tac))
            let tagTokens = aliasTokens(for: tac)
            let searchableTokens = itemTokens.union(tagTokens)

            guard !queryTokens.isEmpty, !searchableTokens.isEmpty else {
                return false
            }

            if queryTokens == itemTokens || tagTokens.contains(where: { $0 == normalizedQuery }) {
                return true
            }

            if queryTokens.isSubset(of: searchableTokens) && searchableTokens.count > queryTokens.count {
                let extraSearchableTokens = searchableTokens.subtracting(queryTokens)
                return !containsDistinguishingToken(extraSearchableTokens)
            }

            return false
        }
    }

    func isPlausibleSemanticMatch(query: String, candidate: Tac) -> Bool {
        let normalizedQuery = Tac.normalizeObjectName(query)
        let queryTokens = canonicalTokens(for: normalizedQuery)
        let itemTokens = canonicalTokens(for: normalizedName(for: candidate))
        let tagTokens = aliasTokens(for: candidate)
        let searchableTokens = itemTokens.union(tagTokens)

        return isPlausibleMatch(
            queryTokens: queryTokens,
            itemTokens: itemTokens,
            searchableTokens: searchableTokens,
            normalizedQuery: normalizedQuery,
            tagTokens: tagTokens
        )
    }

    func findRelatedMatch(for objectName: String, candidates: [Tac]) -> Tac? {
        let normalizedQuery = Tac.normalizeObjectName(objectName)
        let queryTokens = canonicalTokens(for: normalizedQuery)
        let matches = candidates.filter { tac in
            let itemTokens = canonicalTokens(for: normalizedName(for: tac))
            let tagTokens = aliasTokens(for: tac)
            let searchableTokens = itemTokens.union(tagTokens)

            return isPlausibleMatch(
                queryTokens: queryTokens,
                itemTokens: itemTokens,
                searchableTokens: searchableTokens,
                normalizedQuery: normalizedQuery,
                tagTokens: tagTokens
            )
        }

        return matches.count == 1 ? matches[0] : nil
    }

    private func isPlausibleMatch(
        queryTokens: Set<String>,
        itemTokens: Set<String>,
        searchableTokens: Set<String>,
        normalizedQuery: String,
        tagTokens: Set<String>
    ) -> Bool {
        guard !queryTokens.isEmpty, !searchableTokens.isEmpty else {
            return false
        }

        if queryTokens == itemTokens || tagTokens.contains(where: { $0 == normalizedQuery }) {
            return true
        }

        if queryTokens.isSubset(of: searchableTokens) && searchableTokens.count > queryTokens.count {
            let extraSearchableTokens = searchableTokens.subtracting(queryTokens)
            return !containsDistinguishingToken(extraSearchableTokens)
        }

        if itemTokens.isSubset(of: queryTokens) && queryTokens.count > itemTokens.count {
            let extraQueryTokens = queryTokens.subtracting(itemTokens)
            return !containsDistinguishingToken(extraQueryTokens)
                && extraQueryTokens.allSatisfy { extraToken in
                    itemTokens.contains { itemToken in
                        areRelatedTokens(extraToken, itemToken)
                    }
                }
        }

        guard !containsDistinguishingToken(queryTokens.subtracting(itemTokens)),
              !containsDistinguishingToken(itemTokens.subtracting(queryTokens)) else {
            return false
        }

        return queryTokens.contains { queryToken in
            searchableTokens.contains { itemToken in
                areRelatedTokens(queryToken, itemToken)
            }
        }
    }

    private func findEquivalentMatch(forNormalizedObjectName normalizedObjectName: String) throws -> Tac? {
        let queryTokens = canonicalTokens(for: normalizedObjectName)

        return try fetchRecent().first { tac in
            let itemTokens = canonicalTokens(for: normalizedName(for: tac))

            if normalizedName(for: tac) == normalizedObjectName || queryTokens == itemTokens {
                return true
            }

            if queryTokens.isSubset(of: itemTokens) && itemTokens.count > queryTokens.count {
                let extraItemTokens = itemTokens.subtracting(queryTokens)
                return !containsDistinguishingToken(extraItemTokens)
            }

            return false
        }
    }

    private func normalizedName(for tac: Tac) -> String {
        if tac.normalizedObjectName.isEmpty {
            return Tac.normalizeObjectName(tac.objectName)
        }

        return tac.normalizedObjectName
    }

    private func aliasTokens(for tac: Tac) -> Set<String> {
        tac.tags.reduce(into: Set<String>()) { tokens, tag in
            guard !tag.hasPrefix("icon:") else {
                return
            }

            tokens.formUnion(canonicalTokens(for: Tac.normalizeObjectName(tag)))
        }
    }

    private func canonicalTokens(for normalizedValue: String) -> Set<String> {
        let tokens = normalizedValue
            .split(separator: " ")
            .map(String.init)
            .filter { !ignoredTokenValues.contains($0) }

        return Set(tokens.map(canonicalToken))
    }

    private var ignoredTokenValues: Set<String> {
        ["s"]
    }

    private func areRelatedTokens(_ lhs: String, _ rhs: String) -> Bool {
        lhs == rhs || relatedTokenGroup(for: lhs) == relatedTokenGroup(for: rhs)
    }

    private func containsDistinguishingToken(_ tokens: Set<String>) -> Bool {
        !tokens.isDisjoint(with: distinguishingTokenValues)
    }

    private var distinguishingTokenValues: Set<String> {
        [
            "boyfriend",
            "girlfriend",
            "husband",
            "wife",
            "partner",
            "mother",
            "mom",
            "father",
            "dad",
            "brother",
            "sister",
            "son",
            "daughter",
            "friend",
            "roommate"
        ]
    }

    private func relatedTokenGroup(for token: String) -> String {
        switch token {
        case "glass", "sunglass", "eyeglass":
            return "eyewear"
        case "phone", "iphone", "mobile", "cell":
            return "phone"
        case "laptop", "computer", "macbook":
            return "computer"
        case "backpack", "bag", "purse":
            return "bag"
        case "airpod", "earbud", "headphone":
            return "headphones"
        case "remote", "controller":
            return "remote"
        default:
            return token
        }
    }

    private func canonicalToken(_ token: String) -> String {
        if token.hasSuffix("ies"), token.count > 3 {
            return String(token.dropLast(3)) + "y"
        } else if token.hasSuffix("es"), token.count > 3 {
            return String(token.dropLast(2))
        } else if token.hasSuffix("s"), token.count > 3 {
            return String(token.dropLast())
        }

        return token
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
