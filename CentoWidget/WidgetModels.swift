import Foundation
import WidgetKit

/// Курсы для виджета: из общего контейнера, а если приложение давно не открывали — свежие из сети.
enum WidgetRates {
    static func current(now: Date = .now) async -> SharedRates {
        var rates = SharedRates.load() ?? .empty
        // Фиат у поставщика обновляется раз в сутки, криптовалюты — постоянно.
        let needsFiat = now.timeIntervalSince(rates.fiatFetchedAt) > 3 * 3600
        let needsCrypto = now.timeIntervalSince(rates.cryptoFetchedAt) > 15 * 60
        guard needsFiat || needsCrypto else { return rates }

        let service = RatesService()
        let fiat: RateSet? = needsFiat ? (try? await service.fetchFiat()) : nil
        let crypto: RateSet? = needsCrypto ? (try? await service.fetchCrypto()) : nil
        guard fiat != nil || crypto != nil else { return rates }

        rates.record(fiat: fiat?.rates, fiatAt: fiat?.fetchedAt, crypto: crypto?.rates, cryptoAt: crypto?.fetchedAt, now: now)
        rates.save()
        return rates
    }

    static var hasData: Bool {
        guard let rates = SharedRates.load() else { return false }
        return !rates.fiat.isEmpty || !rates.crypto.isEmpty
    }

    /// Следующее обновление: курсы криптовалют меняются постоянно.
    static var nextUpdate: Date { .now.addingTimeInterval(30 * 60) }
}

/// Длинные нули после запятой — как в крипто-приложениях: 0.000007345 → 0.0₅7345,
/// маленькая цифра — сколько нулей идёт после запятой. Так мелкие суммы помещаются в виджет.
enum CompactZeros {
    private static let subscripts: [Character] = ["₀", "₁", "₂", "₃", "₄", "₅", "₆", "₇", "₈", "₉"]

    static func apply(_ text: String, locale: Locale) -> String {
        let separator = locale.decimalSeparator ?? "."
        guard let range = text.range(of: separator) else { return text }
        let fraction = text[range.upperBound...]
        let zeros = fraction.prefix { $0 == "0" }.count
        // Сворачиваем от трёх нулей и только если после них есть значащие цифры.
        guard zeros >= 3, fraction.count > zeros else { return text }
        let count = String(String(zeros).compactMap { $0.wholeNumberValue.map { subscripts[$0] } })
        return String(text[..<range.upperBound]) + "0" + count + String(fraction.dropFirst(zeros))
    }
}

// MARK: - «Мои валюты»

struct RateRow: Identifiable, Equatable {
    let code: String
    let name: String
    let value: String
    let isSource: Bool

    var id: String { code }
}

struct ListEntry: TimelineEntry {
    let date: Date
    let rows: [RateRow]
    let isRightToLeft: Bool
    /// Выбраны валюты, недоступные без подписки: виджет показывает доступные и пометку Pro.
    let isLocked: Bool

    static func make(_ config: ListIntent, snapshot: WidgetSnapshot?, rates: SharedRates, date: Date = .now) -> ListEntry {
        let app = snapshot ?? .preview
        // Выбранное в настройках виджета — в своём порядке, без привязки к списку приложения.
        let requestedSource = config.source?.id
        let requestedOthers = config.others
        let isConfigured = requestedSource != nil || !requestedOthers.isEmpty
        // Без подписки — только бесплатные валюты и не больше, чем в списке приложения.
        let allowedSource = requestedSource.flatMap { app.allows($0) ? $0 : nil }
        let allowedOthers = requestedOthers.filter(app.allows)
        let isLocked = allowedOthers.count < requestedOthers.count || (requestedSource != nil && allowedSource == nil)

        let source: String
        var codes: [String]
        if isConfigured, let base = allowedSource ?? allowedOthers.first {
            source = base
            // Выбрана только основная валюта — остальные берём из приложения.
            let others = allowedOthers.isEmpty ? app.codes : allowedOthers
            codes = [base] + others.filter { $0 != base }
        } else {
            source = app.sourceCode
            codes = app.codes
            if !codes.contains(source) { codes.insert(source, at: 0) }
        }
        if !app.isPro { codes = Array(codes.prefix(WidgetSnapshot.freeLimit)) }
        // Сумма из приложения подходит, только если и валюта ввода та же.
        let amount = config.amount ?? (source == app.sourceCode ? app.amount : 1)

        let rows = codes.map { code in
            let value = rates.rate(from: source, to: code)
                .map { CompactZeros.apply(AmountFormat.amount($0 * amount, locale: app.numberLocale, decimalPlaces: app.decimalPlaces), locale: app.numberLocale) }
            return RateRow(
                code: code,
                name: CurrencyCatalog.name(for: code, locale: app.language),
                value: value ?? "—",
                isSource: code == source
            )
        }
        let hasRates = !rates.fiat.isEmpty || !rates.crypto.isEmpty
        return ListEntry(date: date, rows: hasRates ? rows : [], isRightToLeft: app.isRightToLeft, isLocked: isLocked)
    }
}

