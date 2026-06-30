import Foundation
import SwiftData

@Model
class Tac {
    var id: UUID
    var objectName: String
    var place: String
    var rawInput: String
    var createdAt: Date
    
    init(objectName: String, place: String, rawInput: String) {
        self.id = UUID()
        self.objectName = objectName
        self.place = place
        self.rawInput = rawInput
        self.createdAt = Date()
    }
}
