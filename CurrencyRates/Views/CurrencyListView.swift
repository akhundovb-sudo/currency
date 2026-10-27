import SwiftUI
import UIKit

struct CurrencyListView: View {
    @Environment(RatesStore.self) private var store
    @State private var isAddPresented = false
    @State private var isSettingsPresented = false
    @State private var editMode: EditMode = .inactive
    @State private var isKeypadVisible = false
    @State private var isRefreshing = false
    @State private var toast: String?
    @State private var toastTask: Task<Void, Never>?
    /// Счётчик «тряски» карточки ввода при переполнении суммы.
    /// Какая карточка трясётся и фаза тряски (0…1). Вне тряски фаза всегда 0 — поэтому
    /// смена выбранной валюты не «проигрывает» тряску.
    @State private var shakingCode: String?
    @State private var shakePhase: CGFloat = 0
    /// Размеры строк для определения, куда пришлось нажатие. Обычный класс, а не состояние:
    /// запись при прокрутке не должна перерисовывать весь список.
    @State private var rowSizes = RowSizeStore()

    /// Отступы вокруг карточки внутри строки списка.
    private static let rowPadding = CGSize(width: 16, height: 6)

    var body: some View {
        NavigationStack {
            // Смена языка перестраивает список с новыми строками; открытые окна при этом не закрываются.
            list.id(store.language)
            // Заголовок не показывается, но остаётся для VoiceOver и переключателя приложений.
            .navigationTitle(L(.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            // Вместо панели с резкой нижней границей — плавное затухание сверху.
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $isAddPresented) {
                AddCurrencyView()
            }
            .sheet(isPresented: $isSettingsPresented) {
                SettingsView()
            }
        }
    }

    // MARK: - Список

    private var list: some View {
        ScrollViewReader { proxy in
            List {
                Section {
                    ForEach(store.selectedCodes, id: \.self) { code in
                        HStack(spacing: 12) {
                        if editMode.isEditing {
                            deleteButton(for: code)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                        CurrencyRow(
                            code: code,
                            sourceCode: store.sourceCode,
                            value: displayValue(for: code),
                            isPlaceholder: code == store.sourceCode && store.amountText.isEmpty,
                            unitRate: store.unitRate(to: code),
                            showsCursor: isKeypadVisible,
                            idleSourceCaption: idleSourceCaption
                        )
                        .card(selected: code == store.sourceCode && isKeypadVisible)
                        .modifier(ShakeEffect(shakes: shakingCode == code ? shakePhase : 0))
                        }
                        .swipeToDelete(isEnabled: !editMode.isEditing, canDelete: store.canDelete(code), onBlocked: { showBlockedToast(for: code) }, label: L(.delete)) {
                            store.remove(code)
                        }
                        // Отступы вокруг карточки — часть строки: нажатие в них закрывает клавиатуру.
                        .padding(.vertical, Self.rowPadding.height)
                        .padding(.horizontal, Self.rowPadding.width)
                        .background {
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear { rowSizes.sizes[code] = geo.size }
                                    .onChange(of: geo.size) { _, size in rowSizes.sizes[code] = size }
                            }
                        }
                        .contentShape(Rectangle())
                        // При перетаскивании поднимается только карточка, без отступов вокруг.
                        .contentShape(
                            .dragPreview,
                            CardInsetShape(inset: Self.rowPadding, cornerRadius: 20)
                        )
                        // В списке вся строка ловит нажатие, поэтому смотрим, куда оно пришлось:
                        // в карточку — выбор валюты, в отступ вокруг — закрыть клавиатуру.
                        // Точка нажатия на экране — по ней видно, где сейчас карточка
                        // (положение строк List при прокрутке не отслеживается надёжно).
                        .simultaneousGesture(
                            SpatialTapGesture(coordinateSpace: .global).onEnded { rowSizes.lastTap = $0.location }
                        )
                        .onTapGesture(coordinateSpace: .local) { location in
                            if isInsideCard(location, rowSize: rowSizes.sizes[code]) {
                                // После обоих жестов: точка нажатия на экране уже записана.
                                DispatchQueue.main.async {
                                    startEditing(code, proxy: proxy, tapInRow: location)
                                }
                            } else {
                                hideKeypad()
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .moveDisabled(store.isPinned(code))
                    }
                    .onMove { store.move(fromOffsets: $0, toOffset: $1) }
                }

                // Пустое место под списком тоже закрывает клавиатуру.
                if isKeypadVisible {
                    Color.clear
                        .frame(height: 360)
                        .contentShape(Rectangle())
                        .onTapGesture { hideKeypad() }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                }

                statusSection
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .environment(\.editMode, $editMode)
            .refreshable {
                withAnimation(.snappy) { isRefreshing = true }
                let started = Date.now
                await store.refresh()
                // Монеты успевают сделать хотя бы пару оборотов.
                let elapsed = Date.now.timeIntervalSince(started)
                if elapsed < 1.2 { try? await Task.sleep(for: .seconds(1.2 - elapsed)) }
                withAnimation(.snappy) { isRefreshing = false }
            }
            // В iOS 26 — системный мягкий край под панелью вместо резкой линии.
            .modifier(SoftTopEdge())
            // Под тостом и монетами, чтобы не приглушать их.
            .overlay(alignment: .top) { TopFade() }
            .overlay(alignment: .top) {
                if let toast {
                    ToastView(text: toast)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture { withAnimation { self.toast = nil } }
                }
            }
            // Вместо системного индикатора — крутящиеся монеты.
            .overlay(alignment: .top) {
                if isRefreshing {
                    SpinningCoins()
                        .padding(.top, 8)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .onAppear { UIRefreshControl.appearance().tintColor = .clear }
            .background {
                EmptySpaceTapCatcher { if isKeypadVisible { hideKeypad() } }
            }
            // Прокрутка списка прячет клавиатуру, как у системной клавиатуры.
            // Жест включён только при открытой клавиатуре: иначе он перехватывает
            // потягивание вниз, и «потяните, чтобы обновить» срабатывает через раз.
            .simultaneousGesture(
                DragGesture(minimumDistance: 12).onChanged { value in
                    if isKeypadVisible, abs(value.translation.height) > 24 { hideKeypad() }
                },
                including: isKeypadVisible ? .all : .subviews
            )
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isKeypadVisible {
                    AmountKeypad(
                        onKey: { key in
                            let accepted = withAnimation(.snappy(duration: 0.2)) { store.press(key) }
                            if !accepted {
                                // Не помещается: тряска карточки и вибрация ошибки.
                                UINotificationFeedbackGenerator().notificationOccurred(.error)
                                shake(store.sourceCode)
                            }
                        },
                        onClear: { withAnimation { store.amountText = "" } },
                        onDone: hideKeypad
                    )
                    .background {
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { rowSizes.keypadTop = geo.frame(in: .global).minY }
                                .onChange(of: geo.frame(in: .global).minY) { _, top in rowSizes.keypadTop = top }
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { rowSizes.listBottom = geo.frame(in: .global).maxY }
                        .onChange(of: geo.frame(in: .global).maxY) { _, bottom in rowSizes.listBottom = bottom }
                }
            }
        }
    }

    /// Кнопка удаления в режиме правки (в стиле блока свайпа): удаляет сразу, без подтверждения.
    /// Минимум две валюты — последние две удалить нельзя.
    private func deleteButton(for code: String) -> some View {
        Button {
            guard store.canDelete(code) else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                showBlockedToast(for: code)
                return
            }
            withAnimation(.snappy) { store.remove(code) }
        } label: {
            AppIcon("icon-minus", size: 18)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background { DeleteBlock(cornerRadius: 18, isDisabled: !store.canDelete(code)) } // круг: половина стороны 36
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(L(.delete)) \(code)")
    }

    /// Курс исходной валюты к первой другой валюте списка — подпись, пока клавиатура скрыта.
    private var idleSourceCaption: String? {
        guard let other = store.selectedCodes.first(where: { $0 != store.sourceCode }),
              let rate = store.unitRate(to: other) else { return nil }
        return "1 \(store.sourceCode) = \(RateFormat.rate(rate)) \(other)"
    }

    /// Строка ввода показывает выражение; остальные — пересчитанную сумму.
    private func displayValue(for code: String) -> String {
        if code == store.sourceCode {
            return store.amountText.isEmpty ? "1" : store.amountText
        }
        return store.convertedAmount(to: code).map(RateFormat.amount) ?? "—"
    }

    private func isInsideCard(_ point: CGPoint, rowSize: CGSize?) -> Bool {
        guard let size = rowSize else { return true }
        let card = CGRect(origin: .zero, size: size)
            .insetBy(dx: Self.rowPadding.width, dy: Self.rowPadding.height)
        return card.contains(point)
    }

    /// Всплывающее сообщение: последние две валюты удалить нельзя. Скрывается через 2,5 с.
    /// Почему валюту нельзя удалить: без подписки USD и EUR закреплены, иначе — минимум две валюты.
    private func showBlockedToast(for code: String) {
        toastTask?.cancel()
        let text = store.isPinned(code) ? L(.pinnedFree) : L(.minTwoCurrencies)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { toast = text }
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.25)) { toast = nil }
        }
    }

    private func shake(_ code: String) {
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) { shakingCode = code; shakePhase = 0 }
        withAnimation(.linear(duration: 0.3)) { shakePhase = 1 }
        Task {
            try? await Task.sleep(for: .seconds(0.32))
            withTransaction(reset) { shakePhase = 0; shakingCode = nil }
        }
    }

    private func startEditing(_ code: String, proxy: ScrollViewProxy, tapInRow: CGPoint) {
        guard !editMode.isEditing else { return }
        if code != store.sourceCode || !isKeypadVisible {
            UISelectionFeedbackGenerator().selectionChanged()
        }
        store.beginEditing(code)
        let wasVisible = isKeypadVisible
        withAnimation(.snappy) { isKeypadVisible = true }
        // Список прокручивается, только если карточка окажется под клавиатурой;
        // видимая карточка остаётся на месте.
        let keypadTop = wasVisible
            ? rowSizes.keypadTop ?? rowSizes.listBottom - Self.estimatedKeypadHeight
            : rowSizes.listBottom - (rowSizes.keypadHeight ?? Self.estimatedKeypadHeight)
        if let tap = rowSizes.lastTap, let rowHeight = rowSizes.sizes[code]?.height {
            // Низ карточки на экране: точка нажатия минус её смещение внутри строки, плюс высота строки.
            let cardBottom = tap.y - tapInRow.y + rowHeight - Self.rowPadding.height
            guard cardBottom > keypadTop - 8 else { return }
        }
        Task {
            // Ждём, пока клавиатура займёт место внизу, иначе прокрутка не учтёт её.
            if !wasVisible { try? await Task.sleep(for: .milliseconds(250)) }
            withAnimation(.snappy) { proxy.scrollTo(code, anchor: .bottom) }
        }
    }

    /// Высота клавиатуры до первого показа, пока её не измерили.
    private static let estimatedKeypadHeight: CGFloat = 380

    private func hideKeypad() {
        withAnimation(.snappy) { isKeypadVisible = false }
    }

    // MARK: - Статус загрузки

    @ViewBuilder
    private var statusSection: some View {
        Section {
            if let error = store.errorMessage {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L(.updateFailed))
                            .font(.headline)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                .accessibilityElement(children: .combine)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
                .cardListRow()

                Button(L(.retry), systemImage: "arrow.clockwise") {
                    Task { await store.refresh() }
                }
                .modifier(GlassButtonStyle())
                .disabled(store.isLoading)
                .cardListRow()
            } else if store.snapshot == nil, store.isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                    Text(L(.loading))
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
                .cardListRow()
            }

            // Источники и время обновления — в настройках; здесь только когда курсы не свежие.
            if isShowingStaleData {
                SourceFooter()
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .cardListRow()
            }
        }
    }

