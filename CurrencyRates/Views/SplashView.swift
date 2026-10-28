import SwiftUI

/// Сплэш при запуске: продолжает системный экран запуска (тот же фон и знак ¢ на том же месте).
/// 1. За знаком разгорается мягкое лавандовое свечение, по знаку пробегает блик.
/// 2. Знак сжимается, как перед прыжком.
/// 3. Стремительно растёт и превращается в окно со светящимися краями: сквозь его форму
///    проступает список, который в этот момент чуть «приближается» и встаёт на место.
struct SplashView: View {
    /// Начало раскрытия — список под сплэшем запускает своё приближение.
    var onReveal: () -> Void = {}
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now

    /// Самая толстая точка знака (доли картинки): масштаб растёт от неё, чтобы раскрываться
    /// линией знака, а не его пустой серединой.
    private static let anchor = UnitPoint(x: 0.352, y: 0.303)
    private static let glow = Color(hex: 0xE299FF)

    private let glowEnd = 0.45        // свечение и блик
    private let squeezeStart = 0.5
    private let squeezeEnd = 0.68     // сжатие перед прыжком
    private let revealEnd = 1.2       // окно на весь экран

    var body: some View {
        TimelineView(.animation) { context in
            frame(at: context.date.timeIntervalSince(start))
        }
        .ignoresSafeArea()
        .environment(\.layoutDirection, .leftToRight)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            start = .now
            if reduceMotion {
                try? await Task.sleep(for: .seconds(0.6))
                onReveal()
                onFinish()
                return
            }
            try? await Task.sleep(for: .seconds(squeezeEnd))
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            onReveal()
            try? await Task.sleep(for: .seconds(revealEnd - squeezeEnd))
            onFinish()
        }
    }

    @ViewBuilder
    private func frame(at t: Double) -> some View {
        if reduceMotion {
            ZStack {
                Color("SplashBackground")
                Image("SplashLogo")
            }
            .opacity(1 - smoothstep(0.2, 0.6, t))
        } else {
            let bloom = smoothstep(0, glowEnd, t)
            // Знак чуть «дышит» вперёд, потом сжимается с упругим отскоком назад.
            let breathe = 0.05 * sin(min(1, t / squeezeStart) * .pi / 2)
            let squeeze = springy((t - squeezeStart) / (squeezeEnd - squeezeStart))
            let grow = pow(min(1, max(0, (t - squeezeEnd) / (revealEnd - squeezeEnd))), 2.6)
            let scale = 1 + breathe - (0.17 + breathe) * squeeze + 90 * grow
            let windowed = smoothstep(squeezeEnd, squeezeEnd + 0.06, t)
            // Блик проходит по знаку сверху справа вниз влево.
            let sweep = (t - 0.12) / 0.45

            ZStack {
                // Фон: в центре — мягкое свечение, по краям окна — светящаяся кромка.
                ZStack {
                    Color("SplashBackground")
                    RadialGradient(
                        colors: [Self.glow.opacity(0.35), Self.glow.opacity(0.08), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 300
                    )
                    .opacity(bloom * (1 - windowed))
                    // Светящаяся кромка окна: размытый силуэт знака под вырезом.
                    logo(scale: scale)
                        .colorMultiply(Self.glow)
                        .blur(radius: 14)
                        .opacity(windowed)
                }
                .mask {
                    Rectangle()
                        .overlay {
                            logo(scale: scale)
                                .blendMode(.destinationOut)
                                .opacity(windowed)
                        }
                        .compositingGroup()
                }

                // Сам знак — пока он ещё не окно: со свечением и бликом.
                logo(scale: scale)
                    .overlay {
                        if sweep > -0.2 && sweep < 1.2 {
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: max(0, sweep - 0.16)),
                                    .init(color: .white.opacity(0.8), location: min(1, max(0, sweep))),
                                    .init(color: .clear, location: min(1, sweep + 0.16)),
                                ],
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                            )
                            .mask(logo(scale: scale))
                            .blendMode(.screen)
                        }
                    }
                    .shadow(color: Self.glow.opacity(0.6 * bloom), radius: 24)
                    .opacity(1 - windowed)
            }
            .opacity(1 - smoothstep(revealEnd - 0.12, revealEnd, t))
        }
    }

    private func logo(scale: Double) -> some View {
        Image("SplashLogo")
            .scaleEffect(scale, anchor: Self.anchor)
    }

    /// 0…1 с лёгким перелётом в конце — сжатие «пружинит».
    private func springy(_ x: Double) -> Double {
        let t = min(1, max(0, x))
        // back-out: доходит до ~1,1 и возвращается к 1.
        let c = 1.7
        return 1 + (c + 1) * pow(t - 1, 3) + c * pow(t - 1, 2)
    }

    private func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = min(1, max(0, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }
}

#Preview {
    ZStack {
        Color.white
        SplashView(onFinish: {})
    }
}
