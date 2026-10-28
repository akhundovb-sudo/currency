import Observation
import SwiftUI
import UIKit

struct CurrencyListView: View {
    @Environment(RatesStore.self) private var store
    @State private var isAddPresented = false
    @State private var isSettingsPresented = false
    @State private var editMode: EditMode = .inactive
    @State private var isKeypadVisible = false
    @State private var isRefreshing = false
    @State private var toast: Toast?
    @State private var toastTask: Task<Void, Never>?
    /// Счётчик «тряски» карточки ввода при переполнении суммы.
    /// Какая карточка трясётся и фаза тряски (0…1). Вне тряски фаза всегда 0 — поэтому
    /// смена выбранной валюты не «проигрывает» тряску.
    @State private var shakingCode: String?
    @State private var shakePhase: CGFloat = 0
    /// Размеры строк для определения, куда пришлось нажатие. Обычный класс, а не состояние:
    /// запись при прокрутке не должна перерисовывать весь список.
    @State private var rowSizes = RowSizeStore()
    @State private var pullTracker = PullTracker()

    /// Отступы вокруг карточки внутри строки списка.
    private static let rowPadding = CGSize(width: 16, height: 6)

    var body: some View {
        NavigationStack {
            // Смена языка перестраивает список с новыми строками; открытые окна при этом не закрываются.
            // Смена формата чисел — тоже: суммы пересчитываются в новом виде.
            list.id("\(store.language.rawValue)-\(store.numberStyle.rawValue)-\(store.decimalPlaces ?? -1)")
            // Заголовок не показывается, но остаётся для VoiceOver и переключателя приложений.
            .navigationTitle(L(.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            // Вместо панели с резкой нижней границей — плавное затухание сверху.
            .modifier(HiddenBarBackground())
            .sheet(isPresented: $isAddPresented) {
                AddCurrencyView()
            }
            // Вместо системного индикатора — капли из Dynamic Island.
            .overlay { IslandRefreshIndicator(isActive: isRefreshing, pull: pullTracker.progress) }
            .sheet(isPresented: $isSettingsPresented) {
                SettingsView()
            }
        }
    }

    // MARK: - Список

    private var list: some View {
        Group {
            // Клавиатура лежит поверх списка, а список не меняет размер — только снизу
            // добавляется место для прокрутки. Так клавиатура и подъём списка движутся
            // одним плавным движением, без пересчёта высоты списка на ходу.
            ZStack(alignment: .bottom) {
            List {
                Section {
                    ForEach(store.selectedCodes, id: \.self) { code in
                        HStack(spacing: 12) {
                        if editMode.isEditing {
                            deleteButton(for: code)
                                .transition(.scale(scale: 0.4).combined(with: .opacity))
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
                        // Фокус: выбранная карточка приподнимается — чуть крупнее, с мягкой тенью.
                        .scaleEffect(isKeypadVisible && code == store.sourceCode ? 1.025 : 1)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isKeypadVisible)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.sourceCode)
                        .modifier(ShakeEffect(shakes: shakingCode == code ? shakePhase : 0))
                        }
                        .swipeToDelete(isEnabled: !editMode.isEditing, canDelete: store.canDelete(code), onBlocked: { showBlockedToast(for: code) }, label: L(.delete)) {
                            store.remove(code)
                        }
                        // Отступы вокруг карточки — часть строки: нажатие в них закрывает клавиатуру.
                        .padding(.vertical, Self.rowPadding.height)
                        .padding(.horizontal, Self.rowPadding.width)
                        // Невидимая метка строки — по ней список прокручивается средствами UIKit.
                        .background(RowAnchor(code: code, store: rowSizes))
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
                        .onTapGesture(coordinateSpace: .local) { location in
                            if isInsideCard(location, rowSize: rowSizes.sizes[code]) {
                                startEditing(code)
                            } else {
                                hideKeypad()
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                    }
                    .onMove { store.move(fromOffsets: $0, toOffset: $1) }
                }

                statusSection
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .environment(\.editMode, $editMode)
            // «Потяните, чтобы обновить» — своё: капли из Dynamic Island следуют за пальцем,
            // обновление начинается, когда список отпустили, потянув до конца.
            .onAppear {
                pullTracker.onRelease = { startPullRefresh() }
                // Строки должны успеть появиться — через них находим прокрутку списка.
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    if let scrollView = rowSizes.scrollView() { pullTracker.attach(scrollView) }
                }
            }
            // Системный край прокрутки выключен — размытие под панелью рисует TopFade.
            .modifier(SoftTopEdge())
            .overlay(alignment: .top) { TopFade() }
            // Сообщения — снизу, над клавиатурой; смахиваются вниз или закрываются крестиком.
            .overlay(alignment: .bottom) {
                if let toast {
                    ToastView(toast: toast, onClose: dismissToast)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .gesture(
                            DragGesture(minimumDistance: 8).onEnded { value in
                                if value.translation.height > 20 { dismissToast() }
                            }
                        )
                }
            }
            .background {
                EmptySpaceTapCatcher { if isKeypadVisible { hideKeypad() } }
            }
            // Подписка закончилась — валюты Pro отключены; объясняем, куда они делись.
            .onChange(of: store.suspendedCodes.count) { old, new in
                if new > old { showToast(Toast(kind: .info, message: L(.proSuspended))) }
            }
            // Смахивание списка вниз прячет клавиатуру. Прокрутка вверх её не трогает:
            // иначе клавиатура исчезала посреди жеста и список прыгал под пальцем.
            // Жест включён только при открытой клавиатуре: иначе он перехватывает
            // потягивание вниз, и «потяните, чтобы обновить» срабатывает через раз.
            .simultaneousGesture(
                DragGesture(minimumDistance: 12).onChanged { value in
                    if isKeypadVisible, value.translation.height > 40 { hideKeypad() }
                },
                including: isKeypadVisible ? .all : .subviews
            )
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
                        // Высота клавиатуры — чтобы в следующий раз заранее знать, где будет её верх.
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { rowSizes.updateKeypadHeight(geo.size.height) }
                                .onChange(of: geo.size.height) { _, height in rowSizes.updateKeypadHeight(height) }
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
            return store.amountText.isEmpty ? "1" : RateFormat.groupedInput(store.amountText)
        }
        return store.convertedAmount(to: code).map(RateFormat.amount) ?? "—"
    }

    private func isInsideCard(_ point: CGPoint, rowSize: CGSize?) -> Bool {
        guard let size = rowSize else { return true }
        let card = CGRect(origin: .zero, size: size)
            .insetBy(dx: Self.rowPadding.width, dy: Self.rowPadding.height)
        return card.contains(point)
    }

    /// Почему валюту нельзя удалить: в списке должно остаться минимум две валюты.
    private func showBlockedToast(for code: String) {
        showToast(Toast(kind: .warning, message: L(.minTwoCurrencies)))
    }

    /// Показывает сообщение снизу; оно само скрывается через 3 с.
    private func showToast(_ newToast: Toast) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { toast = newToast }
        toastTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            dismissToast()
        }
    }

    private func dismissToast() {
        toastTask?.cancel()
        withAnimation(.easeInOut(duration: 0.25)) { toast = nil }
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

    private func startEditing(_ code: String) {
        guard !editMode.isEditing else { return }
        if code != store.sourceCode || !isKeypadVisible {
            UISelectionFeedbackGenerator().selectionChanged()
        }
        store.beginEditing(code)
        let wasVisible = isKeypadVisible
        withAnimation(Self.keypadAnimation) { isKeypadVisible = true }
        // Список поднимается одним плавным движением одновременно с клавиатурой:
        // заранее считаем, где окажется её верх, и прокручиваем средствами UIKit
        // (ScrollViewProxy.scrollTo в List на iOS 27 этого не делал). Видимая карточка
        // остаётся на месте.
        if !wasVisible { rowSizes.showKeypadSpace() }
        rowSizes.liftAboveKeypad(code)
    }

    private func startPullRefresh() {
        guard !isRefreshing else { return }
        Task {
            withAnimation(.snappy) { isRefreshing = true }
            let started = Date.now
            await store.refresh()
            // Капли успевают сделать хотя бы пару оборотов.
            let elapsed = Date.now.timeIntervalSince(started)
            if elapsed < 1.2 { try? await Task.sleep(for: .seconds(1.2 - elapsed)) }
            withAnimation(.snappy) { isRefreshing = false }
        }
    }

    private func hideKeypad() {
        guard isKeypadVisible else { return }
        withAnimation(Self.keypadAnimation) { isKeypadVisible = false }
        rowSizes.hideKeypadSpace()
    }

    /// Одна и та же плавная кривая для клавиатуры и подъёма списка — движутся как одно целое.
    private static let keypadAnimation = Animation.smooth(duration: 0.4)

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
                    // Одна плавная анимация без отскока: кнопки «−», ручки перетаскивания и карточки.
                    withAnimation(.smooth(duration: 0.32)) {
                        editMode = editMode.isEditing ? .inactive : .active
                    }
                } label: {
                    // Ширина — по длинному из двух слов: кнопка не прыгает при смене «Править» / «Готово».
                    ZStack {
                        Text(L(.edit)).opacity(editMode.isEditing ? 0 : 1)
                        Text(L(.done)).opacity(editMode.isEditing ? 1 : 0)
                    }
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .fixedSize()
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
    /// UIView каждой строки (слабые ссылки) — для прокрутки средствами UIKit.
    private let anchors = NSMapTable<NSString, UIView>.strongToWeakObjects()

    func setAnchor(_ view: UIView, for code: String) {
        anchors.setObject(view, forKey: code as NSString)
    }

    /// Прокрутка списка — ближайший UIScrollView над любой из строк.
    @MainActor
    func scrollView() -> UIScrollView? {
        let views = anchors.objectEnumerator()?.allObjects as? [UIView] ?? []
        return views.lazy.compactMap { Self.enclosingScrollView(of: $0) }.first
    }

    private static func enclosingScrollView(of view: UIView) -> UIScrollView? {
        var parent = view.superview
        while let current = parent, !(current is UIScrollView) { parent = current.superview }
        return parent as? UIScrollView
    }

    /// Высота клавиатуры (без области под полоской «домой»); до первого показа — примерная.
    private(set) var keypadHeight: CGFloat = 330
    private var isKeypadSpaceShown = false

    /// Одна кривая для всех движений списка — та же длительность, что у клавиатуры.
    @MainActor
    private func animate(_ changes: @escaping () -> Void) {
        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: changes
        )
    }

    /// Место снизу списка под клавиатурой — чтобы нижние строки можно было поднять над ней.
    @MainActor
    func showKeypadSpace() {
        isKeypadSpaceShown = true
        scrollView()?.contentInset.bottom = keypadHeight
    }

    /// Убирает место под клавиатурой; если список был прокручен в это место — плавно возвращает.
    @MainActor
    func hideKeypadSpace() {
        isKeypadSpaceShown = false
        guard let scrollView = scrollView() else { return }
        animate {
            scrollView.contentInset.bottom = 0
            let inset = scrollView.adjustedContentInset
            let maxOffset = max(-inset.top, scrollView.contentSize.height + inset.bottom - scrollView.bounds.height)
            if scrollView.contentOffset.y > maxOffset { scrollView.contentOffset.y = maxOffset }
        }
    }

    @MainActor
    func updateKeypadHeight(_ height: CGFloat) {
        guard height > 0, abs(height - keypadHeight) > 0.5 else { return }
        keypadHeight = height
        if isKeypadSpaceShown { scrollView()?.contentInset.bottom = height }
    }

    /// Если клавиатура закроет строку, плавно поднимает список ровно настолько, чтобы строка
    /// оказалась над ней, — одновременно с выездом клавиатуры. Видимую строку не трогает.
    @MainActor
    func liftAboveKeypad(_ code: String) {
        guard let view = anchors.object(forKey: code as NSString), let window = view.window,
              let scrollView = Self.enclosingScrollView(of: view) else { return }
        let row = view.convert(view.bounds, to: nil)
        // Верх клавиатуры на экране (она лежит поверх списка у нижнего края).
        let keypadTop = window.bounds.height - window.safeAreaInsets.bottom - keypadHeight
        let delta = row.maxY - keypadTop
        guard delta > 0 else { return }
        let inset = scrollView.adjustedContentInset
        let maxOffset = max(-inset.top, scrollView.contentSize.height + inset.bottom - scrollView.bounds.height)
        let target = min(scrollView.contentOffset.y + delta, maxOffset)
        animate { scrollView.contentOffset.y = target }
    }
}

/// Следит, насколько список потянут вниз за верхний край, и сообщает, когда его отпустили.
@MainActor
@Observable
final class PullTracker {
    /// 0…1: насколько потянули относительно порога обновления.
    private(set) var progress: CGFloat = 0
    @ObservationIgnored var onRelease: @MainActor () -> Void = {}

    /// Сколько точек нужно потянуть, чтобы началось обновление.
    private let threshold: CGFloat = 96
    @ObservationIgnored private weak var scrollView: UIScrollView?
    @ObservationIgnored private var observation: NSKeyValueObservation?
    @ObservationIgnored private let panTarget = PanTarget()
    @ObservationIgnored private var didReachThreshold = false

    func attach(_ scrollView: UIScrollView) {
        guard scrollView !== self.scrollView else { return }
        self.scrollView = scrollView
        // Тянуть можно, даже если список короткий.
        scrollView.alwaysBounceVertical = true
        observation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scrollView, _ in
            MainActor.assumeIsolated { self?.update(scrollView) }
        }
        panTarget.onEnd = { [weak self] in self?.released() }
        scrollView.panGestureRecognizer.addTarget(panTarget, action: #selector(PanTarget.handle(_:)))
    }

    private func update(_ scrollView: UIScrollView) {
        let pulled = -(scrollView.contentOffset.y + scrollView.adjustedContentInset.top)
        let value = min(1, max(0, pulled / threshold))
        // Пока палец на экране — капли следуют за ним; после отпускания список
        // возвращается сам, и капли уходят обратно вместе с ним.
        if abs(value - progress) > 0.005 || (value == 0 && progress != 0) { progress = value }
        if scrollView.isTracking, value >= 1, !didReachThreshold {
            didReachThreshold = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else if value < 1, scrollView.isTracking {
            didReachThreshold = false
        }
    }

    private func released() {
        if didReachThreshold { onRelease() }
        didReachThreshold = false
    }

    @MainActor
    private final class PanTarget: NSObject {
        var onEnd: @MainActor () -> Void = {}

        @objc func handle(_ recognizer: UIPanGestureRecognizer) {
            if recognizer.state == .ended || recognizer.state == .cancelled { onEnd() }
        }
    }
}

/// Невидимая метка строки: отдаёт её UIView в `RowSizeStore`.
struct RowAnchor: UIViewRepresentable {
    let code: String
    let store: RowSizeStore

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        store.setAnchor(view, for: code)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        store.setAnchor(view, for: code)
    }
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

/// Индикатор обновления: из Dynamic Island вытекают две чёрные капли-монеты с белыми $ и ₿,
/// кружат под ним, а по окончании втягиваются обратно. Капли и остров сливаются, как жидкость:
/// круги размываются и обрезаются по порогу прозрачности. Без Dynamic Island капли
/// появляются из-за верхнего края экрана.
struct IslandRefreshIndicator: View {
    let isActive: Bool
    /// Насколько список потянут вниз: 0 — нет, 1 — до конца (сейчас начнётся обновление).
    var pull: CGFloat = 0

    @State private var startedAt: Date?
    @State private var endedAt: Date?

    private let dropDistance: CGFloat = 96
    private let coinRadius: CGFloat = 26
    private let orbit: CGFloat = 33
    private let period: Double = 1.4
    private let inDuration: Double = 0.55
    private let outDuration: Double = 0.4

    var body: some View {
        GeometryReader { proxy in
            if let startedAt {
                TimelineView(.animation) { context in
                    drops(at: context.date, startedAt: startedAt, width: proxy.size.width)
                }
            } else if pull > 0 {
                // Пока тянут — капли выходят из острова ровно настолько, насколько потянули,
                // и чуть поворачиваются.
                drops(amount: pull, angle: Double(pull) * .pi * 0.6, width: proxy.size.width)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel(L(.loading))
        .accessibilityHidden(!isActive)
        .onChange(of: isActive) { _, active in
            if active {
                // Если капли уже вытянуты жестом, не начинаем выход заново.
                startedAt = pull > 0.5 ? Date.now.addingTimeInterval(-inDuration) : .now
                endedAt = nil
            } else if startedAt != nil {
                endedAt = .now
                Task {
                    try? await Task.sleep(for: .seconds(outDuration))
                    // Если за это время началось новое обновление, endedAt уже сброшен.
                    if endedAt != nil {
                        startedAt = nil
                        endedAt = nil
                    }
                }
            }
        }
    }

    private struct Drop {
        let glyph: String
        let center: CGPoint
        let radius: CGFloat
        let depth: Double
    }

    private func drops(at date: Date, startedAt: Date, width: CGFloat) -> some View {
        let elapsed = date.timeIntervalSince(startedAt)
        // Насколько капли вытекли: быстро в начале, мягко в конце; при завершении — обратно.
        var amount = 1 - pow(1 - min(1, elapsed / inDuration), 3)
        if let endedAt {
            let back = min(1, date.timeIntervalSince(endedAt) / outDuration)
            amount *= 1 - back * back
        }
        let angle = (elapsed.truncatingRemainder(dividingBy: period) / period) * 2 * .pi
        return drops(amount: amount, angle: angle, width: width)
    }

    private func drops(amount: CGFloat, angle: Double, width: CGFloat) -> some View {
        let island = Self.islandRect(screenWidth: width)
        let center = CGPoint(x: width / 2, y: island.midY + dropDistance * amount)
        let items = [("dollarsign", 0.0), ("bitcoinsign", Double.pi)].map { pair in
            let (glyph, shift) = pair
            let a = angle + shift
            let depth = (cos(a) + 1) / 2   // 1 — спереди, 0 — сзади
            return Drop(
                glyph: glyph,
                center: CGPoint(x: center.x + orbit * amount * sin(a), y: center.y),
                radius: coinRadius * (0.45 + 0.55 * amount) * (0.82 + 0.18 * depth),
                depth: depth
            )
        }

        return ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                context.addFilter(.alphaThreshold(min: 0.5, color: .black))
                context.addFilter(.blur(radius: 7))
                context.drawLayer { layer in
                    layer.fill(Path(roundedRect: island, cornerRadius: island.height / 2), with: .color(.black))
                    for item in items {
                        let rect = CGRect(
                            x: item.center.x - item.radius,
                            y: item.center.y - item.radius,
                            width: item.radius * 2,
                            height: item.radius * 2
                        )
                        layer.fill(Path(ellipseIn: rect), with: .color(.black))
                    }
                }
            }
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                Image(systemName: item.glyph)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .scaleEffect(0.82 + 0.18 * item.depth)
                    .opacity(Double(amount) * (0.5 + 0.5 * item.depth))
                    .position(item.center)
                    .zIndex(item.depth)
            }
        }
    }

    /// Где на экране Dynamic Island (чуть меньше настоящего, чтобы прятаться под ним).
    /// Без него — капсула за верхним краем экрана, капли выходят оттуда.
    @MainActor
    private static func islandRect(screenWidth: CGFloat) -> CGRect {
        let topInset = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.top }
            .first ?? 0
        let hasIsland = topInset >= 51
        let size = CGSize(width: 120, height: 34)
        return CGRect(
            x: (screenWidth - size.width) / 2,
            y: hasIsland ? 12 : -size.height - 4,
            width: size.width,
            height: size.height
        )
    }
}

/// Всплывающее сообщение.
struct Toast: Equatable {
    enum Kind {
        case info, warning, error, success

        var tint: Color {
            switch self {
            case .info: .accentColor
            case .warning: .dynamic(light: 0xD97706, dark: 0xFBBF24)
            case .error: .dynamic(light: 0xDC2626, dark: 0xF87171)
            case .success: .dynamic(light: 0x16A34A, dark: 0x4ADE80)
            }
        }

        var symbol: String {
            switch self {
            case .info: "info.circle"
            case .warning, .error: "exclamationmark.triangle"
            case .success: "checkmark.circle"
            }
        }
    }

    var kind: Kind
    var title: String?
    var message: String
}

/// Карточка сообщения: белая плашка, цветной значок без подложки, текст и крестик —
/// всё по центру строки.
struct ToastView: View {
    let toast: Toast
    let onClose: () -> Void

    private let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.kind.symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(toast.kind.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                if let title = toast.title {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                }
                Text(toast.message)
                    .font(.subheadline)
                    .foregroundStyle(toast.title == nil ? Color.primary : Color.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.secondaryLabel)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L(.close))
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, 14)
        .background {
            shape
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(shape.strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
                .shadow(color: Color(red: 0.2, green: 0.25, blue: 0.4).opacity(0.12), radius: 16, y: 6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}
