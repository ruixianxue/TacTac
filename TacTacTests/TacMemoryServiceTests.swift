import Foundation
import SwiftData
import Testing
@testable import TacTac

@MainActor
struct TacMemoryServiceTests {
    @Test
    func rememberSavesExtractedLocation() async throws {
        let harness = try MemoryServiceHarness()
        harness.nlp.extractions["my keys are on the chair in my room"] = TacExtraction(
            objectName: "keys",
            place: "on the chair in my room",
            specificPlace: "chair",
            area: "my room"
        )

        let tac = try await harness.service.remember(input: "my keys are on the chair in my room")
        let records = try harness.repository.fetchRecent()

        #expect(tac.objectName == "keys")
        #expect(tac.place == "on the chair in my room")
        #expect(tac.specificPlace == "chair")
        #expect(tac.area == "my room")
        #expect(records.count == 1)
    }

    @Test
    func rememberUpdatesExistingItem() async throws {
        let harness = try MemoryServiceHarness()
        harness.nlp.extractions["my keys are on the chair"] = TacExtraction(
            objectName: "keys",
            place: "on the chair",
            specificPlace: "chair",
            area: nil
        )
        harness.nlp.extractions["my keys are in the kitchen drawer"] = TacExtraction(
            objectName: "keys",
            place: "in the kitchen drawer",
            specificPlace: "kitchen drawer",
            area: nil
        )

        _ = try await harness.service.remember(input: "my keys are on the chair")
        let updatedTac = try await harness.service.remember(input: "my keys are in the kitchen drawer")
        let records = try harness.repository.fetchRecent()

        #expect(records.count == 1)
        #expect(updatedTac.place == "in the kitchen drawer")
        #expect(records.first?.place == "in the kitchen drawer")
    }

    @Test
    func rememberStoresCurrentNamedPlace() async throws {
        let harness = try MemoryServiceHarness()
        harness.nlp.extractions["my keys are on the desk"] = TacExtraction(
            objectName: "keys",
            place: "on the desk",
            specificPlace: "desk",
            area: nil
        )
        harness.location.snapshot = TacLocationSnapshot(
            latitude: 48.8566,
            longitude: 2.3522,
            horizontalAccuracy: 12,
            namedPlace: "Home"
        )

        let tac = try await harness.service.remember(input: "my keys are on the desk")

        #expect(tac.namedPlace == "Home")
        #expect(tac.latitude == 48.8566)
        #expect(tac.longitude == 2.3522)
        #expect(tac.answerPlace == "on the desk at Home")
    }

    @Test
    func findIncludesNamedPlaceWhenAreaWasNotSpecified() async throws {
        let harness = try MemoryServiceHarness()
        _ = try harness.repository.save(
            objectName: "keys",
            place: "on the desk",
            specificPlace: "desk",
            area: nil,
            rawInput: "my keys are on the desk",
            locationSnapshot: TacLocationSnapshot(
                latitude: 48.8566,
                longitude: 2.3522,
                horizontalAccuracy: 12,
                namedPlace: "Home"
            )
        )
        harness.nlp.objectNames["where are my keys?"] = "keys"

        let answer = try await harness.service.find(query: "where are my keys?")

        #expect(answer == "keys: on the desk at Home")
    }

    @Test
    func findUsesLocalMatchBeforeSemanticFallback() async throws {
        let harness = try MemoryServiceHarness()
        _ = try harness.repository.save(
            objectName: "keys",
            place: "on the chair in my room",
            specificPlace: "chair",
            area: "my room",
            rawInput: "my keys are on the chair in my room"
        )
        harness.nlp.objectNames["where are my keys?"] = "keys"

        let answer = try await harness.service.find(query: "where are my keys?")

        #expect(answer == "keys: on the chair in my room")
        #expect(harness.nlp.chooseBestTacCallCount == 0)
    }

    @Test
    func findReturnsMissingLocationMessage() async throws {
        let harness = try MemoryServiceHarness()
        harness.nlp.objectNames["where is my wallet?"] = "wallet"

        let answer = try await harness.service.find(query: "where is my wallet?")

        #expect(answer == "I could not find a saved location for wallet. You can save it by telling me where it is.")
        #expect(harness.nlp.chooseBestTacCallCount == 1)
    }

    @Test
    func findDoesNotMatchLongerQueryToGenericSavedItem() async throws {
        let harness = try MemoryServiceHarness()
        _ = try harness.repository.save(
            objectName: "keys",
            place: "on the entry table",
            specificPlace: "entry table",
            rawInput: "my keys are on the entry table"
        )
        harness.nlp.objectNames["where are my boyfriend's keys?"] = "boyfriend's keys"

        let answer = try await harness.service.find(query: "where are my boyfriend's keys?")

        #expect(answer == "I could not find a saved location for boyfriend's keys. You can save it by telling me where it is.")
        #expect(harness.nlp.chooseBestTacCallCount == 1)
    }

    @Test
    func rememberKeepsSimilarItemNamesSeparate() async throws {
        let harness = try MemoryServiceHarness()
        harness.nlp.extractions["my keys are on the entry table"] = TacExtraction(
            objectName: "keys",
            place: "on the entry table",
            specificPlace: "entry table",
            area: nil
        )
        harness.nlp.extractions["my boyfriend's keys are in the blue bowl"] = TacExtraction(
            objectName: "boyfriend's keys",
            place: "in the blue bowl",
            specificPlace: "blue bowl",
            area: nil
        )

        _ = try await harness.service.remember(input: "my keys are on the entry table")
        _ = try await harness.service.remember(input: "my boyfriend's keys are in the blue bowl")
        let records = try harness.repository.fetchRecent()

        #expect(records.count == 2)
    }

