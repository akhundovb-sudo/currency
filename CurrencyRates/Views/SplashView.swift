import SwiftUI

/// Сплэш при запуске — под выбранную иконку: её фон на весь экран, в центре знак.
/// 1. Знак мягко появляется, за ним разгорается свечение, по самому знаку проходит блик.
/// 2. Знак чуть сжимается, как перед прыжком.
/// 3. Стремительно растёт и превращается в окно: сквозь его форму проступает список,
///    который в этот момент чуть приближается и встаёт на место.
struct SplashView: View {
    /// Начало раскрытия — список под сплэшем запускает своё приближение.
    var onReveal: () -> Void = {}
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now

    /// Картинка знака (прозрачная, в рамке иконки) рисуется этого размера.
    private let artSize: CGFloat = 240
    private let appearEnd = 0.3
    private let squeezeStart = 0.75
    private let squeezeEnd = 0.92
    private let revealEnd = 1.45

    private struct Style {
        let image: String
        let background: Color
        let glow: Color
        /// Самая толстая точка знака — от неё растёт окно.
        let anchor: UnitPoint
    }

    private var style: Style {
        let name = UIApplication.shared.alternateIconName?.replacingOccurrences(of: "AppIcon-", with: "") ?? "Chrome"
        let table: [String: (UInt32, UInt32, CGFloat, CGFloat)] = [
            "Chrome": (0x000000, 0xE8ECF4, 0.283, 0.477),
            "Knit": (0x07031C, 0xC9A7F5, 0.286, 0.511),
            "Rubber": (0xF3F1F1, 0x9A9AA0, 0.504, 0.267),
            "Stone": (0xCAC5C5, 0x8E8A88, 0.448, 0.758),
            "Blocks": (0x07031C, 0xFFD34D, 0.512, 0.691),
            "Doodle": (0xE9E9E9, 0xFF7A1A, 0.540, 0.768),
            "Amethyst": (0x07031C, 0xC9A7F5, 0.394, 0.275),
            "Sticker": (0xCC9DF1, 0xFFFFFF, 0.394, 0.257),
            "Puffy": (0x07031C, 0x9C8BFF, 0.273, 0.507),
            "Sponge": (0x07031C, 0xC9A7F5, 0.264, 0.481),
            "Plush": (0x07031C, 0xC9A7F5, 0.444, 0.582),
            "Gummy": (0x02000E, 0xFF5A5A, 0.289, 0.501),
            "Bubbles": (0x02000E, 0xC9A7F5, 0.619, 0.740),
            "Holo": (0x02000E, 0x8FE3FF, 0.263, 0.506),
        ]
        let v = table[name] ?? table["Chrome"]!
        return Style(image: "SplashIcon-\(name)", background: Color(hex: v.0), glow: Color(hex: v.1), anchor: UnitPoint(x: v.2, y: v.3))
    }

    var body: some View {
        TimelineView(.animation) { context in
            frame(at: context.date.timeIntervalSince(start))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            start = .now
            if reduceMotion {
                try? await Task.sleep(for: .seconds(0.5))
                onReveal()
                try? await Task.sleep(for: .seconds(0.35))
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
        let style = style
        if reduceMotion {
            ZStack {
                Color("SplashBackground")
                style.background.opacity(smoothstep(0, 0.2, t))
                mark(style, scale: 1)
            }
            .opacity(1 - smoothstep(0.5, 0.85, t))
        } else {
            let appear = smoothstep(0, appearEnd, t)
            let squeeze = backOut((t - squeezeStart) / (squeezeEnd - squeezeStart))
            let grow = pow(min(1, max(0, (t - squeezeEnd) / (revealEnd - squeezeEnd))), 2.6)
            let scale = 0.92 + 0.08 * appear - 0.12 * squeeze + 40 * grow
            let windowed = smoothstep(squeezeEnd, squeezeEnd + 0.05, t)
            let sweep = (t - 0.22) / 0.5

            ZStack {
                // Фон с вырезом в форме знака — окно в список.
                ZStack {
                    Color("SplashBackground")
                    style.background.opacity(appear)
                    RadialGradient(colors: [style.glow.opacity(0.22), .clear], center: .center, startRadius: 0, endRadius: 260)
                        .opacity(appear * (1 - windowed))
                }
                .mask {
                    Rectangle()
                        .overlay {
                            mark(style, scale: scale)
                                .blendMode(.destinationOut)
                                .opacity(windowed)
                        }
                        .compositingGroup()
                }

                // Сам знак с бликом — пока он ещё не окно.
                mark(style, scale: scale)
                    .overlay {
                        if sweep > -0.2 && sweep < 1.2 {
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: max(0, sweep - 0.12)),
                                    .init(color: .white.opacity(0.3), location: min(1, max(0, sweep))),
                                    .init(color: .clear, location: min(1, sweep + 0.12)),
                                ],
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                            )
                            .frame(width: artSize, height: artSize)
                            .scaleEffect(scale, anchor: style.anchor)
                            .mask(mark(style, scale: scale))
                            .blendMode(.screen)
                        }
                    }
                    .shadow(color: style.glow.opacity(0.35 * appear), radius: 22)
                    .opacity(appear * (1 - windowed))
            }
            .opacity(1 - smoothstep(revealEnd - 0.12, revealEnd, t))
        }
    }

    private func mark(_ style: Style, scale: Double) -> some View {
        Image(style.image)
            .resizable()
            .frame(width: artSize, height: artSize)
            .scaleEffect(scale, anchor: style.anchor)
    }

    /// 0…1 с небольшим перелётом — сжатие «пружинит».
    private func backOut(_ x: Double) -> Double {
        let t = min(1, max(0, x))
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
