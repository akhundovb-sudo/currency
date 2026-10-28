import SwiftUI

/// Плашка подписки Pro в настройках: карточка в акцентном цвете приложения,
/// «Перейдите на Pro» — слово Pro стеклянное, подпись и стеклянная кнопка справа.
struct ProBanner: View {
    var onDetails: () -> Void = {}

    private let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

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
        .background { background }
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.15), lineWidth: 1))
        .shadow(color: Color(hex: 0x3A2E85).opacity(0.35), radius: 14, y: 6)
    }

    /// «Перейдите на Pro»: слово Pro — стеклянное; порядок слов из перевода.
    private var title: some View {
        let parts = L(.proBecome).components(separatedBy: "%@")
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
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

    /// Цвета экрана подписки: синий слева, фиолетовый справа, к низу темнее.
    private var background: some View {
        ZStack {
            // Синего больше: фиолетовый появляется только у правого края.
            LinearGradient(
                stops: [
                    .init(color: Color(hex: 0x2E3A9A), location: 0),
                    .init(color: Color(hex: 0x2B3488), location: 0.55),
                    .init(color: Color(hex: 0x45308A), location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            LinearGradient(
                colors: [.clear, Color.paywallInk.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
            // Мягкий блик в верхнем левом углу.
            RadialGradient(
                colors: [.white.opacity(0.12), .white.opacity(0)],
                center: UnitPoint(x: 0.15, y: 0),
                startRadius: 0,
                endRadius: 200
            )
            TwinklingSparkles()
        }
    }
}

/// Искорки на плашке: каждая по своему ритму плавно гаснет и загорается снова.
private struct TwinklingSparkles: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let sparkles: [(x: CGFloat, y: CGFloat, size: CGFloat, period: Double, phase: Double)] = [
        (0.25, 0.18, 9, 2.6, 0.0), (0.58, 0.28, 7, 3.4, 1.3), (0.42, 0.85, 8, 2.9, 2.1),
        (0.78, 0.82, 6, 3.8, 0.6), (0.93, 0.15, 7, 3.1, 2.7), (0.48, 0.1, 6, 4.2, 1.8),
        (0.68, 0.55, 5, 2.4, 3.3),
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
                    Image(systemName: "sparkle")
                        .font(.system(size: sparkle.size))
                        .foregroundStyle(.white.opacity(0.05 + 0.6 * glow))
                        .scaleEffect(0.6 + 0.5 * glow)
                        .position(x: w * sparkle.x, y: h * sparkle.y)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Слово «Pro» без подложки — стеклянное само по себе: буквы залиты полупрозрачным
/// белым с ярким бликом сверху и резкой границей посередине, мягкое свечение вокруг.
private struct GlassProBadge: View {
    var body: some View {
        Text(verbatim: "Pro")
            // Крупнее, чем «Become a».
            .font(.system(size: 36, weight: .heavy, design: .rounded))
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
            // Лишняя высота крупного слова не раздвигает плашку:
            // отступы считаются от строки «Become a».
            .padding(.top, -12)
            .padding(.bottom, -3)
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
        .contentShape(Capsule())
        .scaleEffect(configuration.isPressed ? 0.94 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

extension Color {
    /// Нижний цвет градиента плашки Pro — глубокий оттенок акцента.
    static let proBannerDeep = Color.dynamic(light: 0x2A1A8C, dark: 0x1E1266)
}

#Preview {
    ProBanner()
        .padding()
}
