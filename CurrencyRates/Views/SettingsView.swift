import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(RatesStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var isPaywallPresented = false
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var store = store

        NavigationStack {
            Form {
                // Без Pro — предложение подписки; с Pro — какой тариф куплен.
                Section {
                    Group {
                        if store.isPro {
                            ProStatusCard(plan: store.proPlan) { openURL(AppLinks.manageSubscriptions) }
                        } else {
                            ProBanner(onDetails: { isPaywallPresented = true })
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section {
                    // Язык — в системных настройках приложения.
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        LabeledContent {
                            HStack(spacing: 6) {
                                Text(store.language.nativeName).foregroundStyle(Color.secondaryLabel)
                                Image(systemName: "chevron.forward")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Color(.tertiaryLabel))
                            }
                        } label: {
                            rowLabel(L(.language), icon: "io-globe")
                        }
                    }
                    .foregroundStyle(Color.primary)
                    Picker(selection: $store.theme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    } label: {
                        rowLabel(L(.theme), icon: "io-half-moon")
                    }
                }

                Section {
                    NavigationLink { NumbersSettingsView() } label: {
                        rowLabel(L(.numbers), icon: "io-hashtag")
                    }
                    NavigationLink { RatesSettingsView() } label: {
                        rowLabel(L(.rates), icon: "io-coins-swap")
                    }
                    NavigationLink {
                        AppIconSettingsView(onLocked: { isPaywallPresented = true })
                    } label: {
                        rowLabel(L(.appIcon), icon: "io-palette")
                    }
                    NavigationLink { WidgetsGuideView() } label: {
                        rowLabel(L(.widgets), icon: "io-view-grid")
                    }
                    NavigationLink { LiveActivitySettingsView() } label: {
                        rowLabel(L(.liveActivity), icon: "io-airplane")
                    }
                }

                #if DEBUG
                // Только в сборке из Xcode: проверить бесплатную версию после тестовой покупки.
                Section {
                    Toggle(isOn: Bindable(Purchases.shared).ignoresPurchases) {
                        Text(verbatim: "Test: ignore purchases")
                    }
                } footer: {
                    Text(verbatim: "Debug builds only. Not shown in the App Store version.")
                }
                #endif

                Section {
                    ShareLink(item: AppLinks.share) {
                        linkRow(L(.shareApp), icon: "io-share-ios")
                    }
                    // Условия и конфиденциальность — одна строка, ведёт на страницу с документами.
                    Link(destination: AppLinks.legal) {
                        linkRow(L(.termsPrivacy), icon: "io-page", trailing: "arrow.up.right")
                    }
                }
            }
            // Подписи в меню выбора (тема, формат) кэшируются системой — при смене языка
            // форму пересобираем целиком, иначе они остаются на прежнем языке.
            .id(store.language)
            // Отступ сверху — как в окне добавления валют.
            .contentMargins(.top, 8, for: .scrollContent)
            // Модальные окна не наследуют направление письма — для арабского задаём сами.
            .environment(\.layoutDirection, store.language.isRightToLeft ? .rightToLeft : .leftToRight)
            .softTopBar()
            .fullScreenCover(isPresented: $isPaywallPresented) { PaywallView() }
            .navigationTitle(L(.settings))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Закрыть — круглая кнопка слева, как «Настройки» на главном экране.
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(CardBubbleStyle())
                    .accessibilityLabel(L(.close))
                }
                .hidingSharedGlass()
            }
        }
    }

    /// Подпись строки со значком слева: контурный серый значок Iconoir, текст основным.
    private func rowLabel(_ title: String, icon: String) -> some View {
        Label {
            Text(title).foregroundStyle(Color.primary)
        } icon: {
            // Значки Iconoir (iconoir.com, MIT) — в Assets/SettingsIcons.
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(Color.secondaryLabel)
        }
    }

    /// Строка-ссылка: значок и подпись слева, при необходимости значок справа.
    private func linkRow(_ title: String, icon: String, trailing: String? = nil) -> some View {
        HStack {
            rowLabel(title, icon: icon)
            Spacer()
            if let trailing {
                Image(systemName: trailing)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.secondaryLabel)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(RatesStore.preview())
}

/// Внутренняя страница настроек: заголовок, кнопка «Назад» и те же отступы, что на главной.
struct SettingsPage: ViewModifier {
    let title: String
    @Environment(RatesStore.self) private var store

    func body(content: Content) -> some View {
        content
            .contentMargins(.top, 8, for: .scrollContent)
            // Модальные окна не наследуют направление письма — для арабского задаём сами.
            .environment(\.layoutDirection, store.language.isRightToLeft ? .rightToLeft : .leftToRight)
            .softTopBar()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// Плашка-пояснение внизу страницы — как сообщения в приложении, только без крестика.
private struct NoticeSection: View {
    let toast: Toast

    var body: some View {
        Section {
            ToastView(toast: toast)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
    }
}

/// Настройки → «Числа»: формат и число знаков, пример — карточкой из списка валют.
private struct NumbersSettingsView: View {
    @Environment(RatesStore.self) private var store

    private var exampleCode: String {
        store.selectedCodes.first { $0 != store.sourceCode } ?? store.sourceCode
    }

    var body: some View {
        @Bindable var store = store

        Form {
            Section(L(.example)) {
                CurrencyRow(
                    code: exampleCode,
                    sourceCode: store.sourceCode,
                    value: RateFormat.amount(1234.56),
                    unitRate: store.unitRate(to: exampleCode)
                )
                .card(selected: false)
                .accessibilityRemoveTraits(.isButton)
                .animation(.snappy, value: store.numberStyle)
                .animation(.snappy, value: store.decimalPlaces)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                Picker(L(.numberFormat), selection: $store.numberStyle) {
                    ForEach(NumberStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                // −1 — «Авто», дальше 0…8 знаков.
                Stepper(
                    value: Binding(
                        get: { store.decimalPlaces ?? -1 },
                        set: { store.decimalPlaces = $0 >= 0 ? $0 : nil }
                    ),
                    in: -1...8
                ) {
                    LabeledContent(L(.decimalPlaces), value: store.decimalPlaces.map(String.init) ?? L(.auto))
                        .monospacedDigit()
                }
            }

            NoticeSection(toast: Toast(kind: .info, message: L(.tinyAmountsFooter)))
        }
        .modifier(SettingsPage(title: L(.numbers)))
    }
}

/// Настройки → «Курсы»: когда обновлялись, кнопка обновления и откуда данные.
private struct RatesSettingsView: View {
    @Environment(RatesStore.self) private var store

    var body: some View {
        Form {
            Section {
                sourceRow(.fiat)
                sourceRow(.crypto)
                Button {
                    Task { await store.refresh() }
                } label: {
                    HStack {
                        Text(L(.update))
                        Spacer()
                        if store.isLoading { ProgressView().controlSize(.small) }
                    }
                }
                .disabled(store.isLoading)
                .accessibilityLabel(L(.refreshRates))
            }

            NoticeSection(toast: Toast(kind: .info, message: String(sourcesFooter.characters), attributedMessage: sourcesFooter))
        }
        .modifier(SettingsPage(title: L(.rates)))
    }

    /// Тип курсов слева, время обновления справа.
    private func sourceRow(_ kind: CurrencyKind) -> some View {
        LabeledContent(kind == .fiat ? L(.fiatCurrencies) : L(.cryptoCurrencies), value: updatedText(kind))
    }

    /// «Данные: ExchangeRate-API и CoinGecko.» — названия ссылками, затем как часто обновляются курсы.
    private var sourcesFooter: AttributedString {
        let fiat = "[\(RatesService.fiatSourceName)](\(RatesService.fiatSourceURL.absoluteString))"
        let crypto = "[\(RatesService.cryptoSourceName)](\(RatesService.cryptoSourceURL.absoluteString))"
        let markdown = L(.dataSources, fiat, crypto) + " " + L(.dataFooter)
        return (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
    }

    private func updatedText(_ kind: CurrencyKind) -> String {
        guard let snapshot = store.snapshot, let set = snapshot.rateSet(for: kind) else { return L(.noData) }
        if snapshot.isDemo { return L(.demoShort) }
        // Коротко, без года: «27 окт., 04:02».
        return set.updatedAt.formatted(
            Date.FormatStyle(locale: store.language.locale).month(.abbreviated).day().hour().minute()
        )
    }
}

/// Настройки → «Иконка приложения».
private struct AppIconSettingsView: View {
    let onLocked: () -> Void
    @Environment(RatesStore.self) private var store

    var body: some View {
        Form {
            Section {
                AppIconPicker(isPro: store.isPro, onLocked: onLocked)
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 14, trailing: 0))
            }
        }
        .modifier(SettingsPage(title: L(.appIcon)))
    }
}

/// Выбор иконки приложения: сетка. Первые три — бесплатные, остальные — с тегом PRO:
/// без подписки нажатие открывает экран подписки.
struct AppIconPicker: View {
    let isPro: Bool
    var onLocked: () -> Void = {}

    /// nil — основная иконка.
    @State private var current: String? = UIApplication.shared.alternateIconName
    @Environment(\.colorScheme) private var colorScheme

    struct Option: Identifiable {
        let name: String?
        let preview: String
        let title: String
        let isPro: Bool
        var id: String { preview }
    }

    static var options: [Option] {
        [
            Option(name: nil, preview: "IconPreview-Chrome", title: L(.iconChrome), isPro: false),
            Option(name: "AppIcon-Amethyst", preview: "IconPreview-Amethyst", title: L(.iconAmethyst), isPro: false),
            Option(name: "AppIcon-Sticker", preview: "IconPreview-Sticker", title: L(.iconSticker), isPro: false),
            Option(name: "AppIcon-Puffy", preview: "IconPreview-Puffy", title: L(.iconPuffy), isPro: true),
            Option(name: "AppIcon-Sponge", preview: "IconPreview-Sponge", title: L(.iconSponge), isPro: true),
            Option(name: "AppIcon-Plush", preview: "IconPreview-Plush", title: L(.iconPlush), isPro: true),
            Option(name: "AppIcon-Gummy", preview: "IconPreview-Gummy", title: L(.iconGummy), isPro: true),
            Option(name: "AppIcon-Bubbles", preview: "IconPreview-Bubbles", title: L(.iconBubbles), isPro: true),
            Option(name: "AppIcon-Holo", preview: "IconPreview-Holo", title: L(.iconHolo), isPro: true),
            Option(name: "AppIcon-Knit", preview: "IconPreview-Knit", title: L(.iconKnit), isPro: true),
            Option(name: "AppIcon-Rubber", preview: "IconPreview-Rubber", title: L(.iconRubber), isPro: true),
            Option(name: "AppIcon-Stone", preview: "IconPreview-Stone", title: L(.iconStone), isPro: true),
            Option(name: "AppIcon-Blocks", preview: "IconPreview-Blocks", title: L(.iconBlocks), isPro: true),
            Option(name: "AppIcon-Doodle", preview: "IconPreview-Doodle", title: L(.iconDoodle), isPro: true),
            Option(name: "AppIcon-Pixel", preview: "IconPreview-Pixel", title: L(.iconPixel), isPro: true),
            Option(name: "AppIcon-Engraving", preview: "IconPreview-Engraving", title: L(.iconEngraving), isPro: true),
        ]
    }

    /// Иконки, доступные только с Pro (для сброса, когда подписка закончилась).
    static var proIconNames: Set<String> {
        Set(options.filter(\.isPro).compactMap(\.name))
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], spacing: 16) {
            ForEach(Self.options) { option in
                cell(option)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: current)
    }

    private func cell(_ option: Option) -> some View {
        let isSelected = option.name == current
        let isLocked = option.isPro && !isPro
        return Button {
            select(option, locked: isLocked)
        } label: {
            VStack(spacing: 8) {
                Image(option.preview)
                    .resizable()
                    .frame(width: 58, height: 58)
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    }
                    // Рамка выбранной — с заметным зазором от иконки.
                    .padding(5)
                    .overlay {
                        // Светлая тема — стеклянная рамка, как у кружка с галочкой и тега PRO:
                        // белый ободок, тонкая линия акцента внутри и мягкое свечение.
                        // В тёмной стекло выходит серым — там сплошная линия акцента.
                        Group {
                            if colorScheme == .dark {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Color.accentColor, lineWidth: 2.5)
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(
                                            LinearGradient(colors: [Color.glassRim, Color.glassRim.opacity(0.7)], startPoint: .top, endPoint: .bottom),
                                            lineWidth: 3
                                        )
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(Color.amountHighlight.opacity(0.7), lineWidth: 1.5)
                                }
                                .shadow(color: Color.amountHighlight.opacity(0.35), radius: 6)
                            }
                        }
                        .opacity(isSelected ? 1 : 0)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        // Светлая — стеклянный кружок, как в списке валют; тёмная — системная галочка.
                        Group {
                            if colorScheme == .dark {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(Color.onAccent, Color.accentButton)
                                    .background(Circle().fill(Color(.secondarySystemGroupedBackground)).padding(1))
                                    .offset(x: 4, y: 4)
                            } else {
                                SelectionBubble(isSelected: true, size: 24)
                                    .offset(x: 5, y: 5)
                            }
                        }
                            .scaleEffect(isSelected ? 1 : 0.3)
                            .opacity(isSelected ? 1 : 0)
                    }
                    .overlay(alignment: .topTrailing) {
                        if option.isPro && !isSelected {
                            ProBadge().scaleEffect(0.85).offset(x: 6, y: -6)
                        }
                    }
                Text(option.title)
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondaryLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 70)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityHint(isLocked ? L(.proOnly) : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func select(_ option: Option, locked: Bool) {
        if locked {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onLocked()
            return
        }
        guard option.name != current, UIApplication.shared.supportsAlternateIcons else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        let previous = current
        current = option.name
        UIApplication.shared.setAlternateIconName(option.name) { error in
            if error != nil {
                Task { @MainActor in current = previous }
            }
        }
    }
}
