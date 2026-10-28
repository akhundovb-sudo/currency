import Foundation
import WidgetKit

/// Передаёт виджетам выбранные валюты и суммы. Пишем, только когда снимок изменился:
/// перезагрузка виджетов ограничена системой, лишние обновления её расходуют.
@MainActor
enum WidgetBridge {
    static func publish(_ store: RatesStore) {
        let snapshot = WidgetSnapshot(
            rows: store.selectedCodes.map { code in
                let currency = Currency(code: code)
                let value: String
                if code == store.sourceCode {
                    value = store.amountText.isEmpty ? "1" : RateFormat.groupedInput(store.amountText)
                } else {
                    value = store.convertedAmount(to: code).map(RateFormat.amount) ?? "—"
                }
                return WidgetSnapshot.Row(
                    code: code,
                    name: currency.name,
                    value: value,
                    isSource: code == store.sourceCode,
                    flag: currency.flagRegion.map(WidgetSnapshot.flagEmoji(region:))
                )
            },
            isRightToLeft: store.language.isRightToLeft,
            updatedAt: .now
        )
        // Время обновления не сравниваем: иначе снимок «меняется» при каждом вызове.
        if var old = WidgetSnapshot.load() {
            old.updatedAt = snapshot.updatedAt
            if old == snapshot { return }
        }
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
