import SwiftUI

/// Карточка валюты из макета: флаг, код и название слева; сумма и курс за единицу справа.
/// Нажатие делает валюту строкой ввода — сумму набирают на клавиатуре-калькуляторе.
struct CurrencyRow: View {
    let code: String
    let sourceCode: String
    /// Сумма в этой валюте или выражение, если это строка ввода.
    let value: String
    /// Строка ввода пуста — показывается подсказка «1».
    var isPlaceholder = false
    let unitRate: Double?
    /// Показывать мигающий курсор рядом с вводимой суммой.
    var showsCursor = false
    /// Подпись строки ввода, пока клавиатура скрыта (курс к другой валюте списка).
    var idleSourceCaption: String?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isSource: Bool { code == sourceCode }
    /// Строка выделяется только во время ввода.
    private var isEditing: Bool { isSource && showsCursor }

    var body: some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let layout = isLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))

        layout {
            if isLarge {
                // Крупный шрифт: всё в столбик.
                HStack(spacing: 12) {
                    CurrencyIcon(currency: Currency(code: code))
                    codeText
                }
                nameText
                amountText
                captionView
            } else {
                HStack(spacing: 12) {
                    CurrencyIcon(currency: Currency(code: code))
                    // Две строки: код и сумма, затем название и курс — каждая пара на одной линии.
                    VStack(spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            codeText
                            Spacer(minLength: 8)
                            amountText
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            nameText
                            Spacer(minLength: 8)
                            captionView.layoutPriority(1)
                        }
                    }
                }
            }
        }
        .padding(20)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isEditing ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isSource ? L(.sourceHint) : L(.enterHint))
    }

    private var codeText: some View {
        Text(code)
            .font(.body.weight(.medium))
            .foregroundStyle(Color.primary)
            .fixedSize()
    }

    private var nameText: some View {
        Text(Currency.name(for: code))
            .font(.footnote)
            .foregroundStyle(Color.secondaryLabel)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
    }

    private var amountText: some View {
        HStack(spacing: 2) {
            Text(value)
                .font(.amount)
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                // Размер суммы одинаков во всех строках и не меняется при вводе.
                .fixedSize()
                // Цифры прокручиваются, как на счётчике, при каждом изменении суммы.
                .contentTransition(.numericText(countsDown: false))
                .animation(.snappy(duration: 0.35), value: value)
            if showsCursor && isSource {
                BlinkingCursor()
            }
        }
    }

    private var captionView: some View {
        Text(captionText)
            .font(.footnote.monospacedDigit())
            .foregroundStyle(Color.secondaryLabel)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            .minimumScaleFactor(0.8)
    }

    private var valueColor: Color {
        guard isEditing else { return .primary }
        return isPlaceholder ? Color.amountHighlight.opacity(0.45) : Color.amountHighlight
    }

    private var captionText: String {
        if isEditing { return L(.enteredAmount) }
        if isSource { return idleSourceCaption ?? "" }
        guard let unitRate else { return L(.noRate) }
        return "1 \(sourceCode) = \(RateFormat.rate(unitRate)) \(code)"
    }

    private var accessibilityText: String {
        "\(Currency.name(for: code)). \(value) \(code). \(captionText)"
    }
}

/// Мигающий курсор ввода, как у текстового поля.
private struct BlinkingCursor: View {
    @State private var isVisible = true
    @ScaledMetric(relativeTo: .title3) private var height = 22

    var body: some View {
        Capsule()
            .fill(Color.amountHighlight)
            .frame(width: 2.5, height: height)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever()) { isVisible = false }
            }
            .accessibilityHidden(true)
    }
}

/// Кэш проверки наличия картинок в Assets — чтобы не искать её при каждой перерисовке строки.
enum AssetCache {
    @MainActor private static var known: [String: Bool] = [:]

