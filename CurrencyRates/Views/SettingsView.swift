import SwiftUI

struct SettingsView: View {
    @Environment(RatesStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var isPaywallPresented = false

    var body: some View {
        @Bindable var store = store

        NavigationStack {
            Form {
                if !store.isPro {
                    Section {
                        ProBanner(onDetails: { isPaywallPresented = true })
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
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

                Section {
                    // Временно, пока не подключены покупки: включает и выключает Pro для проверки.
                    Toggle(L(.proTest), isOn: $store.isPro)
                    LabeledContent(L(.version), value: appVersion)
                } header: {
                    Text(L(.about))
                } footer: {
                    Text(verbatim: "Iconoir · flag-icons · web3icons (MIT)")
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

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}

#Preview {
    SettingsView()
        .environment(RatesStore.preview())
}
