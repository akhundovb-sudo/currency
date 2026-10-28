import SwiftUI

/// Сплэш при запуске: продолжает системный экран запуска (тот же фон и знак ¢ на том же месте).
/// Знак чуть сжимается, как перед прыжком, а потом стремительно растёт и превращается в окно:
/// сквозь его форму проступает список валют, пока окно не закроет весь экран.
struct SplashView: View {
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now

    /// Самая толстая точка знака (доли картинки): масштаб растёт от неё, чтобы раскрываться
    /// линией знака, а не его пустой серединой.
    private static let anchor = UnitPoint(x: 0.352, y: 0.303)

    private let holdUntil = 0.25      // знак стоит, как на экране запуска
    private let squeezeEnd = 0.5      // чуть сжимается
    private let revealEnd = 1.05      // раскрывается на весь экран

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
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.6 : revealEnd))
            onFinish()
        }
    }

    @ViewBuilder
    private func frame(at t: Double) -> some View {
        if reduceMotion {
            // Без движения: знак и фон просто растворяются.
            ZStack {
                Color("SplashBackground")
                Image("SplashLogo")
            }
            .opacity(1 - smoothstep(0.2, 0.6, t))
        } else {
            let squeeze = smoothstep(holdUntil, squeezeEnd, t)
            // Рост с ускорением: сначала плавно, потом стремительно.
            let grow = pow(min(1, max(0, (t - squeezeEnd) / (revealEnd - squeezeEnd))), 2.4)
            let scale = 1 - 0.12 * squeeze + 80 * grow
            // Знак перестаёт быть лавандовым и становится окном в самом начале роста.
            let windowed = smoothstep(squeezeEnd, squeezeEnd + 0.08, t)

            ZStack {
                // Фон с вырезом в форме знака.
                Color("SplashBackground")
                    .mask {
                        Rectangle()
                            .overlay {
                                Image("SplashLogo")
                                    .scaleEffect(scale, anchor: Self.anchor)
                                    .blendMode(.destinationOut)
                                    .opacity(windowed)
                            }
                            .compositingGroup()
                    }
                // Сам знак — пока он ещё не окно.
                Image("SplashLogo")
                    .scaleEffect(scale, anchor: Self.anchor)
                    .opacity(1 - windowed)
            }
            // Хвост: если кусочек фона остался по краям — растворяется.
            .opacity(1 - smoothstep(revealEnd - 0.15, revealEnd, t))
        }
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
