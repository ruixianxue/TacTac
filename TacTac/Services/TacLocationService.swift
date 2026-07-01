import CoreLocation
import Foundation

struct TacLocationSnapshot: Equatable {
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double
    let namedPlace: String?
}

@MainActor
protocol TacLocationProviding {
    func requestPermissionIfNeeded()
    func currentLocationSnapshot(namedPlaces: [SavedPlace]) async -> TacLocationSnapshot?
}

@MainActor
final class TacLocationService: NSObject, TacLocationProviding, CLLocationManagerDelegate {
    static let shared = TacLocationService()

    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    static var isUsageDescriptionConfigured: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") != nil
    }

    override private init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func requestPermissionIfNeeded() {
        guard Self.isUsageDescriptionConfigured else {
            return
        }

        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func currentLocationSnapshot(namedPlaces: [SavedPlace]) async -> TacLocationSnapshot? {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            break
        case .notDetermined:
            requestPermissionIfNeeded()
            return nil
        case .denied, .restricted:
            return nil
        @unknown default:
            return nil
        }

        guard let location = await requestCurrentLocation() else {
            return nil
        }

        return TacLocationSnapshot(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracy: location.horizontalAccuracy,
            namedPlace: nearestPlaceName(to: location, in: namedPlaces)
        )
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationContinuation?.resume(returning: locations.last)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
    }

    private func requestCurrentLocation() async -> CLLocation? {
        if let existingContinuation = locationContinuation {
            existingContinuation.resume(returning: nil)
            locationContinuation = nil
        }

        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    private func nearestPlaceName(to location: CLLocation, in places: [SavedPlace]) -> String? {
        places
            .compactMap { place -> (name: String, distance: CLLocationDistance)? in
                let placeLocation = CLLocation(latitude: place.latitude, longitude: place.longitude)
                let distance = location.distance(from: placeLocation)
                return distance <= place.radiusMeters ? (place.name, distance) : nil
            }
            .min { lhs, rhs in lhs.distance < rhs.distance }?
            .name
    }
}
