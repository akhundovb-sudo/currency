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
        if let image = CurrencyCatalog.imageName(for: id), UIImage(named: image) != nil {
            return DisplayRepresentation(title: "\(id)", subtitle: "\(name)", image: .init(named: image))
        }
        return DisplayRepresentation(title: "\(id)", subtitle: "\(name)")
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

/// Виджет «Мои валюты»: несколько валют с суммой. Пустые поля — как в приложении.
struct ListIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "My currencies"
    static let description = IntentDescription("Several currencies at once — from your app list or chosen here")

    @Parameter(title: "Base currency")
    var source: CurrencyEntity?

    @Parameter(title: "Currencies")
    var currencies: [CurrencyEntity]?

    @Parameter(title: "Amount")
    var amount: Double?
}
