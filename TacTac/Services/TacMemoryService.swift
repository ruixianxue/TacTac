import Foundation

@MainActor
final class TacMemoryService {
    private let repository: TacRepository
    private let nlpService: any TacNLPServicing
    private let locationProvider: (any TacLocationProviding)?

    init(repository: TacRepository, nlpService: (any TacNLPServicing)? = nil) {
        self.repository = repository
        self.nlpService = nlpService ?? NLPService.shared
        self.locationProvider = TacLocationService.shared
    }

    init(
        repository: TacRepository,
        nlpService: (any TacNLPServicing)? = nil,
        locationProvider: (any TacLocationProviding)?
    ) {
        self.repository = repository
        self.nlpService = nlpService ?? NLPService.shared
        self.locationProvider = locationProvider
    }

    @discardableResult
    func remember(input: String) async throws -> Tac {
        let extracted = try await nlpService.extractTac(from: input)
        let savedPlaces = try repository.fetchSavedPlaces()
        let locationSnapshot = await locationProvider?.currentLocationSnapshot(namedPlaces: savedPlaces)

        return try repository.save(
            objectName: extracted.objectName,
            place: extracted.place,
            specificPlace: extracted.specificPlace,
            area: extracted.area,
            rawInput: input,
            locationSnapshot: locationSnapshot
        )
    }

    func find(query: String) async throws -> String {
        let objectName = try await nlpService.extractObjectName(from: query)

        if let localMatch = try repository.findBestLocalMatch(for: objectName) {
            return try await nlpService.generateAnswer(
                objectName: localMatch.objectName,
                place: localMatch.answerPlace,
                createdAt: localMatch.updatedAt
            )
        }

        let candidates = try repository.fetchRecent(limit: 20)

        if let relatedMatch = repository.findRelatedMatch(for: objectName, candidates: candidates) {
            let answer = try await nlpService.generateAnswer(
                objectName: relatedMatch.objectName,
                place: relatedMatch.place,
                createdAt: relatedMatch.updatedAt
            )
            return "Possibly: \(answer)"
        }

        guard let semanticMatch = try await nlpService.chooseBestTac(
            query: objectName,
            candidates: candidates
        ), repository.isPlausibleSemanticMatch(query: objectName, candidate: semanticMatch) else {
            return "I could not find a saved location for \(objectName). You can save it by telling me where it is."
        }

        let answer = try await nlpService.generateAnswer(
            objectName: semanticMatch.objectName,
            place: semanticMatch.place,
            createdAt: semanticMatch.updatedAt
        )

        return "Possibly: \(answer)"
    }
}
