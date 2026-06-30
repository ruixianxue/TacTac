import Foundation
import FoundationModels

struct TacExtraction: Equatable {
    let objectName: String
    let place: String
}

@MainActor
final class NLPService {
    static let shared = NLPService()
    
    // Extract {object, place} from natural language input
    func extractTac(from input: String) async throws -> TacExtraction {
        let session = LanguageModelSession()
        
        let prompt = """
        You are an information extraction assistant.
        The user said a sentence describing where they placed an object.
        Extract:
        - object: the item name (short, 1-4 words)
        - place: the location (short, under 10 words)
        
        Output only JSON, no other text. Format: {"object":"xxx","place":"xxx"}
        
        If either value is missing or uncertain, output an empty string for that value.

        User said:
        \"\"\"
        \(input)
        \"\"\"
        """
        
        let response = try await session.respond(to: prompt)
        let text = response.content
        
        guard let json = parseJSONObject(from: text),
              let object = cleanedField(json["object"]),
              let place = cleanedField(json["place"]) else {
            throw NLPServiceError.couldNotExtractPlacement
        }
        
        return TacExtraction(objectName: object, place: place)
    }

    // Extract the object the user wants to find from a question.
    func extractObjectName(from input: String) async throws -> String {
        let session = LanguageModelSession()

        let prompt = """
        You extract the item name from a user's question.
        The user is asking where an item is.

        Output only JSON, no other text. Format: {"object":"xxx"}

        If the item is missing or uncertain, output an empty string.

        User asked:
        \"\"\"
        \(input)
        \"\"\"
        """

        let response = try await session.respond(to: prompt)
        let text = response.content

        guard let json = parseJSONObject(from: text),
              let object = cleanedField(json["object"]) else {
            throw NLPServiceError.couldNotExtractObject
        }

        return object
    }

    // Choose the most likely matching Tac when exact local matching fails.
    func chooseBestTac(query: String, candidates: [Tac]) async throws -> Tac? {
        guard !candidates.isEmpty else {
            return nil
        }

        let session = LanguageModelSession()
        let candidateList = candidates.enumerated()
            .map { index, tac in
                "\(index): object=\(tac.objectName), place=\(tac.place), tags=\(tac.tags.joined(separator: ","))"
            }
            .joined(separator: "\n")

        let prompt = """
        You match a user's item query to saved object-location records.
        Return the best matching index only if it is likely the same item or a related item.
        If none match, use -1.

        Output only JSON, no other text. Format: {"index":0}

        Query: \(query)
        Records:
        \(candidateList)
        """

        let response = try await session.respond(to: prompt)
        let text = response.content

        guard let json = parseJSONObject(from: text),
              let index = intField(json["index"]),
              candidates.indices.contains(index) else {
            return nil
        }

        return candidates[index]
    }
    
    // Generate a natural language answer from structured data
    func generateAnswer(objectName: String, place: String, createdAt: Date) async throws -> String {
        let session = LanguageModelSession()
        
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "en_US")
        let timeAgo = formatter.localizedString(for: createdAt, relativeTo: Date())
        
        let prompt = """
        Answer in one short natural sentence in English.
        Item: \(objectName)
        Location: \(place)
        Stored: \(timeAgo)
        
        Example: "Your keys are at the front door, stored 3 hours ago."
        Output only that one sentence.
        """
        
        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseJSONObject(from text: String) -> [String: Any]? {
        let cleanedText = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleanedText.data(using: .utf8) else {
            return nil
        }

        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private func cleanedField(_ value: Any?) -> String? {
        guard let string = value as? String else {
            return nil
        }

        let cleaned = string.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty,
              cleaned.lowercased() != "unknown",
              cleaned.lowercased() != "uncertain" else {
            return nil
        }

        return cleaned
    }

    private func intField(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }

        if let double = value as? Double {
            return Int(double)
        }

        if let string = value as? String {
            return Int(string.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return nil
    }
}

enum NLPServiceError: LocalizedError {
    case couldNotExtractPlacement
    case couldNotExtractObject

    var errorDescription: String? {
        switch self {
        case .couldNotExtractPlacement:
            return "I could not tell both the item and the place. Please say something like, 'my keys are on the kitchen counter.'"
        case .couldNotExtractObject:
            return "I could not tell which item you are looking for."
        }
    }
}
