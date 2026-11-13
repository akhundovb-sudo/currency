import SwiftUI

/// Значок сканера цен: стеклянный круг с лавандовым оттенком акцента — полупрозрачная заливка,
/// блик сверху и светлый ободок, без свечения. Внутри иконка камеры (уголки контуром 2 pt, камера залита).
/// Общий для приложения (раздел «Виджеты») и самого виджета.
struct ScanMark: View {
    var size: CGFloat = 56

    @Environment(\.colorScheme) private var colorScheme

    /// Лаванда акцентных кнопок (`accentButton`), сама подстраивается под тему.
    static let accent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xE9 / 255, green: 0xB3 / 255, blue: 0xFB / 255, alpha: 1)
            : UIColor(red: 0xDA / 255, green: 0x9C / 255, blue: 0xF6 / 255, alpha: 1)
    })

    /// Цвета акцентных кнопок: `accentButton` (лаванда) и `onAccent` (сливовый текст на ней).
    private var lavender: Color {
        colorScheme == .dark
            ? Color(red: 0xE9 / 255, green: 0xB3 / 255, blue: 0xFB / 255)
            : Color(red: 0xDA / 255, green: 0x9C / 255, blue: 0xF6 / 255)
    }
    private let plum = Color(red: 0x4A / 255, green: 0x05 / 255, blue: 0x30 / 255)

    var body: some View {
        let isDark = colorScheme == .dark
        Image("icon-scan")
            .resizable()
            .scaledToFit()
            .frame(width: size * 0.5, height: size * 0.5)
            .foregroundStyle(isDark ? lavender : plum)
            .frame(width: size, height: size)
            .background {
                ZStack {
                    // Стекло с оттенком лаванды.
                    Circle().fill(lavender.opacity(isDark ? 0.16 : 0.32))
                    // Блик сверху, гаснет к середине.
                    Circle().fill(
                        LinearGradient(
                            colors: [.white.opacity(isDark ? 0.16 : 0.5), .white.opacity(0)],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    // Светлый ободок сверху, почти незаметный снизу.
                    Circle().strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(isDark ? 0.35 : 0.9), .white.opacity(isDark ? 0.05 : 0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                }
            }
    }
}
