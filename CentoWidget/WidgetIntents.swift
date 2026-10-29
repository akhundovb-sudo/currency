import AppIntents
import UIKit
import WidgetKit

/// Валюта для выбора в настройках виджета. Особая строка «Не выбрано» сбрасывает поле:
/// в системном окне выбора своей кнопки очистки нет.
struct CurrencyEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Currency"
    static let defaultQuery = CurrencyQuery()

    /// Код строки «Не выбрано».
    static let noneID = "-"

    let id: String

    /// Код валюты; nil — выбрано «Не выбрано».
    var code: String? { id == Self.noneID ? nil : id }

    var displayRepresentation: DisplayRepresentation {
        guard let code else { return DisplayRepresentation(title: "Not selected") }
        let label = CurrencyLabels.shared.label(for: code)
        return DisplayRepresentation(title: "\(label.title)", subtitle: "\(label.subtitle)")
    }
}

/// Подписи валют для окна выбора — считаются один раз на запуск расширения.
/// При быстрой прокрутке система запрашивает подписи сразу для многих строк; если считать
/// название и флаг каждый раз, расширение не успевает и строки показывают «Unable to Load».
final class CurrencyLabels: @unchecked Sendable {
    static let shared = CurrencyLabels()

    struct Label {
        let title: String
        let subtitle: String
        /// Название по-английски — для поиска.
        let english: String
    }

    /// Все валюты в порядке списка: свои из приложения, криптовалюты, остальной фиат.
    let codes: [String]
    /// Валюты для списка без поиска: свои, 15 криптовалют и популярные фиатные.
    let suggested: [String]

    private static let popularFiat = [
        "USD", "EUR", "GBP", "JPY", "CNY", "CHF", "CAD", "AUD", "TRY", "AED", "RUB", "KZT",
        "AZN", "GEL", "UAH", "INR", "KRW", "HKD", "SGD", "THB", "BRL", "MXN", "PLN", "CZK",
        "SEK", "NOK", "DKK", "ILS", "SAR", "EGP",
    ]
    private var labels: [String: Label] = [:]
    private let lock = NSLock()

    private init() {
        let app = WidgetSnapshot.load()
        var fiat = SharedRates.load().map { Array($0.fiat.keys) } ?? []
        if fiat.isEmpty { fiat = Locale.commonISOCurrencyCodes }
        let rest = CryptoAsset.all.map(\.code) + fiat.filter { !CurrencyCatalog.isCrypto($0) }.sorted()
        var seen = Set(app?.codes ?? [])
        codes = (app?.codes ?? []) + rest.filter { seen.insert($0).inserted }
        var seenSuggested = Set(app?.codes ?? [])
        let short = CryptoAsset.all.prefix(15).map(\.code) + Self.popularFiat
        suggested = (app?.codes ?? []) + short.filter { seenSuggested.insert($0).inserted }

        let english = Locale(identifier: "en_US")
        for code in codes {
            labels[code] = Self.makeLabel(code, app: app, english: english)
        }
    }

    func label(for code: String) -> Label {
        lock.lock()
        defer { lock.unlock() }
        if let label = labels[code] { return label }
        // Валюта не из списка (например, сохранённая раньше) — считаем и запоминаем.
        let label = Self.makeLabel(code, app: WidgetSnapshot.load(), english: Locale(identifier: "en_US"))
        labels[code] = label
        return label
    }

