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

                Section {
                    LabeledContent(L(.version), value: appVersion)
                } footer: {
                    Text(verbatim: "Icons: Iconoir (MIT) · Flags: flag-icons (MIT) · Crypto: web3icons (MIT)")
                }
            }
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
