import Foundation

/// Демонстрационные данные только для SwiftUI Preview.
/// Значения приблизительные и помечены `isDemo`, интерфейс подписывает их как демонстрационные.
enum PreviewData {
    static let snapshot = RatesSnapshot(
        fiat: RateSet(
            rates: [
                "USD": 1, "AZN": 1.7, "EUR": 0.92, "GBP": 0.79, "RUB": 92.5,
                "TRY": 34.1, "CNY": 7.2, "JPY": 151.3, "GEL": 2.7, "KZT": 480.2,
            ],
            updatedAt: .now.addingTimeInterval(-3600),
            fetchedAt: .now.addingTimeInterval(-600)
        ),
        crypto: RateSet(
            rates: ["BTC": 1 / 80_000, "ETH": 1 / 2_300, "USDT": 1, "SOL": 1 / 100, "TON": 1 / 1.2],
            updatedAt: .now.addingTimeInterval(-120),
            fetchedAt: .now.addingTimeInterval(-60)
        ),
        isDemo: true
    )
}

extension RatesStore {
    /// Хранилище без сети и без записи на диск.
    static func preview(
        selected: [String] = ["USD", "EUR", "AZN", "RUB", "BTC"],
        amount: String = "100"
    ) -> RatesStore {
        RatesStore(
            service: nil,
            defaults: nil,
            cacheURL: nil,
            selectedCodes: selected,
            sourceCode: "USD",
            amountText: amount,
            snapshot: PreviewData.snapshot
        )
    }
}
