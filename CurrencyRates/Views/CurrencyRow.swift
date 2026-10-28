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
    /// Каждое изменение запускает тряску суммы — сумма не помещается.
    var shakeTrigger = 0

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
                    // Выравнивание по центру, а не по базовой линии: уменьшенная длинная сумма
                    // иначе съезжает вниз на строку курса, и карточка «прыгает».
                    VStack(spacing: 4) {
                        HStack(alignment: .center, spacing: 8) {
                            codeText
                            Spacer(minLength: 8)
                            amountText
                        }
                        HStack(alignment: .center, spacing: 8) {
                            nameText
                            Spacer(minLength: 8)
                            captionView.layoutPriority(1)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isEditing ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isSource ? L(.sourceHint) : L(.enterHint))
    }

    private var codeText: some View {
        Text(code)
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.primary)
            .fixedSize()
    }

    private var nameText: some View {
        Text(Currency.name(for: code))
            .font(.footnote)
            .foregroundStyle(Color.secondaryLabel)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            // Хотя бы пара букв с «…», а не пустая черта.
            .frame(minWidth: 36, alignment: .leading)
    }

    private var amountText: some View {
        HStack(spacing: 2) {
            Text(value)
                .font(.amount)
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                // Обычно размер суммы не меняется; уменьшается, только если не помещается
                // (очень длинная сумма или узкая строка в режиме правки) — карточка не вылезает за край.
                .minimumScaleFactor(0.3)
                .layoutPriority(2)
                // Цифры прокручиваются, как на счётчике, — но не во время набора:
                // при быстром вводе анимации накладываются и цифры размазываются.
                .contentTransition(showsCursor ? .identity : .numericText(countsDown: false))
                .animation(showsCursor ? nil : .snappy(duration: 0.35), value: value)
                .transaction { if showsCursor { $0.animation = nil } }
            if showsCursor && isSource {
                BlinkingCursor()
            }
        }
        // Тряска «не помещается»: короткие затухающие колебания влево-вправо.
        .keyframeAnimator(initialValue: CGFloat(0), trigger: shakeTrigger) { content, x in
            content.offset(x: x)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(-9, duration: 0.05)
                LinearKeyframe(8, duration: 0.08)
                LinearKeyframe(-6, duration: 0.07)
                LinearKeyframe(4, duration: 0.06)
                LinearKeyframe(-2, duration: 0.05)
                LinearKeyframe(0, duration: 0.05)
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
        } else if currency.kind == .crypto {
            TickerCoin(code: currency.code, size: size)
        } else {
            // Нет флага (наднациональные валюты, редкие страны) — глобус.
            ZStack {
                Circle().fill(
                    LinearGradient(
                        colors: [Color.dynamic(light: 0x60A5FA, dark: 0x3B82F6), Color.dynamic(light: 0x2563EB, dark: 0x1D4ED8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                Image(systemName: "globe")
                    .font(.system(size: size * 0.52, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
    }
}

/// Монета без своей иконки: кружок своего цвета (постоянного для тикера) с первыми буквами.
private struct TickerCoin: View {
    let code: String
    let size: CGFloat

    private static let palette: [UInt32] = [0xF59E0B, 0x10B981, 0x6366F1, 0xEC4899, 0x0EA5E9, 0x8B5CF6, 0xEF4444, 0x14B8A6]

    var body: some View {
        // Цвет по сумме кодов букв — одинаковый при каждом запуске.
        let index = code.unicodeScalars.reduce(0) { $0 + Int($1.value) } % Self.palette.count
        ZStack {
            Circle().fill(Color.dynamic(light: Self.palette[index], dark: Self.palette[index]).gradient)
            Text(verbatim: String(code.prefix(code.count > 4 ? 3 : code.count)))
                .font(.system(size: size * (code.count > 3 ? 0.26 : 0.32), weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .padding(4)
        }
    }
}

/// Стеклянный кружок выбора в стиле клавиш: пустой — не выбрано, с галочкой — выбрано.
private struct SelectionBubble: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(Color.amountHighlight)
            .opacity(isSelected ? 1 : 0)
            .scaleEffect(isSelected ? 1 : 0.4)
            .frame(width: 30, height: 30)
            .background {
                // Тот же стеклянный пузырь, что у клавиш; выбранный — с синим оттенком.
                Button(action: {}) { Color.clear.frame(width: 30, height: 30) }
                    .buttonStyle(GlassBubbleStyle(tint: isSelected ? .amountHighlight : .glassNeutral, prominentTint: isSelected))
                    .allowsHitTesting(false)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            .accessibilityHidden(true)
    }
}

/// Тег «PRO» у валют, доступных только с подпиской.
struct ProBadge: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text("PRO")
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .tracking(0.5)
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .frame(height: 22)
            // Стекло, как у кружков выбора: лёгкое свечение акцента внутри, белый ободок
            // и тонкая цветная обводка. В тёмной теме — как клавиши: светлая кромка сверху.
            .background {
                if colorScheme == .dark {
                    GlassBubbleBackground(tint: .accentColor, prominent: false, strongTint: true)
                } else {
                    ZStack {
                        Capsule().fill(Color.glassBase)
                        Capsule().fill(
                            RadialGradient(
                                colors: [Color.accentColor.opacity(0.24), Color.accentColor.opacity(0.06)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        Capsule().strokeBorder(
                            LinearGradient(
                                colors: [Color.glassRim, Color.glassRim.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                        Capsule().strokeBorder(Color.accentColor.opacity(0.55), lineWidth: 1)
                    }
                }
            }
            .modifier(ClearGlassOverlay())
            .accessibilityHidden(true)
    }
}

/// Строка выбора валюты с галочкой; без подписки сверх лимита — с тегом «PRO».
struct CurrencySelectRow: View {
    let currency: Currency
    let isSelected: Bool
    var isLocked = false

    var body: some View {
        HStack(spacing: 14) {
            CurrencyIcon(currency: currency)
            VStack(alignment: .leading, spacing: 3) {
                Text(currency.code)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.primary)
                Text(currency.name)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryLabel)
                    .lineLimit(1)
            }
            // Разделитель строк начинается под текстом, а не под флагом.
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
            Spacer(minLength: 12)
            if isLocked {
                ProBadge()
                    .transition(.scale.combined(with: .opacity))
            } else {
                SelectionBubble(isSelected: isSelected)
            }
        }
        .padding(.vertical, 4)
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
        CurrencySelectRow(currency: Currency(code: "JPY"), isSelected: false, isLocked: true)
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
