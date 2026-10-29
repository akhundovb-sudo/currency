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
            .modifier(TintedWidget(tint: entry.tint))
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
                // Знак Cento в углу напротив флагов — как логотип у банковских виджетов.
                VStack(alignment: .trailing, spacing: 6) {
                    CentoMark(tint: entry.tint)
                    if entry.isLocked { ProMark() }
                }
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
        let offset = CGSize(width: size * 0.6, height: size * 0.55)
        let gap: CGFloat = 2.5
        ZStack(alignment: .topLeading) {
            CurrencyBadge(code: source, size: size)
                // Прозрачное кольцо между иконками: вырез в задней иконке, а не круг цвета фона —
                // фон виджета бывает разным (тёмный, тонированный), и кольцо выделялось.
                .mask {
                    Rectangle()
                        .overlay(alignment: .topLeading) {
                            Circle()
                                .frame(width: size + gap * 2, height: size + gap * 2)
                                .offset(x: offset.width - gap, y: offset.height - gap)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                }
            CurrencyBadge(code: target, size: size)
                .offset(offset)
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
            .modifier(TintedWidget(tint: entry.tint))
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
    @ViewBuilder
    private func list(_ rows: [RateRow], limit: Int, showsNames: Bool) -> some View {
        let shown = Array(rows.prefix(limit))
        if shown.count <= 2 {
            duo(shown)
        } else {
            rowsList(shown, showsNames: showsNames)
        }
    }

    /// Две валюты — крупно, как карточка обмена: иконка, код с названием и сумма, по центру по высоте.
    /// Растянутые на весь виджет две строки выглядели пусто.
    private func duo(_ rows: [RateRow]) -> some View {
        let isSmall = family == .systemSmall
        return VStack(spacing: isSmall ? 8 : 12) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 { Divider().opacity(0.5) }
                if isSmall {
                    // В маленьком виджете сумма — под кодом, чтобы поместилась крупно.
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            CurrencyBadge(code: row.code, size: 24)
                            Text(verbatim: row.code).font(.subheadline.weight(.semibold)).lineLimit(1).fixedSize()
                        }
                        amount(row, font: .title3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: 10) {
                        CurrencyBadge(code: row.code, size: 36)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: row.code).font(.headline).lineLimit(1).fixedSize()
                            Text(verbatim: row.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        amount(row, font: .title2)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    /// Сумма валюты: у исходной — цветом акцента; длинная сначала уменьшается, потом обрезается «…».
    private func amount(_ row: RateRow, font: Font) -> some View {
        Text(verbatim: row.value)
            .font(font.weight(.bold).monospacedDigit())
            .foregroundStyle(row.isSource ? WidgetColor.accent : Color.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .layoutPriority(1)
    }

    private func rowsList(_ shown: [RateRow], showsNames: Bool) -> some View {
        let iconSize: CGFloat = family == .systemLarge ? 32 : 24
        return VStack(spacing: 0) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, row in
                if index > 0 { Divider().opacity(0.5) }
                HStack(spacing: 8) {
                    CurrencyBadge(code: row.code, size: iconSize)
                    if showsNames && family == .systemLarge {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: row.code).font(.subheadline.weight(.medium))
                                .lineLimit(1)
                                .fixedSize()
                            Text(verbatim: row.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    } else {
                        // В среднем виджете название — в той же строке: в две строки
                        // четыре валюты не помещались по высоте и упирались в края.
                        // Код не переносится по буквам («AZ / N»): места не хватает — сжимается сумма.
                        Text(verbatim: row.code).font(.subheadline.weight(.medium))
                            .lineLimit(1)
                            .fixedSize()
                        if showsNames {
                            Text(verbatim: row.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                    // Длинная сумма сначала уменьшается, а если и так не влезает — обрезается «…».
                    Text(verbatim: row.value)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(row.isSource ? WidgetColor.accent : Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .layoutPriority(1)
                }
                // Строки делят высоту поровну, но не растягиваются слишком: при трёх валютах
                // в большом виджете остаток уходит вниз.
                .frame(maxHeight: family == .systemLarge ? CGFloat(52) : CGFloat.infinity)
            }
            if family == .systemLarge { Spacer(minLength: 0) }
        }
    }

    /// Экран блокировки, прямоугольный: до трёх валют строками «код — сумма».
    private func rectangular(_ rows: [RateRow]) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(rows.prefix(3)) { row in
                HStack(spacing: 4) {
                    Text(verbatim: row.code).font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize()
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

/// Фон виджета по настройке «Цвет»: обычный или градиент цвета валюты. В тёмной теме —
/// от насыщенного цвета к почти чёрному, в светлой — пастельный на белом.
private struct TintedWidget: ViewModifier {
    let tint: UInt32?

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if let tint {
            let color = WidgetColor.rgb(tint)
            if colorScheme == .dark {
                content
                    .containerBackground(for: .widget) {
                        ZStack {
                            Color(red: 0.06, green: 0.06, blue: 0.08)
                            LinearGradient(
                                stops: [
                                    .init(color: color, location: 0),
                                    .init(color: color.opacity(0.45), location: 0.6),
                                    .init(color: color.opacity(0), location: 1),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            // Мягкий блик сверху — как у стеклянных карточек приложения.
                            LinearGradient(colors: [.white.opacity(0.12), .clear], startPoint: .top, endPoint: .center)
                        }
                    }
            } else {
                // Светлая тема: пастельный градиент цвета валюты на белом, текст обычный тёмный —
                // насыщенный тёмный фон среди светлых виджетов выглядел чужим.
                content
                    .containerBackground(for: .widget) {
                        ZStack {
                            Color.white
                            LinearGradient(
                                stops: [
                                    .init(color: color.opacity(0.42), location: 0),
                                    .init(color: color.opacity(0.16), location: 0.6),
                                    .init(color: color.opacity(0.05), location: 1),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .top, endPoint: .center)
                        }
                    }
            }
        } else {
            content
                .containerBackground(for: .widget) { Color(.systemBackground) }
        }
    }
}

/// Знак Cento: цвет акцента на обычном фоне; на цветном — белый в тёмной теме
/// и цвет самой валюты в светлой.
private struct CentoMark: View {
    let tint: UInt32?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image("CentoMark")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: 24, height: 24)
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }

    private var color: Color {
        guard let tint else { return WidgetColor.accent }
        return colorScheme == .dark ? Color.white.opacity(0.9) : WidgetColor.rgb(tint)
    }
}

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

/// Тег «PRO», как у платных валют в приложении: акцентный текст на стеклянной капсуле
/// с лёгким свечением акцента, светлым ободком и тонкой цветной обводкой.
private struct ProMark: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(verbatim: "PRO")
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .tracking(0.5)
            .foregroundStyle(WidgetColor.accent)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background {
                ZStack {
                    Capsule().fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.85))
                    Capsule().fill(
                        RadialGradient(
                            colors: [WidgetColor.accent.opacity(0.24), WidgetColor.accent.opacity(0.06)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 30
                        )
                    )
                    Capsule().strokeBorder(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [.white.opacity(0.35), .white.opacity(0.05)]
                                : [.white, .white.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.5
                    )
                    Capsule().strokeBorder(WidgetColor.accent.opacity(0.55), lineWidth: 1)
                }
            }
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
    /// Цвет из 0xRRGGBB.
    static func rgb(_ value: UInt32) -> Color {
        Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }


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
