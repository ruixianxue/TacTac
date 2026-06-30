import Foundation
import FoundationModels

class NLPService {
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
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let object = json["object"],
              let place = json["place"] else {
            // Fallback if parsing fails
            return (objectName: input, place: "unknown location")
        }
        
        return (objectName: object, place: place)
    }
    
    // Generate a natural language answer from structured data
    func generateAnswer(objectName: String, place: String, createdAt: Date) async throws -> String {
        let session = LanguageModelSession()
        
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        let timeAgo = formatter.localizedString(for: createdAt, relativeTo: Date())
        
        let prompt = """
        Answer in one short natural sentence in Chinese.
        Item: \(objectName)
        Location: \(place)
        Stored: \(timeAgo)
        
        Example: "Your keys are at the front door, stored 3 hours ago."
        Output only that one sentence.
        """
        
        let response = try await session.respond(to: prompt)
        return response.content
    }
}
