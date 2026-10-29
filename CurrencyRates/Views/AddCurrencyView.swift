import SwiftUI
import UIKit

struct AddCurrencyView: View {
    @Environment(RatesStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var kind: CurrencyKind = .fiat
    @State private var query = ""

    private var currencies: [Currency] {
        switch kind {
        case .fiat:
            return store.fiatCodes.map(Currency.init(code:))
        case .crypto:
            // Порядок примерно по капитализации.
            return CryptoAsset.all.map { Currency(code: $0.code) }
        }
    }

    /// Валюты, выбранные на момент открытия окна, — они идут первыми. Порядок фиксируется
    /// при открытии: отмеченная сейчас валюта остаётся на месте и поднимется наверх при следующем открытии.
    private let pinned: [String]

    init(pinned: [String] = []) {
        self.pinned = pinned
    }

    private var results: [Currency] {
        let all = currencies.filter { $0.matches(query) }
        let top = pinned.compactMap { code in all.first { $0.code == code } }
        return top + all.filter { !pinned.contains($0.code) }
    }

    @State private var isPaywallPresented = false

    /// Нажатие на валюту с тегом «PRO» открывает экран подписки.
    private func showPro() { isPaywallPresented = true }

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
        // Модальные окна не наследуют направление письма — для арабского задаём сами.
        .environment(\.layoutDirection, store.language.isRightToLeft ? .rightToLeft : .leftToRight)
        .fullScreenCover(isPresented: $isPaywallPresented) { PaywallView() }
    }

    private var listView: some View {
        Group {
            List(results) { currency in
                let isAdded = store.contains(currency.code)
                // Крипта и фиат сверх бесплатного лимита — только с Pro.
                let isLocked = !isAdded && !store.canAdd(currency.code)
                // Окно не закрывается: можно отметить несколько валют подряд.
                // Повторное нажатие убирает валюту (минимум две остаются).
                // Строка с тегом «PRO» не тускнеет и нажимается — дальше по ней откроется покупка.
                Button {
                    if isLocked {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showPro()
                        return
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.snappy) {
                        if isAdded { store.remove(currency.code) } else { store.add(currency.code) }
                    }
                } label: {
                    CurrencySelectRow(currency: currency, isSelected: isAdded, isLocked: isLocked)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .disabled(isAdded && !store.canDelete(currency.code))
                .accessibilityHint(isLocked ? L(.proOnly) : isAdded ? L(.alreadyAdded) : L(.addToList))
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
            .softTopBar()
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
                                // Выбранный тип — светлая капсула на сером фоне; в тёмной теме —
                                // заметно светлее подложки, с бликом по верхнему краю.
                                Capsule()
                                    .fill(Color.segmentSelected)
                                    .overlay(
                                        Capsule().strokeBorder(
                                            LinearGradient(colors: [Color.segmentRim, .clear], startPoint: .top, endPoint: .center),
                                            lineWidth: 1
                                        )
                                    )
                                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
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
        // Серая подложка — на ней белый выбранный сегмент хорошо виден.
        .background(Capsule().fill(Color.segmentTrack))
        .accessibilityLabel(L(.currencyType))
    }
}

#Preview {
    AddCurrencyView()
        .environment(RatesStore.preview())
}

extension Color {
    static let segmentTrack = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.07) : UIColor(white: 0, alpha: 0.08)
    })
    static let segmentSelected = Color.dynamic(light: 0xFFFFFF, dark: 0x48484C)
    static let segmentRim = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.18) : .clear
    })
}