    private var isShowingStaleData: Bool {
        store.snapshot?.isDemo == true
            || store.isShowingCachedData(.fiat)
            || store.isShowingCachedData(.crypto)
    }

    // MARK: - Панель инструментов

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                isSettingsPresented = true
            } label: {
                AppIcon("icon-settings")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(CardBubbleStyle())
            .accessibilityLabel(L(.settings))
        }
        .hidingSharedGlass()

        ToolbarItem(placement: .principal) {
            Text(verbatim: "")
                .accessibilityHidden(true)
        }

        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 10) {
                Button {
                    hideKeypad()
                    withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                } label: {
                    Text(editMode.isEditing ? L(.done) : L(.edit))
                        .fontWeight(.semibold)
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                }
                .buttonStyle(CardBubbleStyle())

                Button {
                    isAddPresented = true
                } label: {
                    AppIcon("icon-plus")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(CardBubbleStyle())
                .accessibilityLabel(L(.addCurrency))
            }
        }
        .hidingSharedGlass()
    }
}

/// Источники курсов, время обновления и пометка о сохранённых данных.
struct SourceFooter: View {
    @Environment(RatesStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let snapshot = store.snapshot, snapshot.isDemo {
                Label(L(.demoData), systemImage: "eye")
            } else if let snapshot = store.snapshot {
                if let fiat = snapshot.fiat {
                    sourceLine(
                        title: LocalizedStringKey("\(L(.fiatShort)): [ExchangeRate-API](https://www.exchangerate-api.com)"),
                        set: fiat,
                        isCached: store.isShowingCachedData(.fiat)
                    )
                }
                if let crypto = snapshot.crypto {
                    sourceLine(
                        title: LocalizedStringKey("\(L(.cryptoShort)): [CoinGecko](https://www.coingecko.com)"),
                        set: crypto,
                        isCached: store.isShowingCachedData(.crypto)
                    )
                }
            } else if !store.isLoading {
                Text(L(.notLoaded))
            }
        }
    }

    private func sourceLine(title: LocalizedStringKey, set: RateSet, isCached: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(L(.updatedAt, RateFormat.date(set.updatedAt)))
            if isCached {
                Label(
                    L(.cachedAt, RateFormat.date(set.fetchedAt)),
                    systemImage: "clock.arrow.circlepath"
                )
            }
        }
    }
}

