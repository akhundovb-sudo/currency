import Charts
import SwiftUI

/// Настройки → «Виджеты»: все виджеты Cento с настоящими курсами и как добавить их на экран.
/// Вид виджетов повторяет CentoWidget: его представления зависят от `widgetFamily`,
/// а это значение в приложении не задать.
struct WidgetsGuideView: View {
    @Environment(RatesStore.self) private var store
    /// Сохранённые курсы; пока их нет — примерные, как в галерее виджетов.
    @State private var rates = SharedRates.preview

    private let steps: [L10n.Key] = [.widgetStep1, .widgetStep2, .widgetStep3, .widgetStep4]

    private var data: WidgetPreviewData {
        let source = store.sourceCode
        let others = store.selectedCodes.filter { $0 != source }
        let local = WidgetSnapshot.load()?.countryCurrency.flatMap { $0 == source ? nil : $0 }
        return WidgetPreviewData(
            rates: rates,
            source: source,
            target: others.first ?? (source == "USD" ? "EUR" : "USD"),
            codes: [source] + others,
            local: local ?? (source == "TRY" ? "EUR" : "TRY"),
            locale: store.language.locale
        )
    }

    var body: some View {
        let data = data

        ScrollView {
            // Между виджетами ровный отступ.
            VStack(alignment: .leading, spacing: 32) {
                WidgetSection(title: .widgetPair, description: .widgetPairInfo, isPro: false) {
                    WidgetTile(.small) { PairSmall(data: data) }
                    WidgetTile(.medium) { PairMedium(data: data) }
                }
                WidgetSection(title: .widgetList, description: .widgetListInfo, isPro: true) {
                    WidgetTile(.small) { ListPreview(data: data, showsNames: false) }
                    WidgetTile(.medium) { ListPreview(data: data, showsNames: true) }
                }
                WidgetSection(title: .widgetChart, description: .widgetChartInfo, isPro: true) {
                    WidgetTile(.small) { ChartSmall(data: data) }
                    WidgetTile(.medium) { ChartMedium(data: data) }
                }
                WidgetSection(title: .widgetCrypto, description: .widgetCryptoInfo, isPro: true) {
                    WidgetTile(.small) { CryptoPreview(data: data, columns: 1) }
                    WidgetTile(.medium) { CryptoPreview(data: data, columns: 2) }
                }
                WidgetSection(title: .widgetTravel, description: .widgetTravelInfo, isPro: true) {
                    WidgetTile(.small) { TravelSmall(data: data) }
                    WidgetTile(.medium) { TravelMedium(data: data) }
                }
                howTo
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            if let saved = SharedRates.load(), !saved.fiat.isEmpty { rates = saved }
        }
        .modifier(SettingsPage(title: L(.widgets)))
    }

    private var howTo: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L(.widgetHowTo)).font(.headline)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text(verbatim: "\(index + 1)")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 28, height: 28)
                            .background(Color.primary.opacity(0.07), in: Circle())
                        Text(L(step))
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal, 16)
    }
}

/// Виджет: название, тариф и описание; под ними размеры виджета на фоне «экрана Домой», листаются вбок.
private struct WidgetSection<Tiles: View>: View {
    let title: L10n.Key
    let description: L10n.Key
    let isPro: Bool
    @ViewBuilder let tiles: Tiles

    private let wallpaperShape = RoundedRectangle(cornerRadius: 28, style: .continuous)

    /// Фон «экрана Домой»: светлая голубо-сиреневая дымка, в тёмной теме — приглушённая.
    private static var wallpaper: LinearGradient { LinearGradient(
        colors: [Color.dynamic(light: 0xCFD8EA, dark: 0x262C3A), Color.dynamic(light: 0xE6DCEF, dark: 0x30283A)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    ) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(L(title)).font(.headline)
                    if isPro {
                        ProBadge()
                    } else {
                        Text(L(.widgetFree))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.secondaryLabel)
                            .padding(.horizontal, 8)
                            .frame(height: 22)
                            .background(Color.primary.opacity(0.07), in: Capsule())
                    }
                }
                Text(L(description))
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryLabel)
            }
            .accessibilityElement(children: .combine)

            // Превью лежат на мягком фоне, как на экране «Домой».
            ScrollView(.horizontal) {
                HStack(spacing: 12) { tiles }
                    .padding(12)
            }
            .scrollIndicators(.hidden)
            .background(Self.wallpaper, in: wallpaperShape)
            .clipShape(wallpaperShape)
        }
        // Без белой карточки: заголовок на фоне страницы, под ним только «экран Домой».
        .padding(.horizontal, 16)
    }
}

/// Карточка размера настоящего виджета. Текст не масштабируется — как на экране «Домой».
private struct WidgetTile<Content: View>: View {
    enum Size {
        case small, medium
        var width: CGFloat { self == .small ? 158 : 338 }
    }

    let size: Size
    @ViewBuilder let content: Content

    init(_ size: Size, @ViewBuilder content: () -> Content) {
        self.size = size
        self.content = content()
    }