    @Test
    func findMatchesSingularAndPluralItemNames() async throws {
        let harness = try MemoryServiceHarness()
        _ = try harness.repository.save(
            objectName: "keys",
            place: "on the entry table",
            specificPlace: "entry table",
            rawInput: "my keys are on the entry table"
        )
        harness.nlp.objectNames["where is my key?"] = "key"

        let answer = try await harness.service.find(query: "where is my key?")

        #expect(answer == "keys: on the entry table")
        #expect(harness.nlp.chooseBestTacCallCount == 0)
    }

    @Test
    func findMatchesPartialItemName() async throws {
        let harness = try MemoryServiceHarness()
        _ = try harness.repository.save(
            objectName: "phone charger",
            place: "inside the backpack",
            specificPlace: "backpack",
            rawInput: "my phone charger is inside the backpack"
        )
        harness.nlp.objectNames["where is my charger?"] = "charger"

        let answer = try await harness.service.find(query: "where is my charger?")

        #expect(answer == "phone charger: inside the backpack")
        #expect(harness.nlp.chooseBestTacCallCount == 0)
    }

    @Test
    func rememberUpdatesPluralEquivalentItem() async throws {
        let harness = try MemoryServiceHarness()
        harness.nlp.extractions["my keys are on the entry table"] = TacExtraction(
            objectName: "keys",
            place: "on the entry table",
            specificPlace: "entry table",
            area: nil
        )
        harness.nlp.extractions["my key is in my jacket"] = TacExtraction(
            objectName: "key",
            place: "in my jacket",
            specificPlace: "jacket",
            area: nil
        )

        _ = try await harness.service.remember(input: "my keys are on the entry table")
        _ = try await harness.service.remember(input: "my key is in my jacket")
        let records = try harness.repository.fetchRecent()

        #expect(records.count == 1)
        #expect(records.first?.objectName == "key")
        #expect(records.first?.place == "in my jacket")
    }

    @Test
    func findRejectsUnrelatedSemanticFallbackMatch() async throws {
        let harness = try MemoryServiceHarness()
        let savedTac = try harness.repository.save(
            objectName: "keys",
            place: "on the entry table",
            specificPlace: "entry table",
            rawInput: "my keys are on the entry table"
        )
        harness.nlp.objectNames["where is my wallet?"] = "wallet"
        harness.nlp.semanticMatch = savedTac

        let answer = try await harness.service.find(query: "where is my wallet?")

        #expect(answer == "I could not find a saved location for wallet. You can save it by telling me where it is.")
        #expect(harness.nlp.chooseBestTacCallCount == 1)
    }

    @Test
    func findMatchesRelatedItemNamesLocally() async throws {
        let harness = try MemoryServiceHarness()
        _ = try harness.repository.save(
            objectName: "sunglasses",
            place: "on the desk",
            specificPlace: "desk",
            rawInput: "my sunglasses are on the desk"
        )
        harness.nlp.objectNames["where are my glasses?"] = "glasses"

        let answer = try await harness.service.find(query: "where are my glasses?")

        #expect(answer == "Possibly: sunglasses: on the desk")
        #expect(harness.nlp.chooseBestTacCallCount == 0)
    }

    @Test
    func findDoesNotMatchGenericQueryToOwnedSavedItem() async throws {
        let harness = try MemoryServiceHarness()
        _ = try harness.repository.save(
            objectName: "boyfriend's keys",
            place: "in the blue bowl",
            specificPlace: "blue bowl",
            rawInput: "my boyfriend's keys are in the blue bowl"
        )
        harness.nlp.objectNames["where are my keys?"] = "keys"

        let answer = try await harness.service.find(query: "where are my keys?")

        #expect(answer == "I could not find a saved location for keys. You can save it by telling me where it is.")
        #expect(harness.nlp.chooseBestTacCallCount == 1)
    }
}

@MainActor
private final class MemoryServiceHarness {
    let container: ModelContainer
    let repository: TacRepository
    let nlp: FakeNLPService
    let location: FakeLocationProvider
    let service: TacMemoryService

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Tac.self, SavedPlace.self, configurations: configuration)
        repository = TacRepository(modelContext: ModelContext(container))
        nlp = FakeNLPService()
        location = FakeLocationProvider()
        service = TacMemoryService(repository: repository, nlpService: nlp, locationProvider: location)
    }
}

@MainActor
private final class FakeLocationProvider: TacLocationProviding {
    var snapshot: TacLocationSnapshot?
    var requestPermissionCallCount = 0

    func requestPermissionIfNeeded() {
        requestPermissionCallCount += 1
    }

    func currentLocationSnapshot(namedPlaces: [SavedPlace]) async -> TacLocationSnapshot? {
        snapshot
    }
}

@MainActor
private final class FakeNLPService: TacNLPServicing {
    var extractions: [String: TacExtraction] = [:]
    var objectNames: [String: String] = [:]
    var semanticMatch: Tac?
    var chooseBestTacCallCount = 0

    func extractTac(from input: String) async throws -> TacExtraction {
        guard let extraction = extractions[input] else {
            throw NLPServiceError.couldNotExtractPlacement
        }

        return extraction
    }

    func extractObjectName(from input: String) async throws -> String {
        guard let objectName = objectNames[input] else {
            throw NLPServiceError.couldNotExtractObject
        }

        return objectName
    }

    func chooseBestTac(query: String, candidates: [Tac]) async throws -> Tac? {
        chooseBestTacCallCount += 1
        return semanticMatch
    }

    func generateAnswer(objectName: String, place: String, createdAt: Date) async throws -> String {
        "\(objectName): \(place)"
    }
}
