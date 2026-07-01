import Foundation
import FoundationModels

struct TacExtraction: Equatable {
    let objectName: String
    let place: String
    let specificPlace: String
    let area: String?
}

@Generable(description: "A structured item location extracted from a user's sentence")
private struct TacPlacementOutput {
    @Guide(description: "The item name, one to four words. Empty when missing or uncertain.")
    var objectName: String

    @Guide(description: "The exact spot, surface, or container. Empty when missing or uncertain.")
    var specificPlace: String

    @Guide(description: "The broader room, building, or area. Empty when not stated.")
    var area: String

    @Guide(description: "The full useful location with prepositions, combining exact spot and broader area.")
    var place: String
}

@Generable(description: "The item a user wants to find")
private struct ObjectQueryOutput {
    @Guide(description: "The item name, one to four words. Empty when missing or uncertain.")
    var objectName: String
}

@Generable(description: "The selected saved location candidate")
private struct TacMatchOutput {
    @Guide(description: "Best matching record index, or -1 when none likely match.")
    var index: Int
}

@MainActor
protocol TacNLPServicing {
    func extractTac(from input: String) async throws -> TacExtraction
    func extractObjectName(from input: String) async throws -> String
    func chooseBestTac(query: String, candidates: [Tac]) async throws -> Tac?
    func generateAnswer(objectName: String, place: String, createdAt: Date) async throws -> String
}

@MainActor
final class NLPService: TacNLPServicing {
    static let shared = NLPService()

    func extractTac(from input: String) async throws -> TacExtraction {
        if let fallbackExtraction = ruleBasedTacExtraction(from: input) {
            return fallbackExtraction
        }

        do {
            let session = try makeSession()
            let prompt = """
            Extract where the user placed an item.
            Preserve important prepositions in the final place, such as "on the chair" or "inside the backpack".
            If the item or exact spot is missing or uncertain, leave that field empty.

            User said:
            \"\"\"
            \(input)
            \"\"\"
            """

            let response = try await session.respond(to: prompt, generating: TacPlacementOutput.self)
            let output = response.content

            guard let objectName = cleanedObjectName(output.objectName),
                  let specificPlace = cleanedRequiredField(output.specificPlace) else {
                throw NLPServiceError.couldNotExtractPlacement
            }

            let area = cleanedOptionalField(output.area).map(secondPersonPossessives)
            let place = cleanedRequiredField(output.place)
                .map(secondPersonPossessives)
                ?? Tac.displayPlace(specificPlace: specificPlace, area: area)

            return TacExtraction(
                objectName: objectName,
                place: place,
                specificPlace: secondPersonPossessives(specificPlace),
                area: area
            )
        } catch {
            if let fallbackExtraction = ruleBasedTacExtraction(from: input) {
                return fallbackExtraction
            }

            throw error
        }
    }

    func extractObjectName(from input: String) async throws -> String {
        if let fallbackObjectName = ruleBasedObjectName(from: input) {
            return fallbackObjectName
        }

        do {
            let session = try makeSession()
            let prompt = """
            Extract only the item the user is trying to find.
            If no item is stated or the item is uncertain, leave the field empty.

            User asked:
            \"\"\"
            \(input)
            \"\"\"
            """

            let response = try await session.respond(to: prompt, generating: ObjectQueryOutput.self)

            guard let objectName = cleanedObjectName(response.content.objectName) else {
                throw NLPServiceError.couldNotExtractObject
            }

            return objectName
        } catch {
            if let fallbackObjectName = ruleBasedObjectName(from: input) {
                return fallbackObjectName
            }

            throw error
        }
    }

    func chooseBestTac(query: String, candidates: [Tac]) async throws -> Tac? {
        guard !candidates.isEmpty else {
            return nil
        }

        do {
            let session = try makeSession()
            let candidateList = candidates.enumerated()
                .map { index, tac in
                    "\(index): object=\(tac.objectName), specificPlace=\(tac.specificPlace), area=\(tac.area ?? ""), place=\(tac.place), tags=\(tac.tags.joined(separator: ","))"
                }
                .joined(separator: "\n")

            let prompt = """
            Match the user's item query to saved object-location records.
            Choose the best index only when it is likely the same item or a closely related item.
            Do not ignore ownership or distinguishing modifiers: "boyfriend keys" should not match plain "keys" unless a record also mentions boyfriend.
            Use -1 when no record likely matches.

            Query: \(query)
            Records:
            \(candidateList)
            """

            let response = try await session.respond(to: prompt, generating: TacMatchOutput.self)
            let index = response.content.index

            guard candidates.indices.contains(index) else {
                return nil
            }

            return candidates[index]
        } catch {
            return nil
        }
    }