    @MainActor static func has(_ name: String) -> Bool {
        if let cached = known[name] { return cached }
        let exists = UIImage(named: name) != nil
        known[name] = exists
        return exists
    }
}

/// Круглый значок валюты: флаг страны из макета, значок криптовалюты или купюра.
struct CurrencyIcon: View {
    let currency: Currency

    @ScaledMetric(relativeTo: .title) private var size = 44

    var body: some View {
        artwork
            .frame(width: size, height: size)
            .clipShape(Circle())
            // Мягкое стекло: блик сверху слева и светлый ободок, ярче сверху.
            .overlay {
                ZStack {
                    Circle().fill(
                        RadialGradient(
                            colors: [.white.opacity(0.28), .white.opacity(0)],
                            center: UnitPoint(x: 0.3, y: 0.18),
                            startRadius: 0,
                            endRadius: size * 0.5
                        )
                    )
                    Circle().strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.7), .white.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.5
                    )
                }
                .allowsHitTesting(false)
            }
            // Еле заметный серый контур — отделяет белые края флагов (Россия, Япония…) от фона.
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.75))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var artwork: some View {
        if currency.kind == .crypto, AssetCache.has("crypto-\(currency.code)") {
            // Иконки web3icons (MIT), вариант с фоном.
            Image("crypto-\(currency.code)")
                .resizable()
                .scaledToFit()
        } else if let region = currency.flagRegion, AssetCache.has("flag-\(region)") {
            Image("flag-\(region)")
                .resizable()
                .scaledToFit()
        } else if let emoji = currency.flagEmoji {
            Text(emoji)
                .font(.system(size: size))
                .scaleEffect(1.75)
        } else {
            Image(systemName: symbolName)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white, symbolBackground)
        }
    }

    private var symbolName: String {
        switch currency.kind {
        case .crypto: currency.code == "BTC" ? "bitcoinsign.circle.fill" : "circle.hexagongrid.circle.fill"
        case .fiat: "banknote.fill"
        }
    }

    private var symbolBackground: Color {
        currency.kind == .crypto ? .orange : .gray
    }
}

/// Стеклянный кружок выбора в стиле клавиш: пустой — не выбрано, с галочкой — выбрано.
private struct SelectionBubble: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color.amountHighlight)
            .opacity(isSelected ? 1 : 0)
            .scaleEffect(isSelected ? 1 : 0.4)
            .frame(width: 30, height: 30)
            .background {
                // Тот же стеклянный пузырь, что у клавиш; выбранный — с синим оттенком.
                Button(action: {}) { Color.clear.frame(width: 30, height: 30) }
                    .buttonStyle(GlassBubbleStyle(tint: isSelected ? .amountHighlight : .glassNeutral))
                    .allowsHitTesting(false)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            .accessibilityHidden(true)
    }
}

/// Строка выбора валюты с галочкой.
struct CurrencySelectRow: View {
    let currency: Currency
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            CurrencyIcon(currency: currency)
            VStack(alignment: .leading, spacing: 2) {
                Text(currency.code)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                Text(currency.name)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            SelectionBubble(isSelected: isSelected)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(currency.name), \(currency.code)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    List {
        CurrencyRow(code: "USD", sourceCode: "USD", value: "100", unitRate: 1)
        CurrencyRow(code: "EUR", sourceCode: "USD", value: "92", unitRate: 0.92)
        CurrencyRow(code: "BTC", sourceCode: "USD", value: "0,00125", unitRate: 0.0000125)
        CurrencySelectRow(currency: Currency(code: "GBP"), isSelected: true)
    }
}

#Preview("Все флаги") {
    let currencies = Locale.commonISOCurrencyCodes.map(Currency.init(code:)) + CryptoAsset.all.map { Currency(code: $0.code) }
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 56))], spacing: 12) {
            ForEach(currencies) { currency in
                VStack(spacing: 4) {
                    CurrencyIcon(currency: currency)
                    Text(currency.code).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}
