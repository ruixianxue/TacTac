import Foundation
import SwiftData

@Model
class Tac {
    var id: UUID
    var objectName: String
    var normalizedObjectName: String
    var place: String
    var rawInput: String
    var createdAt: Date
    var updatedAt: Date
    var confidence: Double
    var tags: [String]
    
    init(
        objectName: String,
        place: String,
        rawInput: String,
        confidence: Double = 1.0,
        tags: [String] = []
    ) {
        let now = Date()

        self.id = UUID()
        self.objectName = objectName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.normalizedObjectName = Self.normalizeObjectName(objectName)
        self.place = place.trimmingCharacters(in: .whitespacesAndNewlines)
        self.rawInput = rawInput
        self.createdAt = now
        self.updatedAt = now
        self.confidence = confidence
        self.tags = tags
    }

    func updateLocation(
        objectName: String,
        place: String,
        rawInput: String,
        confidence: Double = 1.0,
        tags: [String] = []
    ) {
        self.objectName = objectName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.normalizedObjectName = Self.normalizeObjectName(objectName)
        self.place = place.trimmingCharacters(in: .whitespacesAndNewlines)
        self.rawInput = rawInput
        self.updatedAt = Date()
        self.confidence = confidence
        self.tags = Array(Set(self.tags + tags)).sorted()
    }

    static func normalizeObjectName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
