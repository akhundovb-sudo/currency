import AppIntents
import Charts
import SwiftUI
import WidgetKit

// Виджеты «График», «Крипто-рынок» и «Путешествие».

// MARK: - «График»

/// Период графика в настройках.
enum ChartPeriod: String, AppEnum {
    case day, week, month

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Period"
    static let caseDisplayRepresentations: [ChartPeriod: DisplayRepresentation] = [
        .day: "Day",
        .week: "Week",
        .month: "Month",
    ]

    var period: SharedRates.Period {
        switch self {
        case .day: .day
        case .week: .week
        case .month: .month
        }
    }

    /// Короткая подпись на виджете: «24H», «7D», «30D».
    var shortLabel: String {
        switch self {
        case .day: "24H"
        case .week: "7D"
        case .month: "30D"
        }
    }
}

struct ChartIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Rate chart"
    static let description = IntentDescription("A pair with a chart for a day, week or month")

    @Parameter(title: "From")
    var source: CurrencyEntity?

    @Parameter(title: "To")
    var target: CurrencyEntity?

    @Parameter(title: "Period", default: .week)
    var period: ChartPeriod

    @Parameter(title: "Color", default: .trend)
    var tint: ChartTint

    static var parameterSummary: some ParameterSummary {
        When(widgetFamily: .equalTo, .accessoryRectangular) {
            Summary {
                \.$source
                \.$target
                \.$period
            }
        } otherwise: {
            Summary {
                \.$source
                \.$target
                \.$period
                \.$tint
            }
        }
    }
}

/// Фон «Графика»: по движению курса (зелёный — рост, красный — падение) или обычный.
enum ChartTint: String, AppEnum {
    case trend, standard

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Color"
    static let caseDisplayRepresentations: [ChartTint: DisplayRepresentation] = [
        .trend: "Chart color",
        .standard: "Default",
    ]
}

struct ChartPoint: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

struct ChartEntry: TimelineEntry {
    let date: Date
    let source: String
    let target: String
    let rate: Double?
    let points: [ChartPoint]
    let period: ChartPeriod
    let numberLocale: Locale
    let isRightToLeft: Bool
    let isLocked: Bool
    /// Окрашивать фон по движению курса.
    let isTinted: Bool

    /// Изменение за период: последняя точка к первой.
    var change: Double? {
        guard points.count >= 2, let first = points.first?.value, let last = points.last?.value, first > 0 else { return nil }
        return last / first - 1
    }

    /// Цвет линии: рост — зелёный, падение — красный; без истории — nil.
    var trendColor: UInt32? {
        guard let change else { return nil }
        return change >= 0 ? ChartColor.up : ChartColor.down
    }

    /// Фон — цвет линии или обычный, по настройке «Цвет».
    var tint: UInt32? { isTinted ? trendColor : nil }

    func format(_ value: Double) -> String {
        CompactZeros.apply(AmountFormat.rate(value, locale: numberLocale), locale: numberLocale)
    }

    static func make(_ config: ChartIntent, snapshot: WidgetSnapshot?, rates: SharedRates, date: Date = .now) -> ChartEntry {
        let app = snapshot ?? .preview
        let requested = [config.source?.code, config.target?.code].compactMap { $0 }
        let isLocked = !requested.allSatisfy(app.allows)
        let source = isLocked ? app.sourceCode : config.source?.code ?? app.sourceCode
        var target = (isLocked ? nil : config.target?.code) ?? app.codes.first(where: { $0 != source }) ?? "EUR"
        if target == source { target = source == "USD" ? "EUR" : "USD" }
        return ChartEntry(
            date: date,
            source: source,
            target: target,
            rate: rates.rate(from: source, to: target),
            points: rates.series(from: source, to: target, period: config.period.period, now: date)
                .map { ChartPoint(date: $0.date, value: $0.value) },
            period: config.period,
            numberLocale: app.numberLocale,
            isRightToLeft: app.isRightToLeft,
            isLocked: isLocked,
            isTinted: config.tint == .trend
        )
    }
}

