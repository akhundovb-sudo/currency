import SwiftUI
import UIKit

struct AddCurrencyView: View {
    @Environment(RatesStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var kind: CurrencyKind = .fiat
    @State private var query = ""
    /// Валюты, выбранные на момент открытия окна, — они идут первыми.
    /// Порядок фиксируется при открытии, чтобы строки не прыгали при отметке.
    @State private var pinned: [String] = []

    private var currencies: [Currency] {
        switch kind {
        case .fiat:
            let codes = store.snapshot?.fiat.map { Array($0.rates.keys) } ?? Locale.commonISOCurrencyCodes
            return codes
                .filter { CryptoAsset.byCode[$0] == nil }
                .sorted()
                .map(Currency.init(code:))
        case .crypto:
            // Порядок примерно по капитализации.
            return CryptoAsset.all.map { Currency(code: $0.code) }
        }
    }

    private var results: [Currency] {
        let all = currencies.filter { $0.matches(query) }
        let top = pinned.compactMap { code in all.first { $0.code == code } }
        return top + all.filter { !pinned.contains($0.code) }
    }

    /// В iOS 26 поле поиска стоит внизу экрана, как в системных приложениях;
    /// в более ранних версиях такого размещения нет, и поиск остаётся под заголовком.
    private var searchPlacement: SearchFieldPlacement {
        if #available(iOS 26, *) {
            .toolbar
        } else {
            .navigationBarDrawer(displayMode: .always)
        }
    }

    var body: some View {
        NavigationStack {
            listView
        }
        .onAppear { pinned = store.selectedCodes }
    }

    private var listView: some View {
        Group {
            List(results) { currency in
                let isAdded = store.contains(currency.code)
                // Окно не закрывается: можно отметить несколько валют подряд.
                // Повторное нажатие убирает валюту (минимум две остаются).
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.snappy) {
                        if isAdded { store.remove(currency.code) } else { store.add(currency.code) }
                    }
                } label: {
                    CurrencySelectRow(currency: currency, isSelected: isAdded)
                }
                .buttonStyle(.plain)
                .disabled(isAdded && !store.canRemove)
                .accessibilityHint(isAdded ? L(.alreadyAdded) : L(.addToList))
            }
            .overlay {
                if results.isEmpty {
                    ContentUnavailableView(
                        L(.nothingFound),
                        systemImage: "magnifyingglass",
                        description: Text(L(.noResults, query))
                    )
                }
            }
            .searchable(
                text: $query,
                placement: searchPlacement,
                prompt: L(.searchPrompt)
            )
            // Во время поиска «Закрыть» и «Фиат / Крипта» остаются на месте.
            .modifier(KeepToolbarWhileSearching())
            // Над списком — небольшой отступ.
            .contentMargins(.top, 8, for: .scrollContent)
            .environment(\.defaultMinListHeaderHeight, 0)
            .listSectionSpacing(0)
            .navigationTitle(L(.addCurrency))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    // Можно выбрать несколько валют — поэтому «Готово», а не «Закрыть».
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
                ToolbarItem(placement: .principal) {
                    KindSwitch(kind: $kind)
                }
                .hidingSharedGlass()
            }
        }
    }
}

/// Не прячет панель навигации во время поиска (доступно с iOS 17.1).
private struct KeepToolbarWhileSearching: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.1, *) {
            content.searchPresentationToolbarBehavior(.avoidHidingContent)
        } else {
            content
        }
    }
}

/// Переключатель «Фиат / Крипта» в стиле кнопок приложения:
/// капсула-карточка, выбранный сегмент — светлая плашка внутри.
private struct KindSwitch: View {
    @Binding var kind: CurrencyKind
    @Namespace private var selection

    var body: some View {
        HStack(spacing: 2) {
            ForEach(CurrencyKind.allCases) { option in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { kind = option }
                } label: {
                    Text(option.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(kind == option ? Color.primary : Color.secondary)
                        .frame(minWidth: 72)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background {
                            if kind == option {
                                Capsule()
                                    .fill(Color(.systemBackground))
                                    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
                                    .matchedGeometryEffect(id: "segment", in: selection)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(kind == option ? .isSelected : [])
            }
        }
        .padding(4)
        .background { CardBubbleBackground() }
        .accessibilityLabel(L(.currencyType))
    }
}

#Preview {
    AddCurrencyView()
        .environment(RatesStore.preview())
}
