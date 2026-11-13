import ActivityKit
import Foundation

/// Live Activity «В поездке»: пока вы в другой стране, на экране блокировки и в Dynamic Island
/// виден курс местной валюты к домашней. Дома — убирается.
/// Сервера нет, поэтому курс обновляется, когда приложение открыто или загрузило новые курсы;
/// выключить показ можно в системных настройках Cento → Live Activities.
@MainActor
enum TravelActivityController {
    /// Через сколько курс считается устаревшим — система приглушит Live Activity.
    private static let staleAfter: TimeInterval = 12 * 3600

    static func update(_ store: RatesStore) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let activities = Activity<TravelActivityAttributes>.activities

        // Валюта показа — выбранная в настройках или первая фиатная в списке.
        // Валюта курса — выбранная (показывается всегда) или местная: тогда только в поездке,
        // то есть когда она не совпадает с домашней и с валютой страны, где приложение установили.
        let home = store.travelActivityTarget ?? store.selectedCodes.first(where: { CryptoAsset.byCode[$0] == nil })
        let local: String? = store.travelActivitySource ?? store.currentCountryCurrency.flatMap { code in
            code == home || code == store.localCurrency ? nil : code
        }
        guard store.showsTravelActivity,
              let local, let home, local != home,
              let rate = store.snapshot?.rate(from: local, to: home) else {
            // Выключена в настройках, дома или курса нет — Live Activity не нужна.
            end(activities)
            return
        }

        let state = TravelActivityAttributes.ContentState(rate: rate, updatedAt: store.snapshot?.fiat?.fetchedAt ?? .now)
        let content = ActivityContent(state: state, staleDate: Date.now.addingTimeInterval(staleAfter))

        // Та же поездка — только новый курс.
        if let current = activities.first(where: { $0.attributes.local == local && $0.attributes.home == home }) {
            // В задачу передаётся только id: сам Activity не Sendable.
            let id = current.id
            Task { await Self.update(id, content) }
            end(activities.filter { $0.id != current.id })
            return
        }

        // Новая страна или другая домашняя валюта — прежнюю убираем, начинаем новую.
        end(activities)
        let attributes = TravelActivityAttributes(
            local: local,
            // Страна — только если курс местной валюты, а не выбранной вручную.
            country: local == store.currentCountryCurrency ? store.currentCountry : nil,
            home: home,
            numberLocaleIdentifier: RateFormat.locale.identifier,
            languageIdentifier: store.language.locale.identifier
        )
        _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
    }

    private static func end(_ activities: [Activity<TravelActivityAttributes>]) {
        for id in activities.map(\.id) {
            Task { await Self.end(id) }
        }
    }

    // Activity не Sendable: находим и меняем его вне главного актора, в одном контексте.
    nonisolated private static func update(_ id: String, _ content: ActivityContent<TravelActivityAttributes.ContentState>) async {
        await Activity<TravelActivityAttributes>.activities.first { $0.id == id }?.update(content)
    }

    nonisolated private static func end(_ id: String) async {
        await Activity<TravelActivityAttributes>.activities.first { $0.id == id }?.end(nil, dismissalPolicy: .immediate)
    }
}
