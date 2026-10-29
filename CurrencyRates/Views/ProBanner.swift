import SwiftUI

/// Плашка подписки Pro в настройках: карточка в акцентном цвете приложения,
/// «Перейдите на Pro» — слово Pro стеклянное, подпись и стеклянная кнопка справа.
struct ProBanner: View {
    var onDetails: () -> Void = {}

    private let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                title
                Text(L(.proSubscription))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 4)
            Button(action: onDetails) {
                Text(L(.upgrade))
                    .font(.headline)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 18)
                    .frame(height: 44)
            }
            .buttonStyle(GlassPillButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background { ProBannerBackground() }
        .clipShape(shape)
        .shadow(color: Color.proIndigo.opacity(0.35), radius: 12, y: 6)
    }

    /// «Перейдите на Pro»: слово Pro — стеклянное; порядок слов из перевода.
    private var title: some View {
        let parts = L(.proBecome).components(separatedBy: "%@")
        return HStack(alignment: .firstTextBaseline, spacing: 5) {
            if let before = parts.first, !before.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(before.trimmingCharacters(in: .whitespaces))
            }
            GlassProBadge()
            if parts.count > 1, !parts[1].trimmingCharacters(in: .whitespaces).isEmpty {
                Text(parts[1].trimmingCharacters(in: .whitespaces))
            }
        }
        .font(.system(.title2, design: .rounded).weight(.bold))
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

}

