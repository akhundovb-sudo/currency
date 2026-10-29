import Foundation

/// Что виджеты берут из приложения: список валют, валюту ввода, сумму и формат чисел.
/// Приложение записывает снимок в общий контейнер App Group, виджет только читает.
struct WidgetSnapshot: Codable, Equatable, Sendable {
    /// Валюты списка в порядке пользователя.
    var codes: [String]
    var sourceCode: String
    /// Введённая сумма (результат выражения); пустое поле — 1.
    var amount: Double
    /// Язык приложения: названия валют.
    var languageIdentifier: String
    /// Формат чисел из настроек: разделители и число знаков.
    var numberLocaleIdentifier: String
    var decimalPlaces: Int?
    var isRightToLeft: Bool
    /// Подписка Pro: без неё в виджетах — только бесплатные валюты, как в приложении.
    var isPro: Bool
    /// Валюты, доступные без подписки.
    var freeCodes: [String]

    /// Сколько валют можно выбрать в виджете без подписки — как в списке приложения.
    static let freeLimit = 4

    static let appGroup = "group.com.akhundov.CurrencyRates"
    private static let key = "widgetSnapshot.v2"

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    var language: Locale { Locale(identifier: languageIdentifier) }
    var numberLocale: Locale { Locale(identifier: numberLocaleIdentifier) }

    /// Можно ли показать валюту в виджете при текущем плане.
    func allows(_ code: String) -> Bool {
        isPro || freeCodes.contains(code) || codes.contains(code)
    }

    static func load() -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.defaults?.set(data, forKey: Self.key)
    }

    /// Для галереи виджетов и превью: пока приложение ещё ничего не записало.
    static let preview = WidgetSnapshot(
        codes: ["USD", "EUR", "GBP", "JPY", "BTC", "ETH", "TRY", "BRL"],
        sourceCode: "USD",
        amount: 100,
        languageIdentifier: Locale.current.identifier,
        numberLocaleIdentifier: Locale.current.identifier,
        decimalPlaces: nil,
        isRightToLeft: Locale.Language(identifier: Locale.current.identifier).characterDirection == .rightToLeft,
        isPro: true,
        freeCodes: []
    )
}

/// Последние курсы для виджетов: их пишет приложение после загрузки, а виджеты, если
/// приложение давно не открывали, загружают сами. Хранит и курсы за последние сутки —
/// по ним виджет показывает изменение за 24 часа.
struct SharedRates: Codable, Equatable, Sendable {
    /// Сколько единиц валюты стоит 1 USD.
    var fiat: [String: Double]
    var crypto: [String: Double]
    var fiatFetchedAt: Date
    var cryptoFetchedAt: Date
    /// Снимки курсов не чаще раза в час за последние ~30 часов.
    var history: [Sample]

    struct Sample: Codable, Equatable, Sendable {
        let date: Date
        let rates: [String: Double]
    }

    /// Время самых старых из двух наборов курсов.
    var fetchedAt: Date { min(fiatFetchedAt, cryptoFetchedAt) }

    func unitsPerUSD(_ code: String) -> Double? {
        crypto[code] ?? fiat[code]
    }

    /// Сколько единиц `target` стоит 1 единица `source`.
    func rate(from source: String, to target: String) -> Double? {
        guard let s = unitsPerUSD(source), let t = unitsPerUSD(target), s > 0 else { return nil }
        return t / s
    }

    /// Изменение курса за ~24 часа (0.01 — рост на 1 %), если есть снимок суточной давности.
    func change(from source: String, to target: String, now: Date = .now) -> Double? {
        guard let current = rate(from: source, to: target) else { return nil }
        let dayAgo = now.addingTimeInterval(-24 * 3600)
        // Снимок не моложе 18 часов, ближайший к «сутки назад».
        let candidates = history.filter { now.timeIntervalSince($0.date) >= 18 * 3600 }
        guard let sample = candidates.min(by: { abs($0.date.timeIntervalSince(dayAgo)) < abs($1.date.timeIntervalSince(dayAgo)) }),
              let s = sample.rates[source], let t = sample.rates[target], s > 0, t > 0
        else { return nil }
        return current / (t / s) - 1
    }

    /// Записывает новые курсы (любой из наборов может быть nil) и добавляет снимок в историю.
    mutating func record(fiat newFiat: [String: Double]?, fiatAt: Date?, crypto newCrypto: [String: Double]?, cryptoAt: Date?, now: Date = .now) {
        if let newFiat, let fiatAt, fiatAt > fiatFetchedAt || fiat.isEmpty {
            fiat = newFiat
            fiatFetchedAt = fiatAt
        }
        if let newCrypto, let cryptoAt, cryptoAt > cryptoFetchedAt || crypto.isEmpty {
            crypto = newCrypto
            cryptoFetchedAt = cryptoAt
        }
        history.removeAll { now.timeIntervalSince($0.date) > 30 * 3600 }
        if history.last.map({ now.timeIntervalSince($0.date) >= 3600 }) ?? true {
            history.append(Sample(date: now, rates: fiat.merging(crypto) { _, new in new }))
        }
    }

    static let empty = SharedRates(fiat: [:], crypto: [:], fiatFetchedAt: .distantPast, cryptoFetchedAt: .distantPast, history: [])

    // MARK: - Хранение

    /// Файл в контейнере App Group: история курсов великовата для UserDefaults.
    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshot.appGroup)?
            .appendingPathComponent("widget-rates.json")
    }

    static func load() -> SharedRates? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SharedRates.self, from: data)
    }

    func save() {
        guard let url = Self.fileURL, let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Курсы для галереи виджетов, пока настоящих ещё нет.
    static let preview: SharedRates = {
        let rates: [String: Double] = [
            "USD": 1, "EUR": 0.8975, "GBP": 0.7513, "JPY": 152.4, "TRY": 49.81, "BRL": 5.348,
            "RUB": 80.56, "CNY": 6.681, "DKK": 6.70, "BTC": 1 / 80_250.0, "ETH": 1 / 2_330.0,
        ]
        let now = Date.now
        let yesterday = rates.mapValues { $0 * 1.002 }
        return SharedRates(
            fiat: rates.filter { !CurrencyCatalog.isCrypto($0.key) },
            crypto: rates.filter { CurrencyCatalog.isCrypto($0.key) },
            fiatFetchedAt: now,
            cryptoFetchedAt: now,
            history: [Sample(date: now.addingTimeInterval(-24 * 3600), rates: yesterday)]
        )
    }()
}
