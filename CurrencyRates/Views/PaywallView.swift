import SwiftUI

/// Экран подписки Pro: тёмный фон в цвете акцента со звёздами, выбор тарифа,
/// что входит в Pro, большая кнопка и ссылки внизу.
/// Цены и покупка — через StoreKit (`Purchases`).
struct PaywallView: View {
    @Environment(RatesStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var plan: Plan = .yearly
    @State private var message: String?
    private let purchases = Purchases.shared

    typealias Plan = ProPlan

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
        .task { if purchases.products.isEmpty { await purchases.loadProducts() } }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private var isBusy: Bool { purchases.state != .idle }

    private func buy() async {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch await purchases.purchase(plan) {
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        case .cancelled:
            break
        case .pending:
            message = L(.purchasePending)
        case .failed:
            message = purchases.products.isEmpty ? L(.pricesUnavailable) : L(.purchaseFailed)
        }
    }

    private func restore() async {
        if await purchases.restore() {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } else {
            message = L(.nothingToRestore)
        }
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
        // Без заголовка — только крестик слева, как в настройках, но на прозрачном стекле.
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background {
                        Circle()
                            .fill(.white.opacity(0.08))
                            .overlay(
                                Circle().strokeBorder(
                                    LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.06)], startPoint: .top, endPoint: .bottom),
                                    lineWidth: 1
                                )
                            )
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel(L(.close))
            Spacer()
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
                            Text(item.title)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.white)
                            Text(purchases.priceText(for: item))
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer(minLength: 8)
                        if item == .yearly {
                            BestValueBadge()
                        }
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
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
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
                .opacity(purchases.hasTrial(plan) ? 1 : 0)
                .animation(.snappy, value: plan)
            Button {
                Task { await buy() }
            } label: {
                ZStack {
                    Text(purchases.hasTrial(plan) ? L(.startTrial) : L(.getFullAccess))
                        .contentTransition(.opacity)
                        .opacity(purchases.state == .purchasing ? 0 : 1)
                    if purchases.state == .purchasing {
                        ProgressView().tint(Color.onAccent)
                    }
                }
                .font(.headline)
                .foregroundStyle(Color.onAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Capsule().fill(Color.accentColor))
                .shadow(color: Color.accentColor.opacity(0.5), radius: 16, y: 6)
            }
            .buttonStyle(PressScaleStyle())
            .disabled(isBusy)

            HStack(spacing: 10) {
                Link(L(.terms), destination: AppLinks.terms)
                Text(verbatim: "·")
                Link(L(.privacy), destination: AppLinks.privacy)
                Text(verbatim: "·")
                Button(L(.restore)) { Task { await restore() } }
                    .disabled(isBusy)
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
                colors: [Color.proIndigo, Color.proViolet],
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
            .foregroundStyle(Color.onAccent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                // Объём: сверху светлее, книзу темнее, глянцевый блик в верхней половине,
                // светлая кромка сверху и тень под меткой.
                GeometryReader { proxy in
                    ZStack {
                        Capsule().fill(Color.accentColor)
                        Capsule().fill(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .clear, .black.opacity(0.22)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        Capsule()
                            .fill(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                            .frame(height: proxy.size.height * 0.45)
                            .padding(.horizontal, proxy.size.height * 0.3)
                            .padding(.top, 2)
                            .frame(maxHeight: .infinity, alignment: .top)
                        Capsule().strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.7), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom),
                            lineWidth: 1
                        )
                    }
                }
                .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
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
