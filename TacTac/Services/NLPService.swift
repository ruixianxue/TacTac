import Foundation

struct TacExtraction: Equatable {
    let objectName: String
    let place: String
    let specificPlace: String
    let area: String?
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
        guard let extraction = ruleBasedTacExtraction(from: input) else {
            throw NLPServiceError.couldNotExtractPlacement
        }

        return extraction
    }

    func extractObjectName(from input: String) async throws -> String {
        guard let objectName = ruleBasedObjectName(from: input) else {
            throw NLPServiceError.couldNotExtractObject
        }

        return objectName
    }

    func chooseBestTac(query: String, candidates: [Tac]) async throws -> Tac? {
        guard !candidates.isEmpty else {
            return nil
        }

        return candidates
            .map { candidate in
                (candidate: candidate, score: semanticScore(query: query, candidate: candidate))
            }
            .filter { $0.score > 0 }
            .max { $0.score < $1.score }?
            .candidate
    }

    func generateAnswer(objectName: String, place: String, createdAt: Date) async throws -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "en_US")
        let timeAgo = formatter.localizedString(for: createdAt, relativeTo: Date())

        return "Your \(objectName) is \(secondPersonPossessives(place)), stored \(timeAgo)."
    }

    private func secondPersonPossessives(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"\b[Mm]y\b"#, with: "your", options: .regularExpression)
            .replacingOccurrences(of: #"\b[Mm]ine\b"#, with: "yours", options: .regularExpression)
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

    private func semanticScore(query: String, candidate: Tac) -> Int {
        let queryTokens = Set(Tac.normalizeObjectName(query).split(separator: " ").map(String.init))
        let candidateTokens = Set(Tac.normalizeObjectName(candidate.objectName).split(separator: " ").map(String.init))

        guard !queryTokens.isEmpty, !candidateTokens.isEmpty else {
            return 0
        }

        let sharedTokens = queryTokens.intersection(candidateTokens)
        guard !sharedTokens.isEmpty else {
            return 0
        }

        let distinguishingTokens = ["boyfriend", "girlfriend", "husband", "wife", "partner", "work", "home"]
        let queryDistinguishers = queryTokens.intersection(distinguishingTokens)
        let candidateDistinguishers = candidateTokens.intersection(distinguishingTokens)

        guard queryDistinguishers == candidateDistinguishers else {
            return 0
        }

        return sharedTokens.count
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
