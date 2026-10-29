import SwiftUI
import WidgetKit

@main
struct CentoWidgetBundle: WidgetBundle {
    var body: some Widget {
        CurrencyWidget()
    }
}

/// Выбранные в приложении валюты — на экране «Домой» и на экране блокировки.
struct CurrencyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CurrencyWidget", provider: RatesProvider()) { entry in
            CurrencyWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Cento")
        .description(WidgetText.description)
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryRectangular, .accessoryInline, .accessoryCircular,
        ])
    }
}

struct RatesEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

/// Данные пишет приложение и само просит обновить виджеты, поэтому расписание не нужно.
struct RatesProvider: TimelineProvider {
    func placeholder(in context: Context) -> RatesEntry {
        RatesEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (RatesEntry) -> Void) {
        completion(RatesEntry(date: .now, snapshot: WidgetSnapshot.load() ?? .preview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RatesEntry>) -> Void) {
        completion(Timeline(entries: [RatesEntry(date: .now, snapshot: WidgetSnapshot.load())], policy: .never))
    }
}

// MARK: - Вид

struct CurrencyWidgetView: View {
    let snapshot: WidgetSnapshot?

    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .environment(\.layoutDirection, snapshot?.isRightToLeft == true ? .rightToLeft : .leftToRight)
            .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    @ViewBuilder
    private var content: some View {
        if let rows = snapshot?.rows, !rows.isEmpty {
            switch family {
            case .accessoryInline:
                inline(rows)
            case .accessoryCircular:
                circular(rows)
            case .accessoryRectangular:
                rectangular(rows)
            case .systemLarge:
                list(rows, limit: 7, showsNames: true)
            case .systemMedium:
                list(rows, limit: 4, showsNames: true)
            default:
                list(rows, limit: 4, showsNames: false)
            }
        } else {
            empty
        }
    }

    /// Карточки валют, как в приложении: флаг, код (и название), сумма справа.
    private func list(_ rows: [WidgetSnapshot.Row], limit: Int, showsNames: Bool) -> some View {
        let shown = Array(rows.prefix(limit))
        return VStack(spacing: 0) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, row in
                if index > 0 { Divider().opacity(0.5) }
                HStack(spacing: 8) {
                    CurrencyBadge(row: row, size: showsNames && family == .systemLarge ? 30 : 22)
                    if showsNames && family == .systemLarge {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.code).font(.subheadline.weight(.medium))
                            Text(row.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    } else {
                        Text(row.code).font(.subheadline.weight(.medium))
                        if showsNames {
                            Text(row.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                    Text(row.value)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(row.isSource ? WidgetColor.accent : Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .layoutPriority(1)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    /// Экран блокировки, прямоугольный: до трёх валют строками «код — сумма».
    private func rectangular(_ rows: [WidgetSnapshot.Row]) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(rows.prefix(3)) { row in
                HStack(spacing: 4) {
                    Text(row.code).font(.caption.weight(.semibold))
                    Spacer(minLength: 2)
                    Text(row.value)
                        .font(.caption.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .widgetAccentable(row.isSource)
                }
            }
        }
    }

    /// Строка над часами: «100 USD = 89.75 EUR».
    private func inline(_ rows: [WidgetSnapshot.Row]) -> some View {
        let source = rows.first(where: \.isSource) ?? rows[0]
        let other = rows.first { $0.code != source.code }
        return Text(other.map { "\(source.value) \(source.code) = \($0.value) \($0.code)" } ?? "\(source.value) \(source.code)")
    }

    /// Круглый: вторая валюта списка — сколько она стоит для суммы первой.
    private func circular(_ rows: [WidgetSnapshot.Row]) -> some View {
        let row = rows.first { !$0.isSource } ?? rows[0]
        return ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text(row.code).font(.system(size: 11, weight: .semibold))
                Text(row.value)
                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 6) {
            if family != .accessoryInline {
                Image(systemName: "dollarsign.arrow.circlepath")
                    .font(.title2)
                    .foregroundStyle(WidgetColor.accent)
            }
            Text(WidgetText.openApp)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
    }
}

/// Флаг валюты или, у криптовалюты, кружок с первой буквой кода.
private struct CurrencyBadge: View {
    let row: WidgetSnapshot.Row
    let size: CGFloat

    var body: some View {
        if let flag = row.flag {
            Text(flag)
                .font(.system(size: size * 0.82))
                .frame(width: size, height: size)
        } else {
            Text(String(row.code.prefix(1)))
                .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(WidgetColor.accent))
        }
    }
}

enum WidgetColor {
    /// Акцентный цвет приложения.
    static let accent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xE9 / 255, green: 0xB3 / 255, blue: 0xFB / 255, alpha: 1)
            : UIColor(red: 0xA2 / 255, green: 0x4F / 255, blue: 0xCF / 255, alpha: 1)
    })
}

/// Подписи виджета на языке системы (язык приложения виджету недоступен, пока нет данных).
enum WidgetText {
    private static var language: String {
        let preferred = Locale.preferredLanguages.first ?? "en"
        // Китайский с традиционным письмом — отдельный набор подписей.
        if preferred.hasPrefix("zh"), preferred.contains("Hant") || preferred.contains("TW") || preferred.contains("HK") || preferred.contains("MO") {
            return "zh-Hant"
        }
        return String(preferred.prefix(2))
    }

    static var description: String {
        [
            "ru": "Курсы выбранных валют",
            "tr": "Seçtiğin para birimlerinin kurları",
            "fr": "Les taux de vos devises",
            "es": "Tipos de cambio de tus divisas",
            "de": "Kurse deiner Währungen",
            "zh": "所选货币的汇率",
            "ar": "أسعار العملات التي اخترتها",
            "ja": "選んだ通貨のレート",
            "pt": "Cotações das suas moedas",
            "ko": "선택한 통화의 환율",
            "zh-Hant": "所選貨幣的匯率",
            "it": "I tassi delle tue valute",
            "pl": "Kursy wybranych walut",
        ][language] ?? "Rates for your currencies"
    }

    static var openApp: String {
        [
            "ru": "Откройте Cento, чтобы выбрать валюты",
            "tr": "Para birimlerini seçmek için Cento’yu aç",
            "fr": "Ouvrez Cento pour choisir vos devises",
            "es": "Abre Cento para elegir tus divisas",
            "de": "Öffne Cento, um Währungen zu wählen",
            "zh": "打开 Cento 选择货币",
            "ar": "افتح Cento لاختيار العملات",
            "ja": "Cento を開いて通貨を選択",
            "pt": "Abra o Cento para escolher as moedas",
            "ko": "Cento를 열어 통화를 선택하세요",
            "zh-Hant": "開啟 Cento 選擇貨幣",
            "it": "Apri Cento per scegliere le valute",
            "pl": "Otwórz Cento, aby wybrać waluty",
        ][language] ?? "Open Cento to choose currencies"
    }
}

#Preview(as: .systemSmall) {
    CurrencyWidget()
} timeline: {
    RatesEntry(date: .now, snapshot: .preview)
}

#Preview(as: .systemLarge) {
    CurrencyWidget()
} timeline: {
    RatesEntry(date: .now, snapshot: .preview)
}

#Preview(as: .accessoryRectangular) {
    CurrencyWidget()
} timeline: {
    RatesEntry(date: .now, snapshot: .preview)
}
