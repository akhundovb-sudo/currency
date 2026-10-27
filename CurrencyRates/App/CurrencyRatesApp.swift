import SwiftUI
import UIKit

@main
struct CurrencyRatesApp: App {
    @State private var store = RatesStore.live()

    init() {
        // В iOS 26 у панели системный мягкий край прокрутки; своё оформление
        // возвращало бы старую панель с размытием и резкой нижней границей.
        if #available(iOS 26, *) { return }
        // Раньше iOS 26 системная панель полностью прозрачная: у её размытия резкий нижний край.
        // Плавное размытие под кнопками рисует TopFade.
        let standard = UINavigationBarAppearance()
        standard.configureWithTransparentBackground()
        standard.shadowColor = .clear
        let edge = UINavigationBarAppearance()
        edge.configureWithTransparentBackground()
        edge.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = standard
        UINavigationBar.appearance().compactAppearance = standard
        UINavigationBar.appearance().scrollEdgeAppearance = edge
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            CurrencyListView()
                .environment(store)
                .environment(\.locale, store.language.locale)
                .onAppear { applyTheme(store.theme) }
                .onChange(of: store.theme) { _, theme in applyTheme(theme) }
                .task { await store.refresh() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        applyTheme(store.theme)
                        Task { await store.refreshIfStale() }
                    }
                }
        }
    }

    /// Тема задаётся на уровне окна: так она сразу применяется и к открытым sheet,
    /// а «Системная» корректно возвращает оформление устройства
    /// (у `preferredColorScheme(nil)` с этим проблемы в открытых модальных окнах).
    private func applyTheme(_ theme: AppTheme) {
        let style: UIUserInterfaceStyle = switch theme {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
