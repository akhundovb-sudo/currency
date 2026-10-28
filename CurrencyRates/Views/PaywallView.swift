import SwiftUI

/// Экран подписки Pro: тёмный фон в цвете акцента со звёздами, выбор тарифа,
/// что входит в Pro, большая кнопка и ссылки внизу.
/// Покупки (StoreKit) ещё не подключены: цены — заглушки, кнопка включает тестовый Pro.
struct PaywallView: View {
    @Environment(RatesStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var plan: Plan = .yearly

    enum Plan: CaseIterable, Identifiable {
        case monthly, yearly, lifetime
        var id: Self { self }

        var title: String {
            switch self {
            case .monthly: L(.planMonthly)
            case .yearly: L(.planYearly)
            case .lifetime: L(.planLifetime)
            }
        }

        /// У подписок 7 дней бесплатно, у покупки навсегда пробного периода нет.
        var hasTrial: Bool { self != .lifetime }

        /// Цены-заглушки, пока не подключён StoreKit: реальные придут из App Store.
        /// Год — почти в 2,5 раза дешевле помесячной оплаты, навсегда — как два года.
        var price: String {
            switch self {
            case .monthly: L(.perMonth, "$1.99")
            case .yearly: L(.perYear, "$9.99")
            case .lifetime: L(.oneTime, "$19.99")
            }
        }
    }

    var body: some View {
        ZStack {
            PaywallBackground()

            ScrollView {
                VStack(spacing: 28) {
                    Text(L(.proHeadline))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.top, 8)

                    plans

                    VStack(alignment: .leading, spacing: 14) {
                        Text(L(.included))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                        ForEach(features, id: \.title) { feature in
                            Label {
                                Text(feature.title)
                            } icon: {
                                Image(systemName: feature.icon)
                                    .font(.body.weight(.semibold))
                                    .frame(width: 28)
                            }
                            .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        }
        .environment(\.colorScheme, .dark)
        // Светлый статус-бар на тёмном фоне.
        .preferredColorScheme(.dark)
        .environment(\.layoutDirection, store.language.isRightToLeft ? .rightToLeft : .leftToRight)
    }

    /// Что входит в Pro — иконка и подпись.
    private var features: [(icon: String, title: String)] {
        [
            ("square.stack.3d.up", L(.featUnlimited)),
            ("globe", L(.featFiat)),
            ("bitcoinsign.circle", L(.featCrypto)),
            ("heart", L(.featSupport)),
        ]
    }

    private var header: some View {
        // Без заголовка — только кнопка закрытия справа.
        ZStack {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(.white.opacity(0.15)))
                }
                .accessibilityLabel(L(.close))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var plans: some View {
        VStack(spacing: 0) {
            ForEach(Array(Plan.allCases.enumerated()), id: \.element) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(.white.opacity(0.2))
                        .frame(height: 1)
                }
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.snappy) { plan = item }
                } label: {
                    HStack(spacing: 14) {
                        checkbox(isOn: plan == item)
                        VStack(alignment: .leading, spacing: 2) {
                            // Метка рядом с названием — так подпись с ценой помещается в строку.
                            HStack(spacing: 8) {
                                Text(item.title)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.white)
                                if item == .yearly {
                                    BestValueBadge()
                                }
                            }
                            Text(item.price)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(plan == item ? .isSelected : [])
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
        }
    }

    private func checkbox(isOn: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        return ZStack {
            shape.strokeBorder(.white.opacity(isOn ? 0 : 0.5), lineWidth: 1.5)
            if isOn {
                shape.fill(.white)
                Image(systemName: "checkmark")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Color.paywallInk)
            }
        }
        .frame(width: 26, height: 26)
    }

    private var footer: some View {
        VStack(spacing: 14) {
            // Над кнопкой — про пробный период, пока выбрана подписка.
            Label(L(.trialNote), systemImage: "gift")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
                .opacity(plan.hasTrial ? 1 : 0)
                .animation(.snappy, value: plan)
            Button {
                // Пока нет StoreKit — включает тестовый Pro, как переключатель в настройках.
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                store.isPro = true
                dismiss()
            } label: {
                Text(plan.hasTrial ? L(.startTrial) : L(.getFullAccess))
                    .contentTransition(.opacity)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Capsule().fill(Color.accentColor))
                    .shadow(color: Color.accentColor.opacity(0.5), radius: 16, y: 6)
            }
            .buttonStyle(PressScaleStyle())

            HStack(spacing: 10) {
                Text(L(.terms))
                Text(verbatim: "·")
                Text(L(.privacy))
                Text(verbatim: "·")
                Button(L(.restore)) {}
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white.opacity(0.85))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

/// Фон экрана подписки, как в примере: сверху глубокий синий слева и фиолетовый справа,
/// к середине уходит в почти чёрный. Звёзды гаснут и загораются, как искорки на плашке Pro.
private struct PaywallBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.paywallInk
            LinearGradient(
                colors: [Color(hex: 0x2B3488), Color(hex: 0x4A2A80)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black.opacity(0.75), location: 0.2),
                        .init(color: .clear, location: 0.6),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            TimelineView(.animation(paused: reduceMotion)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    var generator = SeededRandom(seed: 7)
                    for _ in 0..<90 {
                        let x = generator.next() * size.width
                        let y = generator.next() * size.height
                        let r = 0.8 + generator.next() * 1.4
                        let period = 2.2 + generator.next() * 2.8   // секунды на вспышку
                        let phase = generator.next() * .pi * 2
                        let peak = 0.5 + generator.next() * 0.5
                        // Каждая звезда в своём ритме гаснет почти до нуля и загорается снова.
                        let wave = 0.5 + 0.5 * sin(time * 2 * .pi / period + phase)
                        let glow = reduceMotion ? 0.6 : pow(wave, 2)
                        let d = r * (0.6 + 0.6 * glow)
                        context.fill(
                            Path(ellipseIn: CGRect(x: x - d / 2, y: y - d / 2, width: d, height: d)),
                            with: .color(.white.opacity(peak * (0.04 + 0.96 * glow)))
                        )
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

extension Color {
    /// Почти чёрный низ экрана подписки и цвет текста на белой кнопке.
    static let paywallInk = Color(hex: 0x111016)

    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Метка «BEST VALUE» — стеклянная капсула в акцентном цвете приложения:
/// полупрозрачный фиолетовый, блик сверху и светлый ободок.
private struct BestValueBadge: View {
    var body: some View {
        Text(L(.bestValue))
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                ZStack {
                    Capsule().fill(.ultraThinMaterial)
                    Capsule().fill(Color.accentColor.opacity(0.55))
                    Capsule().fill(
                        LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0)], startPoint: .top, endPoint: .center)
                    )
                    Capsule().strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.8), .white.opacity(0.2)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
                }
            }
    }
}

/// Простой детерминированный генератор, чтобы звёзды стояли на месте между перерисовками.
private struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(state >> 33) / CGFloat(UInt32.max >> 1)
    }
}

/// Лёгкое сжатие при нажатии.
private struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    PaywallView()
        .environment(RatesStore.preview())
}