/// Фон плашки — цвета экрана подписки: глубокий синий слева, фиолетовый справа,
/// мягкий блик в верхнем левом углу и мерцающие звёздочки.
struct ProBannerBackground: View {
    var body: some View {
        ZStack {
            // Те же цвета, что вверху экрана подписки: глубокий синий слева, фиолетовый справа.
            // Фиолетового справа больше: он начинается раньше и к краю чуть насыщеннее.
            LinearGradient(
                stops: [
                    .init(color: Color.proIndigo, location: 0),
                    .init(color: Color.proViolet, location: 0.6),
                    .init(color: Color(hex: 0x5A2E9A), location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            RadialGradient(
                colors: [.white.opacity(0.1), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 220
            )
            RadialGradient(
                colors: [Color.black.opacity(0.2), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 220
            )
            TwinklingSparkles()
        }
    }
}

/// Искорки на плашке: каждая по своему ритму плавно гаснет и загорается снова.
private struct TwinklingSparkles: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let sparkles: [(x: CGFloat, y: CGFloat, size: CGFloat, period: Double, phase: Double)] = [
        (0.58, 0.22, 9, 2.6, 0.0), (0.52, 0.78, 7, 3.4, 1.3), (0.36, 0.9, 6, 2.9, 2.1),
        (0.79, 0.85, 6, 3.8, 0.6), (0.95, 0.14, 7, 3.1, 2.7), (0.7, 0.08, 6, 4.2, 1.8),
        (0.66, 0.6, 5, 2.4, 3.3), (0.18, 0.95, 5, 3.6, 0.9), (0.44, 0.12, 5, 3.0, 2.4),
    ]

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let w = proxy.size.width, h = proxy.size.height
                ForEach(Array(Self.sparkles.enumerated()), id: \.offset) { _, sparkle in
                    // 0…1: большую часть периода искорка почти не видна, потом вспыхивает.
                    let wave = 0.5 + 0.5 * sin(time * 2 * .pi / sparkle.period + sparkle.phase)
                    let glow = reduceMotion ? 0.6 : pow(wave, 2)
                    // Тонкая четырёхлучевая звёздочка, как в референсе.
                    Image(systemName: "plus")
                        .font(.system(size: sparkle.size, weight: .light))
                        .foregroundStyle(.white.opacity(0.05 + 0.6 * glow))
                        .scaleEffect(0.6 + 0.5 * glow)
                        .position(x: w * sparkle.x, y: h * sparkle.y)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Плашка в настройках, когда Pro уже есть: стеклянное «Pro», какой тариф и цена,
/// у подписки — кнопка «Управлять» (подписки в App Store).
struct ProStatusCard: View {
    let plan: ProPlan?
    var onManage: () -> Void = {}

    private let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                // Значок — по центру высоты букв «Pro».
                HStack(alignment: .center, spacing: 8) {
                    GlassProBadge()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.9))
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 4)
            // Без тарифа (Pro включён вручную) кнопка тоже нужна — иначе плашка выглядит пустой.
            if plan?.isSubscription ?? true {
                Button(action: onManage) {
                    Text(L(.manageSubscription))
                        .font(.headline)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                }
                .buttonStyle(GlassPillButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background { ProBannerBackground() }
        .clipShape(shape)
        .shadow(color: Color.proIndigo.opacity(0.35), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
    }

    /// «Pro активен · Год · $9.99 / год»; пока цена не загрузилась — без неё.
    private var subtitle: String {
        guard let plan else { return L(.proActive) }
        let price = Purchases.shared.priceText(for: plan)
        return price == "…" ? "\(L(.proActive)) · \(plan.title)" : "\(L(.proActive)) · \(plan.title) · \(price)"
    }
}

/// Слово «Pro» без подложки — стеклянное само по себе: буквы залиты полупрозрачным
/// белым с ярким бликом сверху и резкой границей посередине, мягкое свечение вокруг.
private struct GlassProBadge: View {
    var body: some View {
        Text(verbatim: "Pro")
            // Чуть крупнее «Become a», как в референсе.
            .font(.system(size: 27, weight: .heavy, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white.opacity(0.92), location: 0.45),
                        .init(color: .white.opacity(0.6), location: 0.55),
                        .init(color: .white.opacity(0.85), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: .white.opacity(0.5), radius: 8)
            .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
            // Свечение не раздвигает строку.
            .padding(.vertical, -4)
    }
}

/// Стеклянная кнопка на цветной плашке: на iOS 26 — настоящее Liquid Glass
/// (преломляет фон и реагирует на нажатие), раньше — матовое стекло с бликом и ободком.
private struct GlassPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
        Group {
            if #available(iOS 26, *) {
                label
                    .glassEffect(.clear.tint(.white.opacity(0.12)).interactive(), in: Capsule())
            } else {
                label
                    .background {
                        ZStack {
                            Capsule().fill(.ultraThinMaterial)
                            Capsule().fill(.white.opacity(0.12))
                            Capsule().fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.4), .white.opacity(0)],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            Capsule().strokeBorder(
                                LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.25)], startPoint: .top, endPoint: .bottom),
                                lineWidth: 1
                            )
                        }
                        .environment(\.colorScheme, .light)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    }
            }
        }
        // Блик бежит по ободку кнопки — как в референсе.
        .overlay { RunningRimHighlight() }
        .contentShape(Capsule())
        .scaleEffect(configuration.isPressed ? 0.94 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

/// Светлая дуга, которая плавно обходит ободок капсулы по кругу (оборот ~3 с).
private struct RunningRimHighlight: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let angle = reduceMotion ? -90 : (time / 3).truncatingRemainder(dividingBy: 1) * 360
            Capsule()
                .strokeBorder(
                    AngularGradient(
                        stops: [
                            .init(color: .white.opacity(0), location: 0),
                            .init(color: .white.opacity(0.95), location: 0.08),
                            .init(color: .white.opacity(0), location: 0.2),
                            .init(color: .white.opacity(0), location: 0.5),
                            .init(color: .white.opacity(0.5), location: 0.58),
                            .init(color: .white.opacity(0), location: 0.7),
                            .init(color: .white.opacity(0), location: 1),
                        ],
                        center: .center,
                        angle: .degrees(angle)
                    ),
                    lineWidth: 1.5
                )
        }
        .allowsHitTesting(false)
    }
}

extension Color {
    /// Цвета Pro (плашка и экран подписки): глубокий синий и фиолетовый.
    static let proIndigo = Color(hex: 0x2B3488)
    static let proViolet = Color(hex: 0x4A2A80)
    /// Нижний цвет градиента плашки Pro — глубокий оттенок акцента.
    static let proBannerDeep = Color.dynamic(light: 0x2A1A8C, dark: 0x1E1266)
}

#Preview {
    ProBanner()
        .padding()
}