    private let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    var body: some View {
        content
            .padding(14)
            .frame(width: size.width, height: 158)
            .background {
                // На фоне «экрана Домой» — как настоящий виджет: своя плашка и лёгкая тень.
                shape
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(shape.strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
            }
            .dynamicTypeSize(.large)
            .accessibilityHidden(true)
    }
}

/// Что показывают виджеты: валюты из списка приложения и сохранённые курсы.
private struct WidgetPreviewData {
    let rates: SharedRates
    let source: String
    let target: String
    let codes: [String]
    let local: String
    let locale: Locale

    var rate: Double { rates.rate(from: source, to: target) ?? 0 }
    var localRate: Double { rates.rate(from: local, to: source) ?? 0 }
    var change: Double? { rates.change(from: source, to: target) }

    func name(_ code: String) -> String { CurrencyCatalog.name(for: code, locale: locale) }

    /// Значения за неделю. Фиат обновляется раз в сутки, и линия бывает ровной —
    /// тогда примерная волна вокруг текущего курса, чтобы было видно, как выглядит график.
    var points: [ChartValue] {
        let real = rates.series(from: source, to: target, period: .week)
        if Set(real.map(\.value)).count >= 3 {
            return real.map { ChartValue(date: $0.date, value: $0.value) }
        }
        return (0..<28).map { step in
            let hour = Double(step) * 6
            let wave = 1 + 0.015 * sin(hour / 30) + 0.004 * sin(hour / 3)
            return ChartValue(date: .now.addingTimeInterval(hour * 3600), value: rate * wave)
        }
    }

    /// Сумма исходной валюты без копеек: «100 USD».
    func whole(_ amount: Double) -> String {
        AmountFormat.amount(amount, locale: RateFormat.locale, decimalPlaces: 0)
    }

    /// Сумма валюты для исходной суммы 100.
    func amount(_ code: String) -> String {
        rates.rate(from: source, to: code).map { RateFormat.amount($0 * 100) } ?? "—"
    }

    /// Самые крупные монеты, у которых есть цена.
    var coins: [String] {
        ["BTC", "ETH", "SOL", "XRP", "BNB", "DOGE"].filter { rates.rate(from: $0, to: "USD") != nil }
    }
}

private struct ChartValue: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

/// Две круглые иконки внахлёст.
private struct PairIcons: View {
    let source: String
    let target: String
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            CurrencyIcon(currency: Currency(code: source), size: size)
            CurrencyIcon(currency: Currency(code: target), size: size)
                .offset(x: size * 0.6, y: size * 0.55)
        }
        .frame(width: size * 1.6, height: size * 1.55, alignment: .topLeading)
    }
}

/// Изменение за сутки со стрелкой.
private struct ChangeText: View {
    let change: Double?

    var body: some View {
        if let change {
            HStack(spacing: 3) {
                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                Text(abs(change), format: .percent.precision(.fractionLength(2)))
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(change >= 0 ? Color.green : Color.red)
        }
    }
}

private struct RateHeadline: View {
    let source: String
    let target: String
    let rate: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "1 \(source) =")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.secondaryLabel)
                .lineLimit(1)
            Text(verbatim: "\(RateFormat.rate(rate)) \(target)")
                .font(.title3.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.45)
        }
    }
}

// MARK: - «Курс»

