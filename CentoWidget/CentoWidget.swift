import SwiftUI
import UIKit
import WidgetKit

@main
struct CentoWidgetBundle: WidgetBundle {
    var body: some Widget {
        PairWidget()
        CurrencyWidget()
    }
}

/// «Курс»: одна валюта в другой, на экране «Домой» и на экране блокировки.
struct PairWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "PairWidget", intent: PairIntent.self, provider: PairProvider()) { entry in
            PairWidgetView(entry: entry)
        }
        .configurationDisplayName("Exchange rate")
        .description("One currency in another, with the change over a day")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryRectangular, .accessoryInline, .accessoryCircular,
        ])
    }
}

/// «Мои валюты»: несколько валют с суммой — из приложения или выбранные в настройках виджета.
struct CurrencyWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "CurrencyWidget", intent: ListIntent.self, provider: ListProvider()) { entry in
            CurrencyWidgetView(entry: entry)
        }
        .configurationDisplayName("My currencies")
        .description("Several currencies at once — from your app list or chosen here")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryRectangular, .accessoryInline, .accessoryCircular,
        ])
    }
}

// MARK: - «Курс»

struct PairWidgetView: View {
    let entry: PairEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .environment(\.layoutDirection, entry.isRightToLeft ? .rightToLeft : .leftToRight)
            .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    @ViewBuilder
    private var content: some View {
        if let rate = entry.rate {
            switch family {
            case .accessoryInline:
                Text(verbatim: "1 \(entry.source) = \(entry.format(rate)) \(entry.target)")
            case .accessoryCircular:
                circular(rate)
            case .accessoryRectangular:
                rectangular(rate)
            case .systemMedium:
                HStack(spacing: 16) {
                    main(rate)
                    Divider()
                    multiples(rate)
                }
            default:
                main(rate)
            }
        } else {
            EmptyWidgetView(family: family)
        }
    }

    /// Флаги пары, «1 EUR =», курс и изменение за сутки — как карточка курса в банке.
    private func main(_ rate: Double) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                PairBadges(source: entry.source, target: entry.target, size: 38)
                Spacer(minLength: 4)
                if entry.isLocked { ProMark() }
            }
            Spacer(minLength: 8)
            Text(verbatim: "1 \(entry.source) =")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(verbatim: "\(entry.format(rate)) \(entry.target)")
                .font(.title2.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.45)
            Spacer(minLength: 6)
            ChangeLabel(change: entry.change, updatedAt: entry.updatedAt, locale: entry.numberLocale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// Справа в среднем виджете: сколько будет 1, 10, 100 и 1000.
    private func multiples(_ rate: Double) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach([1.0, 10, 100, 1000], id: \.self) { amount in
                if amount > 1 { Divider().opacity(0.5) }
                HStack(spacing: 4) {
                    Text(verbatim: "\(AmountFormat.amount(amount, locale: entry.numberLocale, decimalPlaces: 0)) \(entry.source)")
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Text(verbatim: "\(entry.formatAmount(amount * rate)) \(entry.target)")
                        .fontWeight(.semibold)
                }
                .font(.footnote.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Экран блокировки: пара сверху, курс крупно, изменение снизу.
    private func rectangular(_ rate: Double) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "\(entry.source) → \(entry.target)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(verbatim: entry.format(rate))
                .font(.title3.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .widgetAccentable()
            ChangeLabel(change: entry.change, updatedAt: entry.updatedAt, locale: entry.numberLocale)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func circular(_ rate: Double) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text(verbatim: entry.target).font(.system(size: 11, weight: .semibold))
                Text(verbatim: entry.format(rate))
                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .padding(.horizontal, 4)
            }
        }
    }
}

/// Две круглые иконки внахлёст: исходная валюта сзади, целевая спереди.
private struct PairBadges: View {
    let source: String
    let target: String
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            CurrencyBadge(code: source, size: size)
            CurrencyBadge(code: target, size: size)
                // Кольцо цвета фона отделяет иконки друг от друга.
                .background(Circle().fill(Color(.systemBackground)).padding(-2.5))
                .offset(x: size * 0.6, y: size * 0.55)
        }
        .frame(width: size * 1.6, height: size * 1.55, alignment: .topLeading)
    }
}

/// Изменение за сутки со стрелкой; пока истории нет — время обновления.
private struct ChangeLabel: View {
    let change: Double?
    let updatedAt: Date?
    let locale: Locale

