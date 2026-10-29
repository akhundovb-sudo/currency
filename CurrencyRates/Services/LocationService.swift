import CoreLocation
import Foundation

/// Определяет страну по геолокации и отдаёт её код и валюту. Запрашивает разрешение
/// «при использовании» при первом запуске; точность — до города, этого хватает.
/// Вызывается при каждом открытии приложения: виджет «Путешествие» показывает валюту страны, где вы сейчас.
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var onCurrency: (@MainActor (_ currency: String, _ country: String) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
    }

    /// Запрашивает разрешение (если ещё не спрашивали) и определяет страну и её валюту.
    func requestLocalCurrency(_ completion: @escaping @MainActor (_ currency: String, _ country: String) -> Void) {
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
        onCurrency?(currency, country)
        onCurrency = nil
    }
}
