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
    /// Страна, где пользователь был при последнем открытии приложения (ISO), и её валюта —
    /// для виджета «Путешествие». nil — страну ещё не определили.
    var countryCode: String? = nil
    var countryCurrency: String? = nil

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
/// приложение давно не открывали, загружают сами. Хранит и историю — для изменения
/// за сутки и графиков: снимки раз в час за двое суток и раз в день за месяц.
struct SharedRates: Codable, Equatable, Sendable {
    /// Сколько единиц валюты стоит 1 USD.
    var fiat: [String: Double]
    var crypto: [String: Double]
    var fiatFetchedAt: Date
    var cryptoFetchedAt: Date
    /// Снимки курсов не чаще раза в час за последние 48 часов.
    var history: [Sample]
    /// Снимок на каждый день за последние ~35 дней — для графиков за неделю и месяц.
    var daily: [Sample]
    /// Изменение цены криптовалют за 24 часа в процентах (от CoinGecko).
    var cryptoChanges: [String: Double]

    struct Sample: Codable, Equatable, Sendable {
        let date: Date
        let rates: [String: Double]

        func rate(from source: String, to target: String) -> Double? {
            guard let s = rates[source], let t = rates[target], s > 0, t > 0 else { return nil }
            return t / s
        }
    }

    init(fiat: [String: Double], crypto: [String: Double], fiatFetchedAt: Date, cryptoFetchedAt: Date,
         history: [Sample], daily: [Sample] = [], cryptoChanges: [String: Double] = [:]) {
        self.fiat = fiat
        self.crypto = crypto
        self.fiatFetchedAt = fiatFetchedAt
        self.cryptoFetchedAt = cryptoFetchedAt
        self.history = history
        self.daily = daily
        self.cryptoChanges = cryptoChanges
    }

    // Файл прежней версии (без `daily` и `cryptoChanges`) читается без потери курсов.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fiat = try c.decode([String: Double].self, forKey: .fiat)
        crypto = try c.decode([String: Double].self, forKey: .crypto)
        fiatFetchedAt = try c.decode(Date.self, forKey: .fiatFetchedAt)
        cryptoFetchedAt = try c.decode(Date.self, forKey: .cryptoFetchedAt)
        history = try c.decodeIfPresent([Sample].self, forKey: .history) ?? []
        daily = try c.decodeIfPresent([Sample].self, forKey: .daily) ?? []
        cryptoChanges = try c.decodeIfPresent([String: Double].self, forKey: .cryptoChanges) ?? [:]
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
        let candidates = (history + daily).filter { now.timeIntervalSince($0.date) >= 18 * 3600 }
        guard let sample = candidates.min(by: { abs($0.date.timeIntervalSince(dayAgo)) < abs($1.date.timeIntervalSince(dayAgo)) }),
              now.timeIntervalSince(sample.date) <= 36 * 3600,
              let old = sample.rate(from: source, to: target)
        else { return nil }
        return current / old - 1
    }

    /// Период графика.
    enum Period: String, Sendable {
        case day, week, month

        var duration: TimeInterval {
            switch self {
            case .day: 24 * 3600
            case .week: 7 * 24 * 3600
            case .month: 30 * 24 * 3600
            }
        }
    }

    /// Точки графика курса за период: из истории (раз в час — для суток и недели,
    /// раз в день — для более давнего) и текущий курс последней точкой.
    func series(from source: String, to target: String, period: Period, now: Date = .now) -> [(date: Date, value: Double)] {
        let start = now.addingTimeInterval(-period.duration)
        let hourlyFrom = period == .day ? start : now.addingTimeInterval(-48 * 3600)
        var samples = history.filter { $0.date >= hourlyFrom }
        if period != .day {
            // Дальше двух суток — дневные снимки.
            samples += daily.filter { $0.date >= start && $0.date < hourlyFrom }
        }
        var points = samples
            .compactMap { sample in sample.rate(from: source, to: target).map { (date: sample.date, value: $0) } }
            .sorted { $0.date < $1.date }
        if let current = rate(from: source, to: target) {
            points.append((date: now, value: current))
        }
        return points
    }

    /// Записывает новые курсы (любой из наборов может быть nil) и добавляет снимки в историю.
    mutating func record(
        fiat newFiat: [String: Double]?, fiatAt: Date?,
        crypto newCrypto: [String: Double]?, cryptoAt: Date?,
        cryptoChanges newChanges: [String: Double]? = nil,
        now: Date = .now
    ) {
        if let newFiat, let fiatAt, fiatAt > fiatFetchedAt || fiat.isEmpty {
            fiat = newFiat
            fiatFetchedAt = fiatAt
        }
        if let newCrypto, let cryptoAt, cryptoAt > cryptoFetchedAt || crypto.isEmpty {
            crypto = newCrypto
            cryptoFetchedAt = cryptoAt
            if let newChanges, !newChanges.isEmpty { cryptoChanges = newChanges }
        }
        let all = fiat.merging(crypto) { _, new in new }
        history.removeAll { now.timeIntervalSince($0.date) > 48 * 3600 }
        if history.last.map({ now.timeIntervalSince($0.date) >= 3600 }) ?? true {
            history.append(Sample(date: now, rates: all))
        }
        daily.removeAll { now.timeIntervalSince($0.date) > 35 * 24 * 3600 }
        if daily.last.map({ !Calendar.current.isDate($0.date, inSameDayAs: now) }) ?? true {
            daily.append(Sample(date: now, rates: all))
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

    /// Курсы для галереи виджетов, пока настоящих ещё нет: с выдуманной историей за месяц,
    /// чтобы в галерее был виден график.
    static let preview: SharedRates = {
        let rates: [String: Double] = [
            "USD": 1, "EUR": 0.8975, "GBP": 0.7513, "JPY": 152.4, "TRY": 49.81, "BRL": 5.348,
            "RUB": 80.56, "CNY": 6.681, "DKK": 6.70, "AZN": 1.7, "BTC": 1 / 80_250.0, "ETH": 1 / 2_330.0,
            "SOL": 1 / 152.0, "XRP": 1 / 0.62, "BNB": 1 / 590.0, "DOGE": 1 / 0.16, "USDT": 1, "TON": 1 / 5.2,
        ]
        let now = Date.now
        // Плавная волна ±1,5 % — для превью графика.
        func sample(_ hoursAgo: Double) -> Sample {
            let k = 1 + 0.015 * sin(hoursAgo / 30) + 0.004 * sin(hoursAgo / 3)
            return Sample(date: now.addingTimeInterval(-hoursAgo * 3600), rates: rates.mapValues { $0 * k })
        }
        return SharedRates(
            fiat: rates.filter { !CurrencyCatalog.isCrypto($0.key) },
            crypto: rates.filter { CurrencyCatalog.isCrypto($0.key) },
            fiatFetchedAt: now,
            cryptoFetchedAt: now,
            history: stride(from: 47.0, through: 1, by: -1).map(sample),
            daily: stride(from: 34.0, through: 2, by: -1).map { sample($0 * 24) },
            cryptoChanges: ["BTC": 2.4, "ETH": -1.3, "USDT": 0.01, "XRP": 5.2, "BNB": 0.8, "SOL": -3.1, "DOGE": 7.9, "TON": -0.6]
        )
    }()
}