    var body: some View {
        if let change {
            let isFlat = abs(change) < 0.00005
            HStack(spacing: 3) {
                Image(systemName: isFlat ? "arrow.right" : change > 0 ? "arrow.up.right" : "arrow.down.right")
                Text(abs(change), format: .percent.precision(.fractionLength(2)).locale(locale))
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(isFlat ? Color.secondary : change > 0 ? Color.green : Color.red)
        } else if let updatedAt {
            HStack(spacing: 3) {
                Image(systemName: "clock")
                Text(updatedAt, format: .dateTime.hour().minute())
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - «Мои валюты»

struct CurrencyWidgetView: View {
    let entry: ListEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .environment(\.layoutDirection, entry.isRightToLeft ? .rightToLeft : .leftToRight)
            .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    @ViewBuilder
    private var content: some View {
        let rows = entry.rows
        if !rows.isEmpty {
            switch family {
            case .accessoryInline:
                inline(rows)
            case .accessoryCircular:
                circular(rows)
            case .accessoryRectangular:
                rectangular(rows)
            case .systemLarge:
                listWithNote(rows, limit: 7, showsNames: true)
            case .systemMedium:
                listWithNote(rows, limit: 4, showsNames: true)
            default:
                listWithNote(rows, limit: 4, showsNames: false)
            }
        } else {
            EmptyWidgetView(family: family)
        }
    }

    /// Список; если выбраны платные валюты без подписки — внизу пометка Pro вместо последней строки.
    @ViewBuilder
    private func listWithNote(_ rows: [RateRow], limit: Int, showsNames: Bool) -> some View {
        if entry.isLocked {
            VStack(spacing: 4) {
                list(rows, limit: limit - 1, showsNames: showsNames)
                HStack(spacing: 4) {
                    ProMark()
                    Text("Any currency with Pro")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                }
            }
        } else {
            list(rows, limit: limit, showsNames: showsNames)
        }
    }

    /// Карточки валют, как в приложении: круглая иконка, код (и название), сумма справа.
    private func list(_ rows: [RateRow], limit: Int, showsNames: Bool) -> some View {
        let shown = Array(rows.prefix(limit))
        let iconSize: CGFloat = family == .systemLarge ? 32 : 24
        return VStack(spacing: 0) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, row in
                if index > 0 { Divider().opacity(0.5) }
                HStack(spacing: 8) {
                    CurrencyBadge(code: row.code, size: iconSize)
                    if showsNames && family == .systemLarge {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: row.code).font(.subheadline.weight(.medium))
                            Text(verbatim: row.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    } else {
                        // В среднем виджете название — в той же строке: в две строки
                        // четыре валюты не помещались по высоте и упирались в края.
                        Text(verbatim: row.code).font(.subheadline.weight(.medium))
                        if showsNames {
                            Text(verbatim: row.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                    Text(verbatim: row.value)
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
    private func rectangular(_ rows: [RateRow]) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(rows.prefix(3)) { row in
                HStack(spacing: 4) {
                    Text(verbatim: row.code).font(.caption.weight(.semibold))
                    Spacer(minLength: 2)
                    Text(verbatim: row.value)
                        .font(.caption.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .widgetAccentable(row.isSource)
                }
            }
        }
    }

    /// Строка над часами: «100 USD = 89.75 EUR».
    private func inline(_ rows: [RateRow]) -> some View {
        let source = rows.first(where: \.isSource) ?? rows[0]
        let other = rows.first { $0.code != source.code }
        return Text(verbatim: other.map { "\(source.value) \(source.code) = \($0.value) \($0.code)" } ?? "\(source.value) \(source.code)")
    }

    /// Круглый: первая валюта после исходной — сколько она стоит для суммы исходной.
    private func circular(_ rows: [RateRow]) -> some View {
        let row = rows.first { !$0.isSource } ?? rows[0]
        return ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text(verbatim: row.code).font(.system(size: 11, weight: .semibold))
                Text(verbatim: row.value)
                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Общее

/// Пока курсов нет (приложение ни разу не открывали и сети не было).
private struct EmptyWidgetView: View {
    let family: WidgetFamily

    var body: some View {
        VStack(spacing: 6) {
            if family != .accessoryInline {
                Image(systemName: "dollarsign.arrow.circlepath")
                    .font(.title2)
                    .foregroundStyle(WidgetColor.accent)
            }
            Text("Open Cento to choose currencies")
                .font(.caption)
                .multilineTextAlignment(.center)
        }
    }
}

/// Пометка «Pro» с замком: выбранные валюты доступны только с подпиской.
private struct ProMark: View {
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "lock.fill")
            Text(verbatim: "Pro")
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(WidgetColor.accent.gradient))
    }
}

/// Круглый значок валюты, как в приложении: флаг, значок криптовалюты, монета с буквами или глобус.
struct CurrencyBadge: View {
    let code: String
    let size: CGFloat

    var body: some View {
        artwork
            .frame(width: size, height: size)
            .clipShape(Circle())
            // Мягкое стекло: блик сверху слева и светлый ободок.
            .overlay {
                Circle().fill(
                    RadialGradient(
                        colors: [.white.opacity(0.28), .white.opacity(0)],
                        center: UnitPoint(x: 0.3, y: 0.18),
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
            }
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.75))
    }

    @ViewBuilder
    private var artwork: some View {
        if let name = CurrencyCatalog.imageName(for: code), UIImage(named: name) != nil {
            Image(name)
                .resizable()
                .scaledToFit()
        } else if CurrencyCatalog.isCrypto(code) {
            ZStack {
                Circle().fill(WidgetColor.accent.gradient)
                Text(verbatim: String(code.prefix(3)))
                    .font(.system(size: size * 0.3, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
            }
        } else {
            ZStack {
                Circle().fill(Color.blue.gradient)
                Image(systemName: "globe")
                    .font(.system(size: size * 0.52, weight: .medium))
                    .foregroundStyle(.white)
            }
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

#Preview(as: .systemSmall) {
    PairWidget()
} timeline: {
    PairEntry.make(PairIntent(), snapshot: .preview, rates: .preview)
}

#Preview(as: .systemMedium) {
    PairWidget()
} timeline: {
    PairEntry.make(PairIntent(), snapshot: .preview, rates: .preview)
}

#Preview(as: .systemSmall) {
    CurrencyWidget()
} timeline: {
    ListEntry.make(ListIntent(), snapshot: .preview, rates: .preview)
}

#Preview(as: .systemLarge) {
    CurrencyWidget()
} timeline: {
    ListEntry.make(ListIntent(), snapshot: .preview, rates: .preview)
}