    private static func makeLabel(_ code: String, app: WidgetSnapshot?, english: Locale) -> Label {
        var name = CurrencyCatalog.name(for: code, locale: .current)
        if CurrencyCatalog.isCrypto(code) { name = "₿ " + name }
        // Без подписки платные валюты помечены — в виджете вместо них останутся валюты из приложения.
        if let app, !app.allows(code) { name += " · PRO" }
        // Флаг — эмодзи в заголовке: картинки из каталога окно настроек виджета загружает ненадёжно.
        let flag = CurrencyCatalog.flagRegion(for: code).map(flagEmoji(region:)) ?? ""
        return Label(
            title: flag.isEmpty ? code : flag + " " + code,
            subtitle: name,
            english: CurrencyCatalog.name(for: code, locale: english)
        )
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

    /// Короткий список: свои валюты, топ криптовалют и самые ходовые валюты мира.
    /// Все ~230 строк система при быстрой прокрутке не успевала подгрузить («Unable to Load»);
    /// остальные валюты находятся поиском по коду или названию.
    func suggestedEntities() async throws -> [CurrencyEntity] {
        ([CurrencyEntity.noneID] + CurrencyLabels.shared.suggested).map(CurrencyEntity.init(id:))
    }

    func entities(matching string: String) async throws -> [CurrencyEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return try await suggestedEntities() }
        let labels = CurrencyLabels.shared
        return labels.codes
            .filter { code in
                let label = labels.label(for: code)
                return code.localizedStandardContains(query)
                    || label.subtitle.localizedStandardContains(query)
                    || label.english.localizedStandardContains(query)
            }
            .map(CurrencyEntity.init(id:))
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

    /// На экране блокировки цветного фона нет — там только две валюты.
    static var parameterSummary: some ParameterSummary {
        When(widgetFamily: .equalTo, .accessoryRectangular) {
            Summary {
                \.$source
                \.$target
            }
        } otherwise: {
            When(widgetFamily: .equalTo, .accessoryInline) {
                Summary {
                    \.$source
                    \.$target
                }
            } otherwise: {
                When(widgetFamily: .equalTo, .accessoryCircular) {
                    Summary {
                        \.$source
                        \.$target
                    }
                } otherwise: {
                    Summary {
                        \.$source
                        \.$target
                        \.$tint
                    }
                }
            }
        }
    }
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

    /// В настройках столько полей валют, сколько помещается в выбранный размер:
    /// маленький и средний — 4, большой — 6. На экране блокировки — только 2–3 валюты:
    /// цветного фона там нет, а сумма берётся из приложения (или 1).
    static var parameterSummary: some ParameterSummary {
        When(widgetFamily: .equalTo, .systemLarge) {
            Summary {
                \.$source
                \.$second
                \.$third
                \.$fourth
                \.$fifth
                \.$sixth
                \.$amount
                \.$tint
            }
        } otherwise: {
            When(widgetFamily: .equalTo, .accessoryRectangular) {
                Summary {
                    \.$source
                    \.$second
                    \.$third
                }
            } otherwise: {
                When(widgetFamily: .equalTo, .accessoryInline) {
                    Summary {
                        \.$source
                        \.$second
                    }
                } otherwise: {
                    When(widgetFamily: .equalTo, .accessoryCircular) {
                        Summary {
                            \.$source
                            \.$second
                        }
                    } otherwise: {
                        Summary {
                            \.$source
                            \.$second
                            \.$third
                            \.$fourth
                            \.$amount
                            \.$tint
                        }
                    }
                }
            }
        }
    }

    /// Выбранные валюты кроме основной — в порядке полей, без повторов.
    var others: [String] {
        var seen = Set<String>()
        return [second, third, fourth, fifth, sixth]
            .compactMap { $0?.code }
            .filter { $0 != source?.code && seen.insert($0).inserted }
    }
}

// MARK: - Кнопки на виджете «Курс»

/// «⇄» — поменять валюты пары местами.
struct SwapPairIntent: AppIntent {
    static let title: LocalizedStringResource = "Swap currencies"
    static let isDiscoverable = false

    @Parameter(title: "Pair")
    var pair: String

    init() {}

    init(pair: String) {
        self.pair = pair
    }

    func perform() async throws -> some IntentResult {
        var state = PairState.load(pair)
        state.isSwapped.toggle()
        PairState.save(state, for: pair)
        return .result()
    }
}

/// «1 / 10 / 100 / 1K» — сколько считать.
struct PairAmountIntent: AppIntent {
    static let title: LocalizedStringResource = "Amount"
    static let isDiscoverable = false

    @Parameter(title: "Pair")
    var pair: String

    @Parameter(title: "Amount")
    var amount: Double

    init() {}

    init(pair: String, amount: Double) {
        self.pair = pair
        self.amount = amount
    }

    func perform() async throws -> some IntentResult {
        var state = PairState.load(pair)
        state.amount = amount
        PairState.save(state, for: pair)
        return .result()
    }
}
