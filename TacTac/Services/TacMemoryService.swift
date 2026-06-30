import Foundation

@MainActor
final class TacMemoryService {
    private let repository: TacRepository
    private let nlpService: NLPService

    init(repository: TacRepository, nlpService: NLPService? = nil) {
        self.repository = repository
        self.nlpService = nlpService ?? .shared
    }

    @discardableResult
    func remember(input: String) async throws -> Tac {
        let extracted = try await nlpService.extractTac(from: input)

        return try repository.save(
            objectName: extracted.objectName,
            place: extracted.place,
            rawInput: input
        )
    }

    func find(query: String) async throws -> String {
        let objectName = try await nlpService.extractObjectName(from: query)

        if let localMatch = try repository.findBestLocalMatch(for: objectName) {
            return try await nlpService.generateAnswer(
                objectName: localMatch.objectName,
                place: localMatch.place,
                createdAt: localMatch.updatedAt
            )
        }

        let candidates = try repository.fetchRecent(limit: 20)

        guard let semanticMatch = try await nlpService.chooseBestTac(
            query: objectName,
            candidates: candidates
        ) else {
            return "I do not have a saved location for \(objectName) yet."
        }

        let answer = try await nlpService.generateAnswer(
            objectName: semanticMatch.objectName,
            place: semanticMatch.place,
            createdAt: semanticMatch.updatedAt
        )

        return "Possibly: \(answer)"
    }
}
