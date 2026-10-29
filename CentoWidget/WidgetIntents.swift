import AppIntents
import UIKit
import WidgetKit

/// Валюта для выбора в настройках виджета: код, название и круглый значок.
struct CurrencyEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Currency"
    static let defaultQuery = CurrencyQuery()

    let id: String

    var displayRepresentation: DisplayRepresentation {
        var name = CurrencyCatalog.name(for: id, locale: .current)
        // Без подписки платные валюты помечены — в виджете вместо них останутся валюты из приложения.
        if let app = WidgetSnapshot.load(), !app.allows(id) { name += " · 🔒 Pro" }
        // Флаг — эмодзи в заголовке: картинки из каталога окно настроек виджета загружает ненадёжно.
        let flag = CurrencyCatalog.flagRegion(for: id).map(Self.flagEmoji(region:)) ?? ""
        return DisplayRepresentation(title: "\(flag.isEmpty ? id : flag + " " + id)", subtitle: "\(name)")
    }

    /// Флаг-эмодзи по коду страны («US» → 🇺🇸).
    private static func flagEmoji(region: String) -> String {
        region.uppercased().unicodeScalars
            .compactMap { Unicode.Scalar(0x1F1E6 + $0.value - 0x41) }
            .map(String.init)
            .joined()
    }
}

struct CurrencyQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [CurrencyEntity] {
        identifiers.map(CurrencyEntity.init(id:))
    }

    func suggestedEntities() async throws -> [CurrencyEntity] {
        Self.allCodes().map(CurrencyEntity.init(id:))
    }

    func entities(matching string: String) async throws -> [CurrencyEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return try await suggestedEntities() }
        return Self.allCodes()
            .filter { $0.localizedStandardContains(query) || CurrencyCatalog.name(for: $0, locale: .current).localizedStandardContains(query) }
            .map(CurrencyEntity.init(id:))
    }

    /// Сначала валюты из списка в приложении, затем остальные фиатные по алфавиту и криптовалюты.
    static func allCodes() -> [String] {
        let app = WidgetSnapshot.load()?.codes ?? []
        var fiat = SharedRates.load().map { Array($0.fiat.keys) } ?? []
        if fiat.isEmpty { fiat = Locale.commonISOCurrencyCodes }
        let rest = fiat.filter { !CurrencyCatalog.isCrypto($0) }.sorted() + CryptoAsset.all.map(\.code)
        var seen = Set(app)
        return app + rest.filter { seen.insert($0).inserted }
    }
}

/// Виджет «Курс»: одна валюта в другой.
struct PairIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Exchange rate"
    static let description = IntentDescription("One currency in another, with the change over a day")

    @Parameter(title: "From")
    var source: CurrencyEntity?

    @Parameter(title: "To")
    var target: CurrencyEntity?
}

/// Виджет «Мои валюты»: несколько валют с суммой. Если ничего не выбрано — как в приложении.
/// Валюты — отдельными полями, как «Из» и «В» у «Курса»: так окно настроек открывается надёжно.
struct ListIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "My currencies"
    static let description = IntentDescription("Several currencies at once — from your app list or chosen here")

    @Parameter(title: "Base currency")
    var source: CurrencyEntity?

    @Parameter(title: "Currency 2")
    var second: CurrencyEntity?

    @Parameter(title: "Currency 3")
    var third: CurrencyEntity?

    @Parameter(title: "Currency 4")
    var fourth: CurrencyEntity?

    @Parameter(title: "Currency 5")
    var fifth: CurrencyEntity?

    @Parameter(title: "Currency 6")
    var sixth: CurrencyEntity?

    @Parameter(title: "Amount")
    var amount: Double?

    /// Выбранные валюты кроме основной — в порядке полей, без повторов.
    var others: [String] {
        var seen = Set<String>()
        return [second, third, fourth, fifth, sixth]
            .compactMap { $0?.id }
            .filter { $0 != source?.id && seen.insert($0).inserted }
    }
}
