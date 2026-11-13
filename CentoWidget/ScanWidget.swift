import SwiftUI
import WidgetKit

/// «Сканер цен»: открывает Cento сразу на камере, которая пересчитывает цены на ценниках и в меню.
/// Камеру в самом виджете iOS не запускает, поэтому виджет — кнопка-ссылка cento://scan.
/// Широкий вариант рядом с кнопкой показывает шпаргалку: ходовые суммы в местной валюте — в долларах.
struct ScanWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ScanWidget", provider: ScanProvider()) { entry in
            ScanWidgetView(entry: entry)
        }
        .configurationDisplayName("Scan Prices")
        .description("Point the camera at a price tag or menu to convert it")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}

struct ScanEntry: TimelineEntry {
    var date: Date
    /// Местная валюта (где вы сейчас) и валюта пересчёта — доллар, а дома в США — следующая из списка.
    let local: String
    let target: String
    let rate: Double?
    let numberLocale: Locale

    static func make(snapshot: WidgetSnapshot?, rates: SharedRates, date: Date = .now) -> ScanEntry {
        let app = snapshot ?? .preview
        let local = snapshot == nil ? "TRY" : (app.countryCurrency ?? app.codes.first ?? "EUR")
        let target = local == "USD"
            ? (app.codes.first { $0 != "USD" && !CurrencyCatalog.isCrypto($0) } ?? "EUR")
            : "USD"
        return ScanEntry(date: date, local: local, target: target,
                         rate: rates.rate(from: local, to: target), numberLocale: app.numberLocale)
    }

    func format(_ value: Double) -> String {
        CompactZeros.apply(AmountFormat.amount(value, locale: numberLocale, decimalPlaces: value >= 100 ? 0 : nil), locale: numberLocale)
    }
}

struct ScanProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScanEntry { .make(snapshot: nil, rates: .preview) }

    func getSnapshot(in context: Context, completion: @escaping (ScanEntry) -> Void) {
        if context.isPreview, !WidgetRates.hasData {
            completion(.make(snapshot: nil, rates: .preview))
        } else {
            completion(.make(snapshot: WidgetSnapshot.load(), rates: SharedRates.load() ?? .empty))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScanEntry>) -> Void) {
        Task {
            let rates = await WidgetRates.current()
            let entry = ScanEntry.make(snapshot: WidgetSnapshot.load(), rates: rates)
            completion(Timeline(entries: [entry], policy: .after(WidgetRates.nextUpdate)))
        }
    }
}

struct ScanWidgetView: View {
    let entry: ScanEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    Image("icon-scan")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                }
                .containerBackground(for: .widget) { Color.clear }
            case .systemMedium:
                HStack(spacing: 14) {
                    button
                    Divider()
                    cheatSheet
                }
                .containerBackground(for: .widget) { Color(.systemBackground) }
            default:
                button
                    .containerBackground(for: .widget) { Color(.systemBackground) }
            }
        }
        .widgetURL(URL(string: "cento://scan"))
    }

    /// Кнопка камеры, название и направление пересчёта.
    private var button: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScanMark()
            Spacer(minLength: 8)
            Text("Scan Prices")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                // Отступ между названием и валютами — чтобы строки не слипались.
                .padding(.bottom, 4)
            HStack(spacing: 4) {
                CurrencyBadge(code: entry.local, size: 16)
                Text(verbatim: "\(entry.local) → \(entry.target)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// Шпаргалка: сколько ходовые суммы в местной валюте стоят в валюте пересчёта.
    @ViewBuilder
    private var cheatSheet: some View {
        if let rate = entry.rate {
            let options = TravelEntry.choices(rate: rate)
            VStack(spacing: 0) {
                ForEach(options, id: \.self) { amount in
                    if amount != options[0] { Divider().opacity(0.5) }
                    HStack(spacing: 4) {
                        Text(verbatim: "\(AmountFormat.amount(amount, locale: entry.numberLocale, decimalPlaces: 0)) \(entry.local)")
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 4)
                        Text(verbatim: "\(entry.format(amount * rate)) \(entry.target)")
                            .fontWeight(.semibold)
                    }
                    .font(.caption.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
        } else {
            Text(verbatim: "—")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