    func generateAnswer(objectName: String, place: String, createdAt: Date) async throws -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "en_US")
        let timeAgo = formatter.localizedString(for: createdAt, relativeTo: Date())

        do {
            let session = try makeSession()
            let prompt = """
            Answer in one short natural sentence in English.
            Refer to the item and location as belonging to the user, using "your" instead of "my".
            Item: \(objectName)
            Location: \(secondPersonPossessives(place))
            Stored: \(timeAgo)

            Example: "Your keys are at your front door, stored 3 hours ago."
            Output only that one sentence.
            """

            let response = try await session.respond(to: prompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return "Your \(objectName) is \(secondPersonPossessives(place)), stored \(timeAgo)."
        }
    }

    private func secondPersonPossessives(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"\b[Mm]y\b"#, with: "your", options: .regularExpression)
            .replacingOccurrences(of: #"\b[Mm]ine\b"#, with: "yours", options: .regularExpression)
    }

    private func makeSession() throws -> LanguageModelSession {
        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            return LanguageModelSession(model: model)
        case .unavailable(let reason):
            throw NLPServiceError.modelUnavailable(modelUnavailableMessage(for: reason))
        }
    }

    private func modelUnavailableMessage(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device does not support Apple Intelligence, so TacTac cannot understand new Siri requests here."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is turned off. Turn it on in Settings to let TacTac understand Siri requests."
        case .modelNotReady:
            return "Apple Intelligence is still getting ready. Try again after the model finishes downloading."
        @unknown default:
            return "Apple Intelligence is unavailable right now. Try again later."
        }
    }

    private func ruleBasedTacExtraction(from input: String) -> TacExtraction? {
        let cleanedInput = cleanedSentence(input)
        let verbSeparators = [" are ", " is ", " was ", " were "]

        for separator in verbSeparators {
            guard let separatorRange = cleanedInput.range(of: separator) else {
                continue
            }

            let objectName = cleanedObjectName(String(cleanedInput[..<separatorRange.lowerBound]))
            let place = String(cleanedInput[separatorRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)

            if let extraction = makeRuleBasedExtraction(objectName: objectName, place: place, rawPlaceIncludesPreposition: true) {
                return extraction
            }
        }

        for preposition in locationPrepositions {
            guard let prepositionRange = cleanedInput.range(of: " \(preposition) ") else {
                continue
            }

            let objectName = cleanedObjectName(String(cleanedInput[..<prepositionRange.lowerBound]))
            let place = String(cleanedInput[prepositionRange.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)

            if let extraction = makeRuleBasedExtraction(objectName: objectName, place: place, rawPlaceIncludesPreposition: true) {
                return extraction
            }
        }

        return nil
    }

    private func ruleBasedObjectName(from input: String) -> String? {
        var value = cleanedSentence(input)

        let prefixes = [
            "where are ",
            "where is ",
            "where did i put ",
            "find where i put ",
            "find ",
            "look for "
        ]

        for prefix in prefixes where value.hasPrefix(prefix) {
            value.removeFirst(prefix.count)
            break
        }

        return cleanedObjectName(value)
    }

    private var locationPrepositions: [String] {
        ["on", "in", "at", "inside", "under", "behind", "beside", "near", "next to"]
    }

    private func makeRuleBasedExtraction(objectName: String?, place: String, rawPlaceIncludesPreposition: Bool) -> TacExtraction? {
        guard let objectName,
              let cleanedPlace = cleanedRequiredField(place) else {
            return nil
        }

        let specificPlace = cleanedSpecificPlace(cleanedPlace)

        let place = rawPlaceIncludesPreposition ? cleanedPlace : "at \(cleanedPlace)"

        return TacExtraction(
            objectName: objectName,
            place: secondPersonPossessives(place),
            specificPlace: secondPersonPossessives(specificPlace),
            area: nil
        )
    }

    private func cleanedSentence(_ value: String) -> String {
        value
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func cleanedObjectName(_ value: String) -> String? {
        var cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = ["please ", "i put ", "put ", "my ", "the ", "a ", "an "]

        var removedPrefix = true
        while removedPrefix {
            removedPrefix = false
            for prefix in prefixes where cleaned.hasPrefix(prefix) {
                cleaned.removeFirst(prefix.count)
                removedPrefix = true
            }
        }

        return cleanedRequiredField(cleaned)
    }

    private func cleanedSpecificPlace(_ value: String) -> String {
        var cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)

        for preposition in locationPrepositions where cleaned.hasPrefix("\(preposition) ") {
            cleaned.removeFirst(preposition.count + 1)
            break
        }

        let articles = ["the ", "my ", "a ", "an "]
        for article in articles where cleaned.hasPrefix(article) {
            cleaned.removeFirst(article.count)
            break
        }

        return cleaned
    }

    private func cleanedRequiredField(_ value: String) -> String? {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty,
              cleaned.lowercased() != "unknown",
              cleaned.lowercased() != "uncertain" else {
            return nil
        }

        return cleaned
    }

    private func cleanedOptionalField(_ value: String) -> String? {
        cleanedRequiredField(value)
    }
}

enum NLPServiceError: LocalizedError {
    case couldNotExtractPlacement
    case couldNotExtractObject
    case modelUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .couldNotExtractPlacement:
            return "I could not tell both the item and the place. Please say something like, 'my keys are on the kitchen counter.'"
        case .couldNotExtractObject:
            return "I could not tell which item you are looking for."
        case .modelUnavailable(let message):
            return message
        }
    }
}