#Preview("Список") {
    CurrencyListView()
        .environment(RatesStore.preview())
}

/// Хранилище размеров строк без наблюдения SwiftUI.
final class RowSizeStore {
    var sizes: [String: CGSize] = [:]
    /// Последняя точка нажатия на строку, в координатах экрана.
    var lastTap: CGPoint?
    /// Верх клавиатуры на экране, пока она показана.
    var keypadTop: CGFloat? {
        didSet { if let keypadTop { keypadHeight = listBottom - keypadTop } }
    }
    /// Высота клавиатуры, измеренная при прошлом показе.
    var keypadHeight: CGFloat?
    /// Низ списка на экране.
    var listBottom: CGFloat = 0
}

/// Скруглённый прямоугольник карточки внутри строки с отступами.
struct CardInsetShape: Shape {
    let inset: CGSize
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(
            roundedRect: rect.insetBy(dx: inset.width, dy: inset.height),
            cornerRadius: cornerRadius,
            style: .continuous
        )
    }
}

/// Лёгкая горизонтальная тряска: каждое увеличение `shakes` на 1 — два небольших колебания.
struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 3 * sin(shakes * .pi * 4), y: 0))
    }
}

/// Индикатор обновления: две стеклянные монеты с $ и ₿ кружат друг вокруг друга
/// и, встречаясь, перетекают одна в другую, как капли жидкости.
struct SpinningCoins: View {
    private let orbit: CGFloat = 16
    private let coinRadius: CGFloat = 15
    private let period: Double = 1.4

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let angle = (t.truncatingRemainder(dividingBy: period) / period) * 2 * .pi
            let coins = [coin(angle: angle, glyph: "$"), coin(angle: angle + .pi, glyph: "₿")]
            ZStack {
                LiquidGlass(blobs: coins.map { ($0.offset, $0.radius) })
                ForEach(coins.indices, id: \.self) { index in
                    let item = coins[index]
                    Text(verbatim: item.glyph)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                        .scaleEffect(item.scale)
                        .opacity(0.45 + 0.55 * item.depth)
                        .offset(x: item.offset)
                        .zIndex(item.depth)
                }
            }
            .frame(width: (orbit + coinRadius) * 2 + 8, height: coinRadius * 2 + 10)
        }
        .accessibilityElement()
        .accessibilityLabel(L(.loading))
    }

    private struct Coin {
        let glyph: String
        let offset: CGFloat
        let radius: CGFloat
        let scale: CGFloat
        let depth: Double
    }

    private func coin(angle: Double, glyph: String) -> Coin {
        let depth = (cos(angle) + 1) / 2   // 1 — спереди, 0 — сзади
        let scale = 0.8 + 0.2 * depth
        return Coin(
            glyph: glyph,
            offset: orbit * sin(angle),
            radius: coinRadius * scale,
            scale: scale,
            depth: depth
        )
    }
}

