import AppIntents
import UIKit
import WidgetKit

/// Валюта для выбора в настройках виджета. Особая строка «Не выбрано» сбрасывает поле:
/// в системном окне выбора своей кнопки очистки нет.
struct CurrencyEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Currency"
    static let defaultQuery = CurrencyQuery()

    /// Настройки приложения — один раз на запуск расширения, а не для каждой из сотен строк списка.
    private static let snapshot = WidgetSnapshot.load()

    /// Код строки «Не выбрано».
    static let noneID = "-"

    let id: String

    /// Код валюты; nil — выбрано «Не выбрано».
    var code: String? { id == Self.noneID ? nil : id }

    var displayRepresentation: DisplayRepresentation {
        guard let code else { return DisplayRepresentation(title: "Not selected") }
        var name = CurrencyCatalog.name(for: code, locale: .current)
        if CurrencyCatalog.isCrypto(code) { name = "₿ " + name }
        // Без подписки платные валюты помечены — в виджете вместо них останутся валюты из приложения.
        if let app = Self.snapshot, !app.allows(code) { name += " · PRO" }
        // Флаг — эмодзи в заголовке: картинки из каталога окно настроек виджета загружает ненадёжно.
        let flag = CurrencyCatalog.flagRegion(for: code).map(Self.flagEmoji(region:)) ?? ""
        return DisplayRepresentation(title: "\(flag.isEmpty ? code : flag + " " + code)", subtitle: "\(name)")
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
        ([CurrencyEntity.noneID] + Self.allCodes()).map(CurrencyEntity.init(id:))
    }

    func entities(matching string: String) async throws -> [CurrencyEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return try await suggestedEntities() }
        let english = Locale(identifier: "en_US")
        return Self.allCodes()
            .filter {
                $0.localizedStandardContains(query)
                    || CurrencyCatalog.name(for: $0, locale: .current).localizedStandardContains(query)
                    || CurrencyCatalog.name(for: $0, locale: english).localizedStandardContains(query)
            }
            .map(CurrencyEntity.init(id:))
    }

    /// Сначала валюты из списка в приложении, затем криптовалюты, затем остальной фиат по алфавиту:
    /// разделов в системном окне выбора нет, поэтому крипта — сразу после своих валют.
    static func allCodes() -> [String] {
        let app = WidgetSnapshot.load()?.codes ?? []
        var fiat = SharedRates.load().map { Array($0.fiat.keys) } ?? []
        if fiat.isEmpty { fiat = Locale.commonISOCurrencyCodes }
        let rest = CryptoAsset.all.map(\.code) + fiat.filter { !CurrencyCatalog.isCrypto($0) }.sorted()
        var seen = Set(app)
        return app + rest.filter { seen.insert($0).inserted }
    }
}

/// Фон виджета: обычный или цвет одной из валют.
enum WidgetTint: String, AppEnum {
    case standard, main, second

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Color"
    static let caseDisplayRepresentations: [WidgetTint: DisplayRepresentation] = [
        .standard: "Default",
        .main: "Main currency color",
        .second: "Second currency color",
    ]
}

/// Виджет «Курс»: одна валюта в другой.
struct PairIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Exchange rate"
    static let description = IntentDescription("One currency in another, with the change over a day")

    @Parameter(title: "From")
    var source: CurrencyEntity?

    @Parameter(title: "To")
    var target: CurrencyEntity?

    @Parameter(title: "Color", default: .standard)
    var tint: WidgetTint
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

    @Parameter(title: "Color", default: .standard)
    var tint: WidgetTint

    /// Выбранные валюты кроме основной — в порядке полей, без повторов.
    var others: [String] {
        var seen = Set<String>()
        return [second, third, fourth, fifth, sixth]
            .compactMap { $0?.code }
            .filter { $0 != source?.code && seen.insert($0).inserted }
    }
}
