import Foundation
import FoundationModels

@MainActor
final class NLPService {
    static let shared = NLPService()
    
    // Extract {object, place} from natural language input
    func extractTac(from input: String) async throws -> (objectName: String, place: String) {
        let session = LanguageModelSession()
        
        let prompt = """
        You are an information extraction assistant.
        The user said a sentence describing where they placed an object.
        Extract:
        - object: the item name (short, 1-4 words)
        - place: the location (short, under 10 words)
        
        Output only JSON, no other text. Format: {"object":"xxx","place":"xxx"}
        
        User said: \(input)
        """
        
        let response = try await session.respond(to: prompt)
        let text = response.content
        
        // Parse JSON response
        guard let data = cleanJSONText(text).data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let object = json["object"],
              let place = json["place"] else {
            // Fallback if parsing fails
            return (objectName: input, place: "unknown location")
        }
        
        return (objectName: object, place: place)
    }

    // Extract the object the user wants to find from a question.
    func extractObjectName(from input: String) async throws -> String {
        let session = LanguageModelSession()

        let prompt = """
        You extract the item name from a user's question.
        The user is asking where an item is.

        Output only JSON, no other text. Format: {"object":"xxx"}

        User asked: \(input)
        """

        let response = try await session.respond(to: prompt)
        let text = response.content

        guard let data = cleanJSONText(text).data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let object = json["object"],
              !object.isEmpty else {
            return input
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

        guard let data = cleanJSONText(text).data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Int],
              let index = json["index"],
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
        return response.content
    }

    private func cleanJSONText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
