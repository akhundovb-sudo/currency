import SwiftUI

/// Настройки → «Live Activity»: показывать ли курс на экране блокировки и какую пару.
/// «Местная» — курс валюты страны, где вы сейчас (только в поездке); выбранная валюта — всегда.
struct LiveActivitySettingsView: View {
    @Environment(RatesStore.self) private var store

    /// Валюты для выбора — только из списка приложения, в том же порядке.
    private var options: [String] { store.selectedCodes }

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                Toggle(L(.liveShow), isOn: $store.showsTravelActivity)
            }

            Section {
                Picker(L(.liveFrom), selection: $store.travelActivitySource) {
                    Text(L(.liveAuto)).tag(String?.none)
                    ForEach(options, id: \.self) { code in
                        Text(verbatim: "\(code) · \(Currency(code: code).name)").tag(String?.some(code))
                    }
                }
                Picker(L(.liveTo), selection: $store.travelActivityTarget) {
                    Text(L(.liveMain)).tag(String?.none)
                    ForEach(options, id: \.self) { code in
                        Text(verbatim: "\(code) · \(Currency(code: code).name)").tag(String?.some(code))
                    }
                }
            } footer: {
                Text(L(.liveFooter))
            }
            .disabled(!store.showsTravelActivity)
        }
        // Любое изменение сразу применяется к Live Activity: показать, сменить пару или убрать.
        .onChange(of: store.showsTravelActivity) { _, _ in TravelActivityController.update(store) }
        .onChange(of: store.travelActivitySource) { _, _ in TravelActivityController.update(store) }
        .onChange(of: store.travelActivityTarget) { _, _ in TravelActivityController.update(store) }
        // Валюту убрали из списка — выбор возвращается к «Местной» / «Первой в списке».
        .onAppear {
            if let code = store.travelActivitySource, !options.contains(code) { store.travelActivitySource = nil }
            if let code = store.travelActivityTarget, !options.contains(code) { store.travelActivityTarget = nil }
        }
        .modifier(SettingsPage(title: L(.liveActivity)))
    }
}
