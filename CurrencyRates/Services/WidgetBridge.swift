import Foundation
import WidgetKit

/// Передаёт виджетам выбранные валюты, сумму и курсы. Пишем, только когда что-то изменилось:
/// перезагрузка виджетов ограничена системой, лишние обновления её расходуют.
@MainActor
enum WidgetBridge {
    static func publish(_ store: RatesStore) {
        let snapshot = WidgetSnapshot(
            codes: store.selectedCodes,
            sourceCode: store.sourceCode,
            amount: store.amount,
            languageIdentifier: Currency.locale.identifier,
            numberLocaleIdentifier: RateFormat.locale.identifier,
            decimalPlaces: RateFormat.decimalPlaces,
            isRightToLeft: store.language.isRightToLeft,
            isPro: store.isPro,
            freeCodes: store.freeCodes.sorted(),
            countryCode: store.currentCountry,
            countryCurrency: store.currentCountryCurrency
        )
        var changed = false
        if WidgetSnapshot.load() != snapshot {
            snapshot.save()
            changed = true
        }

        if let rates = store.snapshot, !rates.isDemo {
            let old = SharedRates.load() ?? .empty
            var new = old
            new.record(
                fiat: rates.fiat?.rates, fiatAt: rates.fiat?.fetchedAt,
                crypto: rates.crypto?.rates, cryptoAt: rates.crypto?.fetchedAt,
                cryptoChanges: rates.crypto?.changes
            )
            if new != old {
                new.save()
                changed = true
            }
        }

        if changed { WidgetCenter.shared.reloadAllTimelines() }
    }
}
