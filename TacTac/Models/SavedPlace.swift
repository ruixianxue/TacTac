import Foundation
import SwiftData

@Model
final class SavedPlace {
    var id: UUID
    var name: String
    var normalizedName: String
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
    var iconName: String = "mappin.circle.fill"
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double = 150,
        iconName: String = "mappin.circle.fill",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.normalizedName = Self.normalizeName(name)
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.iconName = iconName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func update(name: String, latitude: Double, longitude: Double, radiusMeters: Double, iconName: String) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.normalizedName = Self.normalizeName(name)
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.iconName = iconName
        self.updatedAt = Date()
    }

    static func normalizeName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