/// Цвета роста и падения — системные зелёный и красный.
enum ChartColor {
    static let up: UInt32 = 0x30D158
    static let down: UInt32 = 0xFF453A
}

struct ChartProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ChartEntry {
        .make(ChartIntent(), snapshot: .preview, rates: .preview)
    }

    func snapshot(for configuration: ChartIntent, in context: Context) async -> ChartEntry {
        if context.isPreview, !WidgetRates.hasData {
            return .make(configuration, snapshot: .preview, rates: .preview)
        }
        return .make(configuration, snapshot: WidgetSnapshot.load(), rates: SharedRates.load() ?? .empty)
    }

    func timeline(for configuration: ChartIntent, in context: Context) async -> Timeline<ChartEntry> {
        let rates = await WidgetRates.current()
        let entry = ChartEntry.make(configuration, snapshot: WidgetSnapshot.load(), rates: rates)
        return Timeline(entries: [entry], policy: .after(WidgetRates.nextUpdate))
    }
}

struct ChartWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ChartWidget", intent: ChartIntent.self, provider: ChartProvider()) { entry in
            ChartWidgetView(entry: entry)
        }
        .configurationDisplayName("Rate chart")
        .description("A pair with a chart for a day, week or month")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct ChartWidgetView: View {
    let entry: ChartEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .environment(\.layoutDirection, entry.isRightToLeft ? .rightToLeft : .leftToRight)
            .modifier(TintedWidget(tint: entry.tint))
    }

    @ViewBuilder
    private var content: some View {
        if let rate = entry.rate {
            switch family {
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(verbatim: "\(entry.source) → \(entry.target)").font(.caption2.weight(.semibold))
                        Spacer(minLength: 2)
                        Text(verbatim: entry.format(rate)).font(.caption.weight(.bold).monospacedDigit()).widgetAccentable()
                    }
                    RateChart(points: entry.points, color: .primary)
                }
            case .systemMedium:
                HStack(spacing: 14) {
                    info(rate, badgeSize: 34)
                        .frame(width: 130)
                    RateChart(points: entry.points, color: lineColor)
                        .padding(.top, 22)
                }
                // Период — в правом верхнем углу виджета, над графиком.
                .overlay(alignment: .topTrailing) { periodMark }
            default:
                VStack(alignment: .leading, spacing: 4) {
                    info(rate, badgeSize: 26)
                    RateChart(points: entry.points, color: lineColor)
                }
            }
        } else {
            EmptyWidgetView(family: family)
        }
    }

    /// Рост — зелёный, падение — красный, без истории — акцент.
    private var lineColor: Color {
        entry.trendColor.map(WidgetColor.rgb) ?? WidgetColor.accent
    }

    @ViewBuilder private var periodMark: some View {
        if entry.isLocked {
            ProMark()
        } else {
            Text(verbatim: entry.period.shortLabel)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
    }

    private func info(_ rate: Double, badgeSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 4) {
                PairBadges(source: entry.source, target: entry.target, size: badgeSize)
                Spacer(minLength: 0)
                // В среднем виджете период стоит в углу всего виджета.
                if family != .systemMedium { periodMark }
            }
            if family == .systemMedium { Spacer(minLength: 2) }
            Text(verbatim: "1 \(entry.source) =")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(verbatim: "\(entry.format(rate)) \(entry.target)")
                .font(.headline.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if let change = entry.change {
                Text(change, format: .percent.precision(.fractionLength(2)).sign(strategy: .always()).locale(entry.numberLocale))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(change >= 0 ? Color.green : Color.red)
            }
        }
    }
}

/// Линия курса с заливкой под ней; пока точек мало — подпись «Собираем историю».
struct RateChart: View {
    let points: [ChartPoint]
    let color: Color

