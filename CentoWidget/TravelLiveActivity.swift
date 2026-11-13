import ActivityKit
import SwiftUI
import WidgetKit

/// Live Activity «В поездке»: курс местной валюты к домашней на экране блокировки
/// и в Dynamic Island. Нажатие открывает Cento.
struct TravelLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TravelActivityAttributes.self) { context in
            TravelLockScreen(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color(.systemBackground).opacity(0.85))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            let a = context.attributes, s = context.state
            let f = TravelFormat(attributes: a)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        CurrencyBadge(code: a.local, size: 24)
                        Text(verbatim: a.local).font(.headline)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 6) {
                        Text(verbatim: a.home).font(.headline)
                        CurrencyBadge(code: a.home, size: 24)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(verbatim: f.headline(rate: s.rate))
                        .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    TravelSteps(format: f, rate: s.rate)
                        .padding(.top, 4)
                }
            } compactLeading: {
                CurrencyBadge(code: a.local, size: 20)
            } compactTrailing: {
                Text(verbatim: f.compact(rate: s.rate))
                    .font(.system(.caption, design: .rounded).weight(.semibold).monospacedDigit())
                    .foregroundStyle(ScanMark.accent)
            } minimal: {
                CurrencyBadge(code: a.local, size: 20)
            }
            .widgetURL(URL(string: "cento://"))
        }
    }
}

/// Форматирование сумм для Live Activity: язык и формат чисел приложения.
struct TravelFormat {
    let attributes: TravelActivityAttributes
    var locale: Locale { Locale(identifier: attributes.numberLocaleIdentifier) }

    func amount(_ value: Double, places: Int? = nil) -> String {
        CompactZeros.apply(AmountFormat.amount(value, locale: locale, decimalPlaces: places ?? (value >= 100 ? 0 : nil)), locale: locale)
    }

    /// «100 TRY = 2.91 USD» — с шагом, при котором в домашней валюте ощутимое число.
    func headline(rate: Double) -> String {
        let step = TravelActivityAttributes.step(rate: rate)
        return "\(amount(step, places: 0)) \(attributes.local) = \(amount(step * rate)) \(attributes.home)"
    }

    /// Для Dynamic Island: «2.91» за шаг местной валюты.
    func compact(rate: Double) -> String {
        amount(TravelActivityAttributes.step(rate: rate) * rate)
    }

    var countryName: String? {
        attributes.country.flatMap { Locale(identifier: attributes.languageIdentifier).localizedString(forRegionCode: $0) }
    }
}

/// Экран блокировки: страна, флаги пары, крупный курс и ходовые суммы.
private struct TravelLockScreen: View {
    let attributes: TravelActivityAttributes
    let state: TravelActivityAttributes.ContentState

    var body: some View {
        let f = TravelFormat(attributes: attributes)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    CurrencyBadge(code: attributes.local, size: 30)
                    CurrencyBadge(code: attributes.home, size: 18)
                        .offset(x: 6, y: 4)
                }
                VStack(alignment: .leading, spacing: 0) {
                    if let country = f.countryName {
                        Text(verbatim: country)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                    }
                    Text(verbatim: "\(attributes.local) → \(attributes.home)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "airplane")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(verbatim: f.headline(rate: state.rate))
                .font(.system(.title2, design: .rounded).weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            TravelSteps(format: f, rate: state.rate)
        }
        .padding(16)
    }
}

/// Ходовые суммы в местной валюте и их цена дома: ×1, ×10, ×100 от шага.
private struct TravelSteps: View {
    let format: TravelFormat
    let rate: Double

    var body: some View {
        let step = TravelActivityAttributes.step(rate: rate)
        HStack(spacing: 0) {
            ForEach([step * 10, step * 100, step * 1000], id: \.self) { amount in
                VStack(spacing: 1) {
                    Text(verbatim: "\(format.amount(amount, places: 0)) \(format.attributes.local)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(verbatim: "\(format.amount(amount * rate)) \(format.attributes.home)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
            }
        }
    }
}