/// Стеклянные капли, сливающиеся при сближении: круги размываются и обрезаются по порогу
/// прозрачности (метаболы). Заливка — лёгкое матовое стекло с оттенком акцента, блик и белый ободок.
private struct LiquidGlass: View {
    /// Смещение центра по горизонтали и радиус каждой капли.
    let blobs: [(CGFloat, CGFloat)]

    var body: some View {
        ZStack {
            // Тело стекла.
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.28), Color.accentColor.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                // Блик сверху.
                LinearGradient(
                    colors: [.white.opacity(0.55), .white.opacity(0)],
                    startPoint: .top,
                    endPoint: .center
                )
            }
            .mask { shape(threshold: 0.5) }

            // Ободок: капля без чуть уменьшенной копии самой себя.
            LinearGradient(
                colors: [.white.opacity(0.95), Color.accentColor.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
            .mask {
                ZStack {
                    shape(threshold: 0.5)
                    shape(threshold: 0.78).blendMode(.destinationOut)
                }
                .compositingGroup()
            }
        }
        .allowsHitTesting(false)
    }

    /// Слитый силуэт капель; чем выше порог, тем он тоньше.
    private func shape(threshold: Double) -> some View {
        Canvas { context, size in
            context.addFilter(.alphaThreshold(min: threshold, color: .white))
            context.addFilter(.blur(radius: 5))
            context.drawLayer { layer in
                for (offset, radius) in blobs {
                    let rect = CGRect(
                        x: size.width / 2 + offset - radius,
                        y: size.height / 2 - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    layer.fill(Path(ellipseIn: rect), with: .color(.white))
                }
            }
        }
    }
}

/// Всплывающее сообщение в стиле кнопок приложения.
struct ToastView: View {
    let text: String

    var body: some View {
        Label {
            Text(text)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.leading)
        } icon: {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Color(.systemGray))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background { CardBubbleBackground() }
        .padding(.horizontal, 24)
        .accessibilityAddTraits(.isStaticText)
    }
}
