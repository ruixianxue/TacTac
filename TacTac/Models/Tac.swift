import Foundation
import SwiftData

@Model
class Tac {
    var id: UUID
    var objectName: String
    var normalizedObjectName: String
    var place: String
    var specificPlace: String = ""
    var area: String?
    var rawInput: String
    var createdAt: Date
    var updatedAt: Date
    var confidence: Double
    var tags: [String]
    
    init(
        objectName: String,
        place: String,
        specificPlace: String? = nil,
        area: String? = nil,
        rawInput: String,
        confidence: Double = 1.0,
        tags: [String] = []
    ) {
        let now = Date()

        self.id = UUID()
        self.objectName = objectName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.normalizedObjectName = Self.normalizeObjectName(objectName)
        self.place = place.trimmingCharacters(in: .whitespacesAndNewlines)
        self.specificPlace = (specificPlace ?? place).trimmingCharacters(in: .whitespacesAndNewlines)
        self.area = Self.cleanedOptionalLocation(area)
        self.rawInput = rawInput
        self.createdAt = now
        self.updatedAt = now
        self.confidence = confidence
        self.tags = tags
    }

    func updateLocation(
        objectName: String,
        place: String,
        specificPlace: String? = nil,
        area: String? = nil,
        rawInput: String,
        confidence: Double = 1.0,
        tags: [String] = []
    ) {
        self.objectName = objectName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.normalizedObjectName = Self.normalizeObjectName(objectName)
        self.place = place.trimmingCharacters(in: .whitespacesAndNewlines)
        self.specificPlace = (specificPlace ?? place).trimmingCharacters(in: .whitespacesAndNewlines)
        self.area = Self.cleanedOptionalLocation(area)
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

    static func displayPlace(specificPlace: String, area: String?) -> String {
        let cleanedSpecificPlace = specificPlace.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let area = cleanedOptionalLocation(area) else {
            return cleanedSpecificPlace
        }

        return "\(cleanedSpecificPlace) in \(area)"
    }

    private static func cleanedOptionalLocation(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }
}
