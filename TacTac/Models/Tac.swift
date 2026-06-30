import Foundation
import SwiftData

@Model
class Tac {
    var id: UUID
    var objectName: String
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
        self.objectName = objectName
        self.place = place
        self.rawInput = rawInput
        self.createdAt = now
        self.updatedAt = now
        self.confidence = confidence
        self.tags = tags
    }
}
