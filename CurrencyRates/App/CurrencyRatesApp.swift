import SwiftUI
import UIKit

@main
struct CurrencyRatesApp: App {
    @State private var store = RatesStore.live()
    @State private var location = LocationService()
    /// Сплэш поверх списка при запуске; сам убирается после анимации.
    @State private var showsSplash = true
    /// Список под сплэшем: чуть увеличен и встаёт на место, когда сплэш раскрывается.
    @State private var contentScale: CGFloat = 1.08

    init() {
        // Системная панель полностью прозрачная на всех версиях iOS: у её размытия резкий
        // нижний край, а вид системного края прокрутки меняется от версии к версии.
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
                .scaleEffect(contentScale)
                .environment(store)
                .environment(\.locale, store.language.locale)
                .environment(\.layoutDirection, store.language.isRightToLeft ? .rightToLeft : .leftToRight)
                .onAppear { applyTheme(store.theme) }
                .onChange(of: store.theme) { _, theme in applyTheme(theme) }
                // Pro закончился — иконка из Pro возвращается к основной.
                .onChange(of: store.isPro, initial: true) { _, isPro in resetProIconIfNeeded(isPro: isPro) }
                .task { await store.refresh() }
                // Покупки: цены, текущий доступ Pro и слежение за подпиской.
                .task { Purchases.shared.start(store) }
                // Первая валюта — местная, по геолокации; без неё — доллар и евро.
                .task { requestCountry() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        applyTheme(store.theme)
                        Task { await store.refreshIfStale() }
                        // Вернулись в приложение (может быть, уже в другой стране) — для «Путешествия».
                        requestCountry()
                    } else {
                        // Уходим с экрана — виджеты получают последние валюты и суммы.
                        WidgetBridge.publish(store)
                    }
                }
                // Новые курсы — сразу и в виджеты.
                .onChange(of: store.snapshot) { _, _ in WidgetBridge.publish(store) }
                // Подписка меняет, какие валюты доступны в виджетах.
                .onChange(of: store.isPro) { _, _ in WidgetBridge.publish(store) }
                .overlay {
                    if showsSplash {
                        SplashView(
                            onReveal: { withAnimation(.smooth(duration: 0.7)) { contentScale = 1 } },
                            onFinish: { showsSplash = false }
                        )
                    }
                }
                .statusBarHidden(showsSplash)
        }
    }

    /// Страна по геолокации: в первый раз её валюта становится первой в списке,
    /// а виджет «Путешествие» всегда показывает валюту страны, где вы сейчас.
    private func requestCountry() {
        location.requestLocalCurrency { currency, country in
            store.applyLocalCurrency(currency)
            store.updateCurrentCountry(country, currency: currency)
            WidgetBridge.publish(store)
        }
    }

    private func resetProIconIfNeeded(isPro: Bool) {
        guard !isPro, let name = UIApplication.shared.alternateIconName,
              AppIconPicker.proIconNames.contains(name) else { return }
        UIApplication.shared.setAlternateIconName(nil)
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