struct ListProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ListEntry {
        .make(ListIntent(), snapshot: .preview, rates: .preview)
    }

    func snapshot(for configuration: ListIntent, in context: Context) async -> ListEntry {
        // В галерее до первого запуска приложения — пример с курсами.
        if context.isPreview, !WidgetRates.hasData {
            return .make(configuration, snapshot: .preview, rates: .preview)
        }
        return .make(configuration, snapshot: WidgetSnapshot.load(), rates: SharedRates.load() ?? .empty)
    }

    func timeline(for configuration: ListIntent, in context: Context) async -> Timeline<ListEntry> {
        let rates = await WidgetRates.current()
        let entry = ListEntry.make(configuration, snapshot: WidgetSnapshot.load(), rates: rates)
        return Timeline(entries: [entry], policy: .after(WidgetRates.nextUpdate))
    }
}

// MARK: - «Курс»

struct PairEntry: TimelineEntry {
    let date: Date
    let source: String
    let target: String
    /// Сколько `target` стоит 1 `source`; nil — курсов ещё нет.
    let rate: Double?
    /// Изменение за сутки: 0.01 — рост на 1 %.
    let change: Double?
    let updatedAt: Date?
    let numberLocale: Locale
    let isRightToLeft: Bool
    /// Выбранная пара недоступна без подписки: показана пара из приложения и пометка Pro.
    let isLocked: Bool

    func format(_ value: Double) -> String {
        CompactZeros.apply(AmountFormat.rate(value, locale: numberLocale), locale: numberLocale)
    }

    func formatAmount(_ value: Double) -> String {
        CompactZeros.apply(AmountFormat.amount(value, locale: numberLocale, decimalPlaces: nil), locale: numberLocale)
    }

    static func make(_ config: PairIntent, snapshot: WidgetSnapshot?, rates: SharedRates, date: Date = .now) -> PairEntry {
        let app = snapshot ?? .preview
        let requested = [config.source?.id, config.target?.id].compactMap { $0 }
        let isLocked = !requested.allSatisfy(app.allows)
        // Без подписки платная валюта в паре заменяется парой из приложения.
        let source = isLocked ? app.sourceCode : config.source?.id ?? app.sourceCode
        var target = (isLocked ? nil : config.target?.id) ?? app.codes.first(where: { $0 != source }) ?? "EUR"
        if target == source { target = source == "USD" ? "EUR" : "USD" }
        let hasRates = !rates.fiat.isEmpty || !rates.crypto.isEmpty
        return PairEntry(
            date: date,
            source: source,
            target: target,
            rate: rates.rate(from: source, to: target),
            change: rates.change(from: source, to: target, now: date),
            updatedAt: hasRates ? rates.fetchedAt : nil,
            numberLocale: app.numberLocale,
            isRightToLeft: app.isRightToLeft,
            isLocked: isLocked
        )
    }
}

struct PairProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PairEntry {
        .make(PairIntent(), snapshot: .preview, rates: .preview)
    }

    func snapshot(for configuration: PairIntent, in context: Context) async -> PairEntry {
        if context.isPreview, !WidgetRates.hasData {
            return .make(configuration, snapshot: .preview, rates: .preview)
        }
        return .make(configuration, snapshot: WidgetSnapshot.load(), rates: SharedRates.load() ?? .empty)
    }

    func timeline(for configuration: PairIntent, in context: Context) async -> Timeline<PairEntry> {
        let rates = await WidgetRates.current()
        let entry = PairEntry.make(configuration, snapshot: WidgetSnapshot.load(), rates: rates)
        return Timeline(entries: [entry], policy: .after(WidgetRates.nextUpdate))
    }
}