    var body: some View {
        if points.count >= 3 {
            let values = points.map(\.value)
            let low = values.min() ?? 0
            let high = values.max() ?? 1
            // Чтобы почти ровная линия не выглядела пилой, держим минимальный размах.
            let pad = max((high - low) * 0.15, high * 0.0005)
            Chart(points) { point in
                AreaMark(
                    x: .value("Time", point.date),
                    yStart: .value("Low", low - pad),
                    yEnd: .value("Rate", point.value)
                )
                .foregroundStyle(LinearGradient(colors: [color.opacity(0.28), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.monotone)
                LineMark(x: .value("Time", point.date), y: .value("Rate", point.value))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .chartYScale(domain: (low - pad)...(high + pad))
        } else {
            Text("Collecting history…")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - «Крипто-рынок»

enum CryptoMode: String, AppEnum {
    case top, gainers, losers

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Show"
    static let caseDisplayRepresentations: [CryptoMode: DisplayRepresentation] = [
        .top: "Top coins",
        .gainers: "Top gainers",
        .losers: "Top losers",
    ]
}

struct CryptoIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Crypto market"
    static let description = IntentDescription("Top coins with the change over a day")

    @Parameter(title: "Show", default: .top)
    var mode: CryptoMode

    @Parameter(title: "Price in")
    var quote: CurrencyEntity?

    @Parameter(title: "Color", default: .standard)
    var tint: WidgetTint

    static var parameterSummary: some ParameterSummary {
        When(widgetFamily: .equalTo, .accessoryRectangular) {
            Summary {
                \.$mode
                \.$quote
            }
        } otherwise: {
            Summary {
                \.$mode
                \.$quote
                \.$tint
            }
        }
    }
}

struct CoinRow: Identifiable {
    let code: String
    let name: String
    let price: String
    /// Изменение за 24 часа в процентах.
    let change: Double?
    var id: String { code }
}

struct CryptoEntry: TimelineEntry {
    let date: Date
    let rows: [CoinRow]
    let quote: String
    let numberLocale: Locale
    let isRightToLeft: Bool
    /// Криптовалюты — только с Pro, как в приложении.
    let isLocked: Bool
    let tint: UInt32?

    static func make(_ config: CryptoIntent, snapshot: WidgetSnapshot?, rates: SharedRates, date: Date = .now) -> CryptoEntry {
        let app = snapshot ?? .preview
        let fallbackQuote = CurrencyCatalog.isCrypto(app.sourceCode) ? "USD" : app.sourceCode
        var quote = config.quote?.code ?? fallbackQuote
        if CurrencyCatalog.isCrypto(quote) { quote = "USD" }

        var coins = CryptoAsset.all.map(\.code).filter { rates.crypto[$0] != nil }
        switch config.mode {
        case .top:
            break
        case .gainers:
            coins = coins.filter { rates.cryptoChanges[$0] != nil }
                .sorted { (rates.cryptoChanges[$0] ?? 0) > (rates.cryptoChanges[$1] ?? 0) }
        case .losers:
            coins = coins.filter { rates.cryptoChanges[$0] != nil }
                .sorted { (rates.cryptoChanges[$0] ?? 0) < (rates.cryptoChanges[$1] ?? 0) }
        }
        let rows = coins.prefix(8).map { code in
            CoinRow(
                code: code,
                name: CurrencyCatalog.name(for: code, locale: app.language),
                price: rates.rate(from: code, to: quote)
                    .map { CompactZeros.apply(AmountFormat.amount($0, locale: app.numberLocale, decimalPlaces: nil), locale: app.numberLocale) } ?? "—",
                change: rates.cryptoChanges[code]
            )
        }
        let tintCode: String? = switch config.tint {
        case .standard: nil
        case .main: rows.first?.code
        case .second: quote
        }
        return CryptoEntry(
            date: date,
            rows: Array(rows),
            quote: quote,
            numberLocale: app.numberLocale,
            isRightToLeft: app.isRightToLeft,
            isLocked: !app.isPro,
            tint: tintCode.map { CurrencyCatalog.color(for: $0) ?? WidgetTintFallback.color }
        )
    }
}

struct CryptoProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CryptoEntry {
        .make(CryptoIntent(), snapshot: .preview, rates: .preview)
    }

    func snapshot(for configuration: CryptoIntent, in context: Context) async -> CryptoEntry {
        if context.isPreview, !WidgetRates.hasData {
            return .make(configuration, snapshot: .preview, rates: .preview)
        }
        return .make(configuration, snapshot: WidgetSnapshot.load(), rates: SharedRates.load() ?? .empty)
    }

    func timeline(for configuration: CryptoIntent, in context: Context) async -> Timeline<CryptoEntry> {
        let rates = await WidgetRates.current()
        let entry = CryptoEntry.make(configuration, snapshot: WidgetSnapshot.load(), rates: rates)
        return Timeline(entries: [entry], policy: .after(WidgetRates.nextUpdate))
    }
}

struct CryptoWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "CryptoWidget", intent: CryptoIntent.self, provider: CryptoProvider()) { entry in
            CryptoWidgetView(entry: entry)
        }
        .configurationDisplayName("Crypto market")
        .description("Top coins with the change over a day")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

struct CryptoWidgetView: View {
    let entry: CryptoEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .environment(\.layoutDirection, entry.isRightToLeft ? .rightToLeft : .leftToRight)
            .modifier(TintedWidget(tint: entry.tint))
    }

    @ViewBuilder
    private var content: some View {
        if entry.rows.isEmpty {
            EmptyWidgetView(family: family)
        } else {
            switch family {
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(entry.rows.prefix(3)) { row in
                        HStack(spacing: 4) {
                            Text(verbatim: row.code).font(.caption.weight(.semibold)).lineLimit(1).fixedSize()
                            Spacer(minLength: 2)
                            changeText(row.change).font(.caption.monospacedDigit())
                        }
                    }
                }
            case .systemMedium:
                VStack(spacing: 6) {
                    header
                    let rows = Array(entry.rows.prefix(6))
                    HStack(alignment: .top, spacing: 12) {
                        column(Array(rows.prefix(3)))
                        column(Array(rows.dropFirst(3)))
                    }
                }
            case .systemLarge:
                VStack(spacing: 6) {
                    header
                    column(Array(entry.rows.prefix(8)), showsNames: true)
                    Spacer(minLength: 0)
                }
            default:
                VStack(spacing: 6) {
                    header
                    column(Array(entry.rows.prefix(3)))
                }
            }
        }
    }

    /// «Крипто-рынок» и плашка «в USD» — в какой валюте цены; PRO, если подписки нет.
    private var header: some View {
        HStack(spacing: 5) {
            // В маленьком виджете места мало — только валюта цен.
            if family != .systemSmall {
                Text("Crypto market").font(.caption.weight(.bold)).lineLimit(1)
            }
            Spacer(minLength: 2)
            if entry.isLocked {
                ProMark()
            } else {
                // Цены — в этой валюте.
                (Text("Price in") + Text(verbatim: " \(entry.quote)"))
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .frame(height: 20)
                    .background(Capsule().fill(Color.primary.opacity(0.12)))
            }
        }
        .font(.caption)
    }

    private func column(_ rows: [CoinRow], showsNames: Bool = false) -> some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                HStack(spacing: 6) {
                    CurrencyBadge(code: row.code, size: showsNames ? 28 : 22)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: row.code).font(.caption.weight(.semibold)).lineLimit(1).fixedSize()
                        if showsNames {
                            Text(verbatim: row.name).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 2)
                    VStack(alignment: .trailing, spacing: 0) {
                        // Без подписки цена скрыта — видно только, что рынок растёт или падает.
                        Text(verbatim: entry.isLocked ? "•••" : row.price)
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        changeText(row.change).font(.caption2.weight(.semibold).monospacedDigit())
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private func changeText(_ change: Double?) -> some View {
        Group {
            if let change {
                Text((change / 100), format: .percent.precision(.fractionLength(1)).sign(strategy: .always()).locale(entry.numberLocale))
                    .foregroundStyle(change >= 0 ? Color.green : Color.red)
            } else {
                Text(verbatim: "—").foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
    }
}

// MARK: - «Путешествие»

struct TravelIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Travel"
    static let description = IntentDescription("The currency of the country you are in, next to your home currency")

    @Parameter(title: "Home currency")
    var home: CurrencyEntity?

    @Parameter(title: "Color", default: .standard)
    var tint: WidgetTint
}

struct TravelEntry: TimelineEntry {
    enum State {
        /// Страну ещё не определили (приложение не открывали или нет доступа к геолокации).
        case unknown
        /// Вы дома: местная валюта совпадает с домашней.
        case home(String)
        /// В поездке: местная валюта и курс к домашней.
        case abroad(local: String, rate: Double?)
    }

    var date: Date
    let state: State
    let country: String?
    let home: String
    let numberLocale: Locale
    let language: Locale
    let isRightToLeft: Bool
    let isLocked: Bool
    let tint: UInt32?
    /// Сумма в местной валюте, выбранная кнопками; nil — шаг по умолчанию для этой валюты.
    var chosenAmount: Double? = nil
    /// Первый кадр после смены страны: облака и самолёт, затем виджет «прилетает» к курсу.
    var isArriving = false

    var countryName: String? {
        country.flatMap { language.localizedString(forRegionCode: $0) }
    }

    func format(_ value: Double) -> String {
        CompactZeros.apply(AmountFormat.rate(value, locale: numberLocale), locale: numberLocale)
    }

    /// Крупные суммы — без копеек: «588.55…» не помещалось в строку.
    func formatAmount(_ value: Double) -> String {
        CompactZeros.apply(AmountFormat.amount(value, locale: numberLocale, decimalPlaces: value >= 100 ? 0 : nil), locale: numberLocale)
    }

    /// Ключ состояния кнопок суммы — своя запись для каждой местной валюты.
    static func stateKey(local: String) -> String { "travelState.\(local)" }

    /// Шаг сумм под валюту: у иены — 100, 1 000…, у евро — 1, 10…
    static func baseStep(rate: Double) -> Double {
        rate > 0 ? pow(10, max(0, floor(log10(1 / rate)))) : 1
    }

    /// Варианты сумм: шаг, ×10, ×100, ×1000 — как 1 / 10 / 100 / 1K у «Курса».
    static func choices(rate: Double) -> [Double] {
        let base = baseStep(rate: rate)
        return [base, base * 10, base * 100, base * 1000]
    }

    /// Выбранная сумма, если она из текущих вариантов, иначе — шаг по умолчанию.
    func amount(rate: Double) -> Double {
        let options = Self.choices(rate: rate)
        return chosenAmount.flatMap { options.contains($0) ? $0 : nil } ?? options[0]
    }

    static func make(_ config: TravelIntent, snapshot: WidgetSnapshot?, rates: SharedRates, date: Date = .now) -> TravelEntry {
        let app = snapshot ?? .preview
        let local = snapshot == nil ? "TRY" : app.countryCurrency
        let country = snapshot == nil ? "TR" : app.countryCode
        let fallbackHome = app.codes.first { $0 != local && !CurrencyCatalog.isCrypto($0) } ?? "USD"
        let home = config.home?.code ?? fallbackHome
        let state: State
        if let local {
            state = local == home ? .home(local) : .abroad(local: local, rate: rates.rate(from: local, to: home))
        } else {
            state = .unknown
        }
        let isLocked: Bool = {
            guard case .abroad(let local, _) = state else { return false }
            return !app.allows(local) || !app.allows(home)
        }()
        let tintCode: String? = switch config.tint {
        case .standard: nil
        case .main: local ?? home
        case .second: home
        }
        // Сумма из кнопок хранится как у «Курса»: изменение через PairAmountIntent.
        let chosen: Double? = local.flatMap { code in
            WidgetSnapshot.defaults?.data(forKey: stateKey(local: code)) != nil ? PairState.load(stateKey(local: code)).amount : nil
        }
        return TravelEntry(
            date: date,
            state: state,
            country: country,
            home: home,
            numberLocale: app.numberLocale,
            language: app.language,
            isRightToLeft: app.isRightToLeft,
            isLocked: isLocked,
            tint: tintCode.map { CurrencyCatalog.color(for: $0) ?? WidgetTintFallback.color },
            chosenAmount: chosen
        )
    }
}

/// Когда показать полёт: прилёт в новую страну или смена суммы кнопкой.
enum TravelArrival {
    private static let key = "travel.lastPair"

    /// Сменилась ли пара «местная → домашняя» с прошлого показа (новая страна или другая
    /// домашняя валюта в настройках); запоминает текущую.
    static func isNew(_ entry: TravelEntry) -> Bool {
        guard case .abroad(let local, _?) = entry.state, !entry.isLocked else { return false }
        let pair = "\(local)-\(entry.home)"
        let defaults = WidgetSnapshot.defaults
        guard defaults?.string(forKey: key) != pair else { return false }
        defaults?.set(pair, forKey: key)
        return true
    }
}

struct TravelProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TravelEntry {
        .make(TravelIntent(), snapshot: nil, rates: .preview)
    }

    func snapshot(for configuration: TravelIntent, in context: Context) async -> TravelEntry {
        if context.isPreview, !WidgetRates.hasData {
            return .make(configuration, snapshot: nil, rates: .preview)
        }
        return .make(configuration, snapshot: WidgetSnapshot.load(), rates: SharedRates.load() ?? .empty)
    }

    func timeline(for configuration: TravelIntent, in context: Context) async -> Timeline<TravelEntry> {
        let rates = await WidgetRates.current()
        let entry = TravelEntry.make(configuration, snapshot: WidgetSnapshot.load(), rates: rates)
        // Новая страна или другая домашняя валюта: сначала кадр с облаками и самолётом, через пару секунд — курс.
        // В виджете анимируется только смена кадров: появляются облака, самолёт влетает слева,
        // затем улетает вправо, и курс проявляется.
        if TravelArrival.isNew(entry) {
            var flight = entry
            flight.isArriving = true
            var landed = entry
            landed.date = entry.date.addingTimeInterval(2.5)
            return Timeline(entries: [flight, landed], policy: .after(WidgetRates.nextUpdate))
        }
        return Timeline(entries: [entry], policy: .after(WidgetRates.nextUpdate))
    }
}

struct TravelWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "TravelWidget", intent: TravelIntent.self, provider: TravelProvider()) { entry in
            TravelWidgetView(entry: entry)
        }
        .configurationDisplayName("Travel")
        .description("The currency of the country you are in, next to your home currency")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TravelWidgetView: View {
    let entry: TravelEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        // Только встроенные переходы: свои модификаторы-переходы виджет не анимирует.
        // Облака и самолёт — во весь виджет, поэтому `.move` проводит самолёт через весь виджет.
        ZStack {
            if entry.isArriving {
                SkyClouds()
                    .transition(.opacity)
                FlyingPlane(country: entry.countryName)
                    .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
            } else {
                content
                    .transition(.opacity)
            }
        }
        // Плавно и без пружины: виджет ограничивает анимацию двумя секундами.
        .animation(.easeInOut(duration: 1.6), value: entry.isArriving)
        .environment(\.layoutDirection, entry.isRightToLeft ? .rightToLeft : .leftToRight)
        .modifier(TintedWidget(tint: entry.tint))
    }

