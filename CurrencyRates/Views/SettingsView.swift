import SwiftUI

struct SettingsView: View {
    @Environment(RatesStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = store

        NavigationStack {
            Form {
                if !store.isPro {
                    Section {
                        // Покупки пока не подключены — экран подписки появится позже.
                        ProBanner()
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }

                Section(L(.appearance)) {
                    Picker(L(.language), selection: $store.language) {
                        ForEach(AppLanguage.allCases) { language in
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
                            Text(verbatim: "\(style.title) · \(1234.56.formatted(.number.locale(style.locale)))")
                                .tag(style)
                        }
                    }
                    HStack {
                        Text(L(.decimalPlaces))
                        Spacer()
                        Text(store.decimalPlaces.map(String.init) ?? L(.auto))
                            .foregroundStyle(Color.secondaryLabel)
                            .monospacedDigit()
                        // −1 — «Авто», дальше 0…8 знаков.
                        Stepper(
                            L(.decimalPlaces),
                            value: Binding(
                                get: { store.decimalPlaces ?? -1 },
                                set: { store.decimalPlaces = $0 >= 0 ? $0 : nil }
                            ),
                            in: -1...8
                        )
                        .labelsHidden()
                    }
                } header: {
                    Text(L(.numbers))
                } footer: {
                    // Живой пример: так будут выглядеть суммы в конвертере.
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L(.formatFooter))
                        ForEach(["USD", "SEK", "JOD"], id: \.self) { code in
                            Text(verbatim: "• \(Currency.name(for: code)): \(RateFormat.amount(32.16))")
                        }
                    }
                    // Пример пересчитывается при смене настроек.
                    .id("\(store.numberStyle.rawValue)-\(store.decimalPlaces ?? -1)")
                }

                Section {
                    LabeledContent(L(.source)) {
                        Link(RatesService.fiatSourceName, destination: RatesService.fiatSourceURL)
                    }
                    LabeledContent(L(.updated), value: updatedText(.fiat))
                } header: {
                    Text(L(.fiatCurrencies))
                } footer: {
                    Text(L(.fiatFooter))
                }

                Section {
                    LabeledContent(L(.source)) {
                        Link(RatesService.cryptoSourceName, destination: RatesService.cryptoSourceURL)
                    }
                    LabeledContent(L(.updated), value: updatedText(.crypto))
                } header: {
                    Text(L(.cryptoCurrencies))
                } footer: {
                    Text(L(.cryptoFooter))
                }

                Section {
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
                } footer: {
                    Text(L(.offlineFooter))
                }

                // Временно, пока не подключены покупки: включает и выключает Pro для проверки.
                Section {
                    Toggle(L(.proTest), isOn: $store.isPro)
                }

                Section {
                    LabeledContent(L(.version), value: appVersion)
                } footer: {
                    Text(verbatim: "Icons: Iconoir (MIT) · Flags: flag-icons (MIT) · Crypto: web3icons (MIT)")
                }
            }
            .softTopBar()
            .navigationTitle(L(.settings))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Text(L(.done))
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                    }
                    .buttonStyle(AccentBubbleStyle())
                }
                .hidingSharedGlass()
            }
        }
    }

    private func updatedText(_ kind: CurrencyKind) -> String {
        guard let snapshot = store.snapshot, let set = snapshot.rateSet(for: kind) else { return L(.noData) }
        if snapshot.isDemo { return L(.demoShort) }
        return RateFormat.date(set.updatedAt)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}

#Preview {
    SettingsView()
        .environment(RatesStore.preview())
}
