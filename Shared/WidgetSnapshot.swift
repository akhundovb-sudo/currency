import Foundation

/// Что показывают виджеты: валюты списка в том же порядке, с уже отформатированными суммами.
/// Приложение записывает снимок в общий контейнер App Group, виджет только читает —
/// так в виджете те же числа, что и в приложении, без своей загрузки курсов.
struct WidgetSnapshot: Codable, Equatable, Sendable {
    struct Row: Codable, Equatable, Sendable, Identifiable {
        let code: String
        let name: String
        let value: String
        /// Валюта ввода: её сумма выделяется цветом, как в приложении.
        let isSource: Bool
        /// Флаг фиатной валюты (эмодзи); у криптовалют — нет.
        let flag: String?

        var id: String { code }
    }

    var rows: [Row]
    var isRightToLeft: Bool
    var updatedAt: Date

    static let appGroup = "group.com.akhundov.CurrencyRates"
    private static let key = "widgetSnapshot"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func load() -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.defaults?.set(data, forKey: Self.key)
    }

    /// Флаг-эмодзи по коду страны («US» → 🇺🇸).
    static func flagEmoji(region: String) -> String {
        region.uppercased().unicodeScalars
            .compactMap { Unicode.Scalar(0x1F1E6 + $0.value - 0x41) }
            .map(String.init)
            .joined()
    }

    /// Для галереи виджетов и превью: пока приложение ещё ничего не записало.
    static let preview = WidgetSnapshot(
        rows: [
            Row(code: "USD", name: "US Dollar", value: "100", isSource: true, flag: flagEmoji(region: "US")),
            Row(code: "EUR", name: "Euro", value: "89.75", isSource: false, flag: flagEmoji(region: "EU")),
            Row(code: "RUB", name: "Russian Ruble", value: "8,056.16", isSource: false, flag: flagEmoji(region: "RU")),
            Row(code: "CNY", name: "Chinese Yuan", value: "668.1", isSource: false, flag: flagEmoji(region: "CN")),
            Row(code: "BTC", name: "Bitcoin", value: "0.001231", isSource: false, flag: nil),
            Row(code: "ETH", name: "Ethereum", value: "0.04238", isSource: false, flag: nil),
            Row(code: "TRY", name: "Turkish Lira", value: "4,981.01", isSource: false, flag: flagEmoji(region: "TR")),
            Row(code: "BRL", name: "Brazilian Real", value: "534.84", isSource: false, flag: flagEmoji(region: "BR")),
        ],
        isRightToLeft: false,
        updatedAt: .now
    )
}