    @ViewBuilder
    private var content: some View {
        switch entry.state {
        case .abroad(let local, let rate?) where !entry.isLocked:
            if family == .systemMedium {
                // Обе колонки одной высоты: верх списка — вровень с флагом.
                HStack(alignment: .top, spacing: 14) {
                    abroad(local: local, rate: rate)
                    Divider()
                    amounts(local: local, rate: rate)
                }
                .padding(.vertical, 2)
            } else {
                abroad(local: local, rate: rate)
            }
        case .abroad(let local, _):
            message(code: local, text: entry.isLocked ? "Any currency with Pro" : "Open Cento to choose currencies", showsPro: entry.isLocked)
        case .home(let code):
            message(code: code, text: "On a trip, the local currency will appear here", showsPro: false)
        case .unknown:
            message(code: entry.home, text: "Open Cento on your trip to detect the country", showsPro: false)
        }
    }

    /// Флаг страны с названием, «1 TRY =» и курс к домашней валюте, ниже — обратный курс.
    private func abroad(local: String, rate: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                CurrencyBadge(code: local, size: 26)
                Text(verbatim: entry.countryName ?? local)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Image(systemName: "airplane")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            // Выбранная сумма — как у «Курса»: кнопками в маленьком, строкой списка в среднем.
            let amount = entry.amount(rate: rate)
            Text(verbatim: "\(AmountFormat.amount(amount, locale: entry.numberLocale, decimalPlaces: 0)) \(local) =")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary.opacity(0.7))
                .lineLimit(1)
                .contentTransition(.numericText())
            Text(verbatim: "\(amount == 1 ? entry.format(rate) : entry.formatAmount(amount * rate)) \(entry.home)")
                .font(.title3.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .contentTransition(.numericText())
            Spacer(minLength: 4)
            if family == .systemSmall {
                AmountChips(
                    pairKey: TravelEntry.stateKey(local: local),
                    selected: amount,
                    locale: entry.numberLocale,
                    amounts: TravelEntry.choices(rate: rate)
                )
            } else if rate > 0 {
                Text(verbatim: "1 \(entry.home) = \(entry.format(1 / rate)) \(local)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// Ходовые суммы в местной валюте — сколько это дома. Как у «Курса»: нажатие на строку
    /// показывает эту сумму слева.
    private func amounts(local: String, rate: Double) -> some View {
        let options = TravelEntry.choices(rate: rate)
        let selected = entry.amount(rate: rate)
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(options, id: \.self) { amount in
                if amount != options[0] { Divider().opacity(0.5) }
                Button(intent: PairAmountIntent(pair: TravelEntry.stateKey(local: local), amount: amount)) {
                    HStack(spacing: 4) {
                        Text(verbatim: "\(AmountFormat.amount(amount, locale: entry.numberLocale, decimalPlaces: 0)) \(local)")
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 4)
                        Text(verbatim: "\(entry.formatAmount(amount * rate)) \(entry.home)")
                            .fontWeight(.semibold)
                            .foregroundStyle(amount == selected ? WidgetColor.accent : Color.primary)
                    }
                    // Один размер шрифта у всех строк — без поштучного сжатия.
                    .font(.caption.monospacedDigit())
                    .lineLimit(1)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func message(code: String, text: LocalizedStringKey, showsPro: Bool) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                CurrencyBadge(code: code, size: 32)
                Image(systemName: "airplane").foregroundStyle(.secondary)
                if showsPro { ProMark() }
            }
            Text(text)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview(as: .systemMedium) {
    ChartWidget()
} timeline: {
    ChartEntry.make(ChartIntent(), snapshot: .preview, rates: .preview)
}

#Preview(as: .systemMedium) {
    CryptoWidget()
} timeline: {
    CryptoEntry.make(CryptoIntent(), snapshot: .preview, rates: .preview)
}

#Preview(as: .systemMedium) {
    TravelWidget()
} timeline: {
    TravelEntry.make(TravelIntent(), snapshot: nil, rates: .preview)
}

/// Облака на весь виджет — фон полёта.
private struct SkyClouds: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                cloud(34, x: -0.32, y: -0.22, opacity: 0.55, in: proxy.size)
                cloud(22, x: 0.30, y: -0.30, opacity: 0.4, in: proxy.size)
                cloud(28, x: 0.36, y: 0.26, opacity: 0.5, in: proxy.size)
                cloud(18, x: -0.38, y: 0.30, opacity: 0.35, in: proxy.size)
                cloud(24, x: 0.02, y: -0.36, opacity: 0.3, in: proxy.size)
            }
        }
    }

    /// Облако на доле ширины и высоты от центра.
    private func cloud(_ size: CGFloat, x: CGFloat, y: CGFloat, opacity: Double, in area: CGSize) -> some View {
        Image(systemName: "cloud.fill")
            .font(.system(size: size))
            .foregroundStyle(Color.primary.opacity(opacity * 0.5))
            .position(x: area.width * (0.5 + x), y: area.height * (0.5 + y))
    }
}

/// Самолёт с названием страны по центру; рамка на весь виджет — чтобы перелёт шёл от края до края.
private struct FlyingPlane: View {
    let country: String?

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "airplane")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(-12))
            if let country {
                Text(verbatim: country)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