private struct PairSmall: View {
    let data: WidgetPreviewData
    var showsChips = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PairIcons(source: data.source, target: data.target, size: 30)
            Spacer(minLength: 4)
            RateHeadline(source: data.source, target: data.target, rate: data.rate)
            Spacer(minLength: 4)
            if showsChips {
                HStack(spacing: 4) {
                    ForEach(["1", "10", "100", "1K"], id: \.self) { label in
                        Text(verbatim: label)
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .foregroundStyle(label == "1" ? Color.onAccent : Color.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 22)
                            .background(Capsule().fill(label == "1" ? Color.accentButton : Color.primary.opacity(0.1)))
                    }
                }
            } else {
                ChangeText(change: data.change)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct PairMedium: View {
    let data: WidgetPreviewData
    private let amounts: [Double] = [1, 10, 100, 1000]

    var body: some View {
        HStack(spacing: 16) {
            PairSmall(data: data, showsChips: false)
            Divider()
            VStack(spacing: 0) {
                ForEach(amounts, id: \.self) { amount in
                    if amount > 1 { Divider().opacity(0.5) }
                    HStack(spacing: 4) {
                        Text(verbatim: "\(data.whole(amount)) \(data.source)")
                            .foregroundStyle(Color.secondaryLabel)
                        Spacer(minLength: 4)
                        Text(verbatim: "\(RateFormat.amount(amount * data.rate)) \(data.target)")
                            .fontWeight(.semibold)
                    }
                    .font(.caption.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - «Мои валюты»

private struct ListPreview: View {
    let data: WidgetPreviewData
    let showsNames: Bool

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(data.codes.prefix(4).enumerated()), id: \.element) { index, code in
                if index > 0 { Divider().opacity(0.5) }
                HStack(spacing: 8) {
                    CurrencyIcon(currency: Currency(code: code), size: 24)
                    Text(verbatim: code).font(.subheadline.weight(.medium)).lineLimit(1).fixedSize()
                    if showsNames {
                        Text(verbatim: data.name(code))
                            .font(.caption)
                            .foregroundStyle(Color.secondaryLabel)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text(verbatim: data.amount(code))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(code == data.source ? Color.accentColor : Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .layoutPriority(1)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
}

// MARK: - «График»

private struct RateLine: View {
    let data: WidgetPreviewData

    var body: some View {
        let points = data.points
        let values = points.map(\.value)
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        // Чтобы почти ровная линия не выглядела пилой, держим минимальный размах.
        let pad = max((high - low) * 0.15, high * 0.0005)
        let color = (points.last?.value ?? 0) >= (points.first?.value ?? 0) ? Color.green : Color.red

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
    }
}

private struct ChartSmall: View {
    let data: WidgetPreviewData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                PairIcons(source: data.source, target: data.target, size: 22)
                Spacer(minLength: 0)
                Text(verbatim: "7D").font(.caption2.weight(.bold)).foregroundStyle(Color.secondaryLabel)
            }
            Text(verbatim: "\(RateFormat.rate(data.rate)) \(data.target)")
                .font(.headline.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            RateLine(data: data)
        }
    }
}

private struct ChartMedium: View {
    let data: WidgetPreviewData

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                PairIcons(source: data.source, target: data.target, size: 34)
                Spacer(minLength: 2)
                RateHeadline(source: data.source, target: data.target, rate: data.rate)
                ChangeText(change: data.change)
            }
            .frame(width: 130, alignment: .leading)
            RateLine(data: data).padding(.top, 22)
        }
        .overlay(alignment: .topTrailing) {
            Text(verbatim: "7D").font(.caption2.weight(.bold)).foregroundStyle(Color.secondaryLabel)
        }
    }
}

// MARK: - «Крипто-рынок»

private struct CryptoPreview: View {
    let data: WidgetPreviewData
    let columns: Int

    var body: some View {
        let coins = Array(data.coins.prefix(columns * 3))
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                if columns > 1 { Text(L(.widgetCrypto)).font(.caption.weight(.bold)).lineLimit(1) }
                Spacer(minLength: 2)
                Text(verbatim: "USD")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 7)
                    .frame(height: 20)
                    .background(Capsule().fill(Color.primary.opacity(0.12)))
            }
            HStack(alignment: .top, spacing: 12) {
                column(Array(coins.prefix(3)))
                if columns > 1 { column(Array(coins.dropFirst(3))) }
            }
        }
    }

    private func column(_ coins: [String]) -> some View {
        VStack(spacing: 0) {
            ForEach(coins, id: \.self) { code in
                HStack(spacing: 6) {
                    CurrencyIcon(currency: Currency(code: code), size: 22)
                    Text(verbatim: code).font(.caption.weight(.semibold)).lineLimit(1).fixedSize()
                    Spacer(minLength: 2)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(verbatim: data.rates.rate(from: code, to: "USD").map(RateFormat.amount) ?? "—")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        if let change = data.rates.cryptoChanges[code] {
                            Text(change / 100, format: .percent.precision(.fractionLength(1)).sign(strategy: .always()))
                                .font(.caption2.weight(.semibold).monospacedDigit())
                                .foregroundStyle(change >= 0 ? Color.green : Color.red)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
}

// MARK: - «Путешествие»

private struct TravelSmall: View {
    let data: WidgetPreviewData

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                CurrencyIcon(currency: Currency(code: data.local), size: 26)
                Text(verbatim: data.name(data.local))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Image(systemName: "airplane")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.secondaryLabel)
            }
            Spacer(minLength: 4)
            RateHeadline(source: data.local, target: data.source, rate: data.localRate)
            Spacer(minLength: 4)
            if data.localRate > 0 {
                Text(verbatim: "1 \(data.source) = \(RateFormat.rate(1 / data.localRate)) \(data.local)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.secondaryLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct TravelMedium: View {
    let data: WidgetPreviewData
    private let amounts: [Double] = [10, 100, 500, 1000]

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            TravelSmall(data: data)
            Divider()
            VStack(spacing: 0) {
                ForEach(amounts, id: \.self) { amount in
                    if amount != amounts[0] { Divider().opacity(0.5) }
                    HStack(spacing: 4) {
                        Text(verbatim: "\(data.whole(amount)) \(data.local)")
                            .foregroundStyle(Color.secondaryLabel)
                        Spacer(minLength: 4)
                        Text(verbatim: "\(RateFormat.amount(amount * data.localRate)) \(data.source)")
                            .fontWeight(.semibold)
                    }
                    .font(.caption.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    NavigationStack { WidgetsGuideView() }
        .environment(RatesStore.preview())
}
