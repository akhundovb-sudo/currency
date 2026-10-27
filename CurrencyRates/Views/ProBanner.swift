import SwiftUI

/// Плашка подписки Pro в настройках: тёмно-синяя карточка со свечением цвета акцента,
/// название приложения с тегом «PRO», подпись и светлая кнопка «Подробнее».
struct ProBanner: View {
    var onDetails: () -> Void = {}

    private let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Text(L(.title))
                    .font(.system(.title, design: .rounded).weight(.bold))
                Text(verbatim: "PRO")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(Color.proBannerDeep)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(Capsule().fill(.white))
            }
            .foregroundStyle(.white)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)

            Button(action: onDetails) {
                Text(L(.seeDetails))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(ProBannerButtonStyle())
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background { background }
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .shadow(color: Color.accentColor.opacity(0.25), radius: 16, y: 6)
    }

    /// «Откройте PRO …» — слово PRO выделено жирным.
    private var subtitle: Text {
        let parts = L(.proDiscover).components(separatedBy: "%@")
        var pro = AttributedString("PRO")
        pro.inlinePresentationIntent = .stronglyEmphasized
        var result = AttributedString(parts.first ?? "")
        result += pro
        result += AttributedString(parts.count > 1 ? parts[1] : "")
        return Text(result)
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color.proBannerTop, Color.proBannerDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // Свечение акцентного цвета снизу по центру, как блик в макете.
            RadialGradient(
                colors: [Color.accentColor.opacity(0.7), Color.accentColor.opacity(0)],
                center: UnitPoint(x: 0.5, y: 0.75),
                startRadius: 0,
                endRadius: 180
            )
            // Две тонкие дуги через карточку.
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                        .frame(width: width * 1.6, height: width * 1.6)
                        .offset(y: width * 0.95)
                    Circle()
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                        .frame(width: width * 2.2, height: width * 2.2)
                        .offset(y: width * 1.2)
                }
                .frame(width: width, height: proxy.size.height)
            }
        }
    }
}

/// Светлая кнопка на тёмной плашке: почти белая заливка, тонкий ободок цвета акцента.
private struct ProBannerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        configuration.label
            .foregroundStyle(Color.proBannerDeep)
            .background {
                shape
                    .fill(.white.opacity(0.95))
                    .overlay(shape.strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1.5))
            }
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

extension Color {
    /// Фон плашки Pro — тёмные оттенки акцентного синего; плашка тёмная в обеих темах.
    static let proBannerTop = Color.dynamic(light: 0x123B66, dark: 0x0F3358)
    static let proBannerDeep = Color.dynamic(light: 0x0A1A30, dark: 0x081526)
}

#Preview {
    ProBanner()
        .padding()
}
