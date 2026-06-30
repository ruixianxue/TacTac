import Foundation
import SwiftData

@Model
final class MemoryItem {
    var id: UUID
    var objectName: String
    var location: String
    var timeAdded: Date
    var iconType: String
    
    init(id: UUID = UUID(), objectName: String, location: String, timeAdded: Date = Date(), iconType: String = "cube.box.fill") {
        self.id = id
        self.objectName = objectName
        self.location = location
        self.timeAdded = timeAdded
        self.iconType = iconType
    }
}
