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

                Section(L(.appearance)) {
                    Picker(L(.language), selection: $store.language) {
                        // Английский первым, дальше в обычном порядке.
                        ForEach([AppLanguage.en] + AppLanguage.allCases.filter { $0 != .en }) { language in
                            Text(verbatim: language.nativeName).tag(language)
                        }
                    }
                    Picker(L(.theme), selection: $store.theme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }
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
                    // Живой пример — так суммы выглядят в конвертере.
                    LabeledContent(L(.example)) {
                        Text(verbatim: "\(RateFormat.amount(1234.56)) $")
                            .font(.amount)
                            .monospacedDigit()
                            .foregroundStyle(Color.primary)
                            .contentTransition(.numericText())
                    }
                    .animation(.snappy, value: store.numberStyle)
                    .animation(.snappy, value: store.decimalPlaces)
                } header: {
                    Text(L(.numbers))
                }

                Section {
                    sourceRow(name: RatesService.fiatSourceName, url: RatesService.fiatSourceURL, kind: .fiat)
                    sourceRow(name: RatesService.cryptoSourceName, url: RatesService.cryptoSourceURL, kind: .crypto)
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        HStack {
                            Text(L(.refreshRates))
                            Spacer()
                            if store.isLoading { ProgressView() }
                        }
                    }
                    .disabled(store.isLoading)
                } header: {
                    Text(L(.rates))
                } footer: {
                    Text(L(.dataFooter))
                }

                Section(L(.appIcon)) {
                    AppIconPicker(isPro: store.isPro, onLocked: { isPaywallPresented = true })
                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 14, trailing: 0))
                }

                Section(L(.support)) {
                    Button { requestReview() } label: {
                        linkRow(L(.rateApp), symbol: "star")
                    }
                    // Условия и конфиденциальность — одна строка, ведёт на страницу с документами.
                    Link(destination: AppLinks.legal) {
                        linkRow(L(.termsPrivacy), symbol: "arrow.up.right")
                    }
                }

                Section {
                    // Временно, пока не подключены покупки: включает и выключает Pro для проверки.
                    Toggle(L(.proTest), isOn: $store.isPro)
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

    /// Строка-ссылка: подпись слева, значок справа.
    private func linkRow(_ title: String, symbol: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Color.primary)
            Spacer()
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.secondaryLabel)
        }
    }

    /// Источник курсов: слева тип, справа ссылка на источник и под ней мелко время обновления.
    private func sourceRow(name: String, url: URL, kind: CurrencyKind) -> some View {
        LabeledContent {
            VStack(alignment: .trailing, spacing: 2) {
                Link(name, destination: url)
                Text(updatedText(kind))
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryLabel)
            }
        } label: {
            Text(kind == .fiat ? L(.fiatCurrencies) : L(.cryptoCurrencies))
        }
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

#Preview {
    SettingsView()
        .environment(RatesStore.preview())
}

/// Выбор иконки приложения: одна строка, листается вбок. Первые три — бесплатные, остальные — с тегом PRO:
/// без подписки нажатие открывает экран подписки.
struct AppIconPicker: View {
    let isPro: Bool
    var onLocked: () -> Void = {}

    /// nil — основная иконка.
    @State private var current: String? = UIApplication.shared.alternateIconName

    struct Option: Identifiable {
        let name: String?
        let preview: String
        let title: String
        let isPro: Bool
        var id: String { preview }
    }

    static var options: [Option] {
        [
            Option(name: nil, preview: "IconPreview-Silver", title: L(.iconSilver), isPro: false),
            Option(name: "AppIcon-Amethyst", preview: "IconPreview-Amethyst", title: L(.iconAmethyst), isPro: false),
            Option(name: "AppIcon-Sticker", preview: "IconPreview-Sticker", title: L(.iconSticker), isPro: false),
            Option(name: "AppIcon-Puffy", preview: "IconPreview-Puffy", title: L(.iconPuffy), isPro: true),
            Option(name: "AppIcon-Sponge", preview: "IconPreview-Sponge", title: L(.iconSponge), isPro: true),
            Option(name: "AppIcon-Plush", preview: "IconPreview-Plush", title: L(.iconPlush), isPro: true),
            Option(name: "AppIcon-Gummy", preview: "IconPreview-Gummy", title: L(.iconGummy), isPro: true),
            Option(name: "AppIcon-Bubbles", preview: "IconPreview-Bubbles", title: L(.iconBubbles), isPro: true),
            Option(name: "AppIcon-Holo", preview: "IconPreview-Holo", title: L(.iconHolo), isPro: true),
        ]
    }

    /// Иконки, доступные только с Pro (для сброса, когда подписка закончилась).
    static var proIconNames: Set<String> {
        Set(options.filter(\.isPro).compactMap(\.name))
    }

    var body: some View {
        // Одна строка, листается вбок; выбранная иконка при открытии — в зоне видимости.
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                // Последняя видимая иконка обрезана краем — видно, что дальше листается.
                HStack(alignment: .top, spacing: 8) {
                    ForEach(Self.options) { option in
                        cell(option).id(option.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                if let selected = Self.options.first(where: { $0.name == current }) {
                    proxy.scrollTo(selected.id, anchor: .center)
                }
            }
        }
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
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.accentColor, lineWidth: 2.5)
                            .opacity(isSelected ? 1 : 0)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Color.onAccent, Color.accentButton)
                            .background(Circle().fill(Color(.secondarySystemGroupedBackground)).padding(1))
                            .offset(x: 4, y: 4)
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
