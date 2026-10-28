import CoreLocation
import Foundation

/// Определяет страну по геолокации и отдаёт её валюту. Запрашивает разрешение
/// «при использовании» при первом запуске; точность — до города, этого хватает.
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var onCurrency: (@MainActor (String) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
    }

    /// Запрашивает разрешение (если ещё не спрашивали) и один раз определяет валюту страны.
    func requestLocalCurrency(_ completion: @escaping @MainActor (String) -> Void) {
        onCurrency = completion
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch self.manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                if self.onCurrency != nil { self.manager.requestLocation() }
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in await self.resolveCurrency(for: location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Не получилось — остаются доллар и евро.
    }

    private func resolveCurrency(for location: CLLocation) async {
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first,
              let country = placemark.isoCountryCode,
              let currency = Locale(identifier: "en_\(country)").currency?.identifier
        else { return }
        onCurrency?(currency)
        onCurrency = nil
    }
}
