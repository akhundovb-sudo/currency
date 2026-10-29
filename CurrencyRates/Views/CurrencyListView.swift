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
    /// Увеличивается после успешного обновления — карточки коротко подсвечиваются волной.
    @State private var refreshedCount = 0
    @State private var toast: Toast?
    @State private var toastTask: Task<Void, Never>?
    /// Счётчик «тряски» карточки ввода при переполнении суммы.
    /// Какая карточка трясётся и фаза тряски (0…1). Вне тряски фаза всегда 0 — поэтому
    /// смена выбранной валюты не «проигрывает» тряску.
    /// Сколько раз тряслась сумма каждой валюты: смена числа запускает тряску.
    @State private var shakeCounts: [String: Int] = [:]
    /// Перетаскивание карточки: какая, откуда, куда и на сколько сдвинута под пальцем.
    @State private var drag: RowDrag?
    /// Когда отпустили карточку: нажатие, пришедшее сразу за этим, не открывает клавиатуру.
    @State private var lastDragEnd = Date.distantPast
    /// Размеры строк для определения, куда пришлось нажатие. Обычный класс, а не состояние:
    /// запись при прокрутке не должна перерисовывать весь список.
    @State private var rowSizes = RowSizeStore()
    @State private var pullTracker = PullTracker()
    /// Ширина экрана — на iPad и в широком окне карточки не растягиваются на всю ширину.
    @State private var screenWidth: CGFloat = 0
    /// Фокус для ввода с внешней клавиатуры (iPad).
    @FocusState private var isKeyboardFocused: Bool

    /// Карточки не шире этого — на iPad список стоит колонкой по центру.
    private static let maxContentWidth: CGFloat = 640

    /// Отступы вокруг карточки внутри строки списка.
    private static let rowPadding = CGSize(width: 16, height: 4)

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
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { screenWidth = $0 }
            // Внешняя клавиатура (только iPad): суммы можно набирать с неё.
            .modifier(HardwareKeyboardInput(isFocused: $isKeyboardFocused, onKey: handleHardwareKey))
            .sheet(isPresented: $isAddPresented) {
                // Выбранные на момент открытия — первыми; список берётся при каждом открытии окна.
                AddCurrencyView(pinned: store.selectedCodes)
            }
            // Вместо системного индикатора — капли из Dynamic Island.
            .overlay { IslandRefreshIndicator(isActive: isRefreshing, pull: pullTracker.progress, failed: store.errorMessage != nil) }
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
                            idleSourceCaption: idleSourceCaption,
                            shakeTrigger: shakeCounts[code, default: 0],
                            isReordering: editMode.isEditing
                        )
                        .card(selected: code == store.sourceCode && isKeypadVisible)
                        // Фокус: выбранная карточка приподнимается — чуть крупнее, с мягкой тенью.
                        .scaleEffect(isKeypadVisible && code == store.sourceCode ? 1.025 : 1)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isKeypadVisible)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.sourceCode)
                        // Курсы обновились: карточки по очереди сверху вниз коротко увеличиваются
                        // и пружинят обратно — волна.
                        .keyframeAnimator(initialValue: 1.0, trigger: refreshedCount) { content, scale in
                            content.scaleEffect(scale)
                        } keyframes: { _ in
                            // Кадр нулевой длины даёт NaN-масштаб, и первая карточка пропадала.
                            let delay = 0.001 + Double(store.selectedCodes.firstIndex(of: code) ?? 0) * 0.06
                            KeyframeTrack {
                                LinearKeyframe(1.0, duration: delay)
                                CubicKeyframe(1.04, duration: 0.16)
                                SpringKeyframe(1.0, duration: 0.45, spring: .bouncy)
                            }
                        }
                        // Ручка перетаскивания — видно, что карточку можно передвинуть.
                        if editMode.isEditing {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.secondaryLabel)
                                .frame(width: 28, height: 44)
                                .contentShape(Rectangle())
                                .transition(.scale(scale: 0.4).combined(with: .opacity))
                                .accessibilityHidden(true)
                        }
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
                        // Своё перетаскивание: долгое нажатие поднимает карточку, дальше она едет
                        // за пальцем, остальные расступаются. Системное перетаскивание List
                        // конфликтовало с жестами карточки и не давало поставить валюту первой.
                        .scaleEffect(drag?.code == code ? 1.04 : 1)
                        .shadow(color: .black.opacity(drag?.code == code ? 0.18 : 0), radius: 18, y: 10)
                        .offset(y: rowOffset(for: code))
                        .zIndex(drag?.code == code ? 1 : 0)
                        // Перестановка — в режиме правки: потянуть карточку (за неё или за ручку справа).
                        .simultaneousGesture(editReorderGesture(for: code), including: editMode.isEditing ? .all : .none)
                        // Долгое нажатие поднимает карточку, и её сразу можно перетащить —
                        // без режима правки. Обычное нажатие не задерживается.
                        .modifier(HoldToDrag(
                            isEnabled: !editMode.isEditing,
                            onChanged: { dragChanged(code, translation: $0) },
                            onEnded: dragEnded
                        ))
                        // В списке вся строка ловит нажатие, поэтому смотрим, куда оно пришлось:
                        // в карточку — выбор валюты, в отступ вокруг — закрыть клавиатуру.
                        .onTapGesture(coordinateSpace: .local) { location in
                            // Отпустили поднятую карточку — это не нажатие.
                            guard drag == nil, Date().timeIntervalSince(lastDragEnd) > 0.3 else { return }
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
                }

                statusSection
            }
            .listStyle(.plain)
            // На широком экране — колонка по центру, а не карточки во всю ширину.
            .contentMargins(.horizontal, max(0, (screenWidth - Self.maxContentWidth) / 2), for: .scrollContent)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .environment(\.editMode, $editMode)
            // Страховка: если жест перетаскивания не сообщил о конце, карточка не остаётся
            // поднятой — иначе список не прокручивается и нажатия не доходят.
            .onChange(of: editMode.isEditing) { _, _ in
                if drag != nil { dragEnded() }
            }
            // Пока карточку тащат, список не прокручивается под пальцем.
            .scrollDisabled(drag != nil)
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
                        .frame(maxWidth: 480)
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
            // Валюты отключены (подписка закончилась или сменился набор бесплатных) —
            // объясняем, куда они делись: при входе и сразу, если это случилось во время работы.
            .onAppear(perform: showSuspensionNotice)
            .onChange(of: store.suspensionNotice) { _, _ in showSuspensionNotice() }
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
                        onKey: press,
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

    private func showSuspensionNotice() {
        guard let notice = store.suspensionNotice else { return }
        store.suspensionNotice = nil
        let message = switch notice.reason {
        case .proEnded: L(.proSuspended)
        case .freeSetChanged: L(.freeSetChanged, notice.codes.joined(separator: ", "))
        }
        showToast(Toast(kind: .info, message: message), duration: 6)
    }

    /// Показывает сообщение снизу; оно само скрывается через `duration` секунд.
    private func showToast(_ newToast: Toast, duration: Double = 3) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { toast = newToast }
        toastTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            dismissToast()
        }
    }

    private func dismissToast() {
        toastTask?.cancel()
        withAnimation(.easeInOut(duration: 0.25)) { toast = nil }
    }

    /// Трясёт сумму в строке ввода. Раньше тряска шла через две смены состояния в одном кадре
    /// (сброс без анимации и запуск с анимацией): SwiftUI сливал их, анимация отключалась,
    /// и сумма не двигалась — была только вибрация.
    private func shake(_ code: String) {
        shakeCounts[code, default: 0] += 1
    }

    // MARK: - Перетаскивание

    struct RowDrag: Equatable {
        let code: String
        let from: Int
        var to: Int
        var offset: CGFloat
        let rowHeight: CGFloat
    }

    /// Сдвиг строки: перетаскиваемая — за пальцем, остальные расступаются на её место.
    private func rowOffset(for code: String) -> CGFloat {
        guard let drag, let index = store.selectedCodes.firstIndex(of: code) else { return 0 }
        if code == drag.code { return drag.offset }
        if drag.from < drag.to, index > drag.from, index <= drag.to { return -drag.rowHeight }
        if drag.from > drag.to, index >= drag.to, index < drag.from { return drag.rowHeight }
        return 0
    }

    /// В режиме правки карточку тянут сразу.
    private func editReorderGesture(for code: String) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .global)
            .onChanged { value in dragChanged(code, translation: value.translation.height) }
            .onEnded { _ in dragEnded() }
    }

    private func dragChanged(_ code: String, translation: CGFloat) {
        guard let from = store.selectedCodes.firstIndex(of: code) else { return }
        if drag == nil {
            if isKeypadVisible { hideKeypad() }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            let height = rowSizes.sizes[code]?.height ?? 88
            withAnimation(.snappy(duration: 0.2)) {
                drag = RowDrag(code: code, from: from, to: from, offset: 0, rowHeight: height)
            }
        }
        guard var current = drag, current.code == code else { return }
        current.offset = translation
        let steps = Int((current.offset / current.rowHeight).rounded())
        let target = min(max(current.from + steps, 0), store.selectedCodes.count - 1)
        if target != current.to {
            UISelectionFeedbackGenerator().selectionChanged()
            current.to = target
            withAnimation(.snappy(duration: 0.25)) { drag = current }
        } else {
            drag = current
        }
    }

    private func dragEnded() {
        guard let finished = drag else { return }
        lastDragEnd = Date()
        // Ставим строку на новое место без анимации, а затем плавно убираем сдвиги:
        // карточка «доезжает» в свою ячейку, остальные остаются, где расступились.
        var settle = Transaction()
        settle.disablesAnimations = true
        withTransaction(settle) {
            if finished.to != finished.from {
                store.move(
                    fromOffsets: IndexSet(integer: finished.from),
                    toOffset: finished.to > finished.from ? finished.to + 1 : finished.to
                )
            }
            let landed = CGFloat(finished.to - finished.from) * finished.rowHeight
            drag = RowDrag(code: finished.code, from: finished.to, to: finished.to,
                           offset: finished.offset - landed, rowHeight: finished.rowHeight)
        }
        withAnimation(.snappy(duration: 0.3)) { drag = nil }
    }

    private func startEditing(_ code: String) {
        guard !editMode.isEditing else { return }
        // Повторное нажатие на валюту, которую уже вводят, закрывает клавиатуру.
        if code == store.sourceCode && isKeypadVisible {
            hideKeypad()
            return
        }
        UISelectionFeedbackGenerator().selectionChanged()
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
            // Подсветка карточек — когда капля закончила обновление.
            if store.errorMessage == nil {
                try? await Task.sleep(for: .seconds(0.3))
                refreshedCount += 1
            }
        }
    }

    /// Нажатие клавиши — на экранной клавиатуре или на внешней.
    private func press(_ key: KeypadKey) {
        let accepted = withAnimation(.snappy(duration: 0.2)) { store.press(key) }
        if !accepted {
            // Не помещается: тряска карточки и вибрация ошибки.
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            shake(store.sourceCode)
        }
    }

    /// Ввод с внешней клавиатуры (iPad): цифры, запятая/точка, + − × ÷, = и Enter,
    /// ⌫ стирает, Esc прячет клавиатуру. Работает, пока открыта экранная клавиатура.
    private func handleHardwareKey(_ keyPress: KeyPress) -> KeyPress.Result {
        guard isKeypadVisible else { return .ignored }
        if keyPress.key == .delete { press(.backspace); return .handled }
        if keyPress.key == .return { press(.equals); return .handled }
        if keyPress.key == .escape { hideKeypad(); return .handled }
        guard let character = keyPress.characters.first else { return .ignored }
        let key: KeypadKey
        if character.isASCII, let digit = character.wholeNumberValue {
            key = .digit(digit)
        } else {
            switch character {
            case ".", ",": key = .decimal
            case "+": key = .add
            case "-", "−": key = .subtract
            case "*", "x", "X", "×": key = .multiply
            case "/", "÷": key = .divide
            case "=": key = .equals
            default: return .ignored
            }
        }
        press(key)
        return .handled
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


/// Индикатор обновления: из Dynamic Island выпадает капля со знаком выбранной иконки —
/// тянется за ним жидкой каплей (фигуры размываются и обрезаются по порогу прозрачности)
/// и крутится вокруг своей оси, как подброшенная. Чем сильнее тянут, тем ниже она опускается.
/// Когда курсы обновились, монета разворачивается лицом, подпрыгивает и улетает обратно
/// в остров; при ошибке вокруг неё вспыхивает красное свечение.
/// Без Dynamic Island монета выходит из-за верхнего края экрана.
struct IslandRefreshIndicator: View {
    let isActive: Bool
    /// Насколько список потянут вниз: 0 — нет, 1 — до конца (сейчас начнётся обновление).
    var pull: CGFloat = 0
    /// Обновить не удалось — вокруг монеты вспыхивает красное свечение.
    var failed = false

    @State private var startedAt: Date?
    @State private var endedAt: Date?
    @Environment(\.colorScheme) private var colorScheme

    /// Капля: в светлой теме чёрная, как остров; в тёмной — чуть светлее, иначе её не видно.
    private var dropColor: Color { colorScheme == .dark ? Color(white: 0.17) : .black }

    private let dropDistance: CGFloat = 80
    // Крупнее: тонкий серебряный знак на маленькой монете было не разглядеть.
    private let coinSize: CGFloat = 64
    private let inDuration: Double = 0.45
    /// Оборотов в секунду, пока идёт обновление.
    private let spinRate: Double = 1.1
    /// Завершение: монета доворачивается лицом и подпрыгивает, потом улетает в остров.
    private let settleDuration: Double = 0.35
    private let hopDuration: Double = 0.3
    private let outDuration: Double = 0.35

    private static let face = Color(hex: 0x131313)
    private static let failure = Color(hex: 0xF87171)

    var body: some View {
        GeometryReader { proxy in
            if let startedAt {
                TimelineView(.animation) { context in
                    running(at: context.date, startedAt: startedAt, width: proxy.size.width)
                }
            } else if pull > 0 {
                // Пока тянут — монета выходит и поворачивается вслед за пальцем.
                coin(amount: pull, angle: Double(pull) * .pi, lift: 0, alert: 0, result: 0, width: proxy.size.width)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel(L(.loading))
        .accessibilityHidden(!isActive)
        .onChange(of: isActive) { _, active in
            if active {
                // Если монета уже вытянута жестом, не начинаем выход заново.
                startedAt = pull > 0.5 ? Date.now.addingTimeInterval(-inDuration) : .now
                endedAt = nil
            } else if startedAt != nil {
                endedAt = .now
                Task {
                    try? await Task.sleep(for: .seconds(settleDuration))
                    if endedAt != nil {
                        if failed {
                            UINotificationFeedbackGenerator().notificationOccurred(.error)
                        } else {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        }
                    }
                    try? await Task.sleep(for: .seconds(hopDuration + outDuration))
                    // Если за это время началось новое обновление, endedAt уже сброшен.
                    if endedAt != nil {
                        startedAt = nil
                        endedAt = nil
                    }
                }
            }
        }
    }

    private static func smooth(_ x: Double) -> Double {
        let t = min(1, max(0, x))
        return t * t * (3 - 2 * t)
    }

    private func running(at date: Date, startedAt: Date, width: CGFloat) -> some View {
        let elapsed = date.timeIntervalSince(startedAt)
        // Быстро выходит, мягко останавливается.
        var amount = 1 - pow(1 - min(1, elapsed / inDuration), 3)
        // Вращение начинается с того поворота, на котором монету отпустили.
        let spin = Double(max(pull, 0.5)) * .pi + elapsed * spinRate * 2 * .pi

        guard let endedAt else {
            return coin(amount: amount, angle: spin, lift: 0, alert: 0, result: 0, width: width)
        }
        let sinceEnd = date.timeIntervalSince(endedAt)
        // Доворот до ближайшего «лица» (целое число оборотов) с замедлением.
        let frozen = Double(max(pull, 0.5)) * .pi + endedAt.timeIntervalSince(startedAt) * spinRate * 2 * .pi
        let target = (frozen / (2 * .pi)).rounded(.up) * 2 * .pi
        let settle = 1 - pow(1 - min(1, sinceEnd / settleDuration), 3)
        let angle = frozen + (target - frozen) * settle
        // Подпрыгивает вниз-вверх, потом улетает в остров с ускорением.
        let hop = sinceEnd - settleDuration
        let lift: CGFloat = hop > 0 && hop < hopDuration ? CGFloat(sin(hop / hopDuration * .pi)) * 10 : 0
        let outTime = sinceEnd - settleDuration - hopDuration
        if outTime > 0 {
            let back = min(1, outTime / outDuration)
            amount *= 1 - back * back
        }
        let alert = failed ? sin(min(1, sinceEnd / (settleDuration + hopDuration)) * .pi) : 0
        // Знак коротко пружинит, когда обновление закончилось.
        let result = min(1, sinceEnd / settleDuration)
        return coin(amount: amount, angle: angle, lift: lift, alert: alert, result: result, width: width)
    }

    /// `angle` — поворот вокруг вертикальной оси; `lift` — подскок вниз (pt);
    /// `alert` — сила красной вспышки (0…1).
    private func coin(amount: CGFloat, angle: Double, lift: CGFloat, alert: Double, result: Double, width: CGFloat) -> some View {
        let island = Self.islandRect(screenWidth: width)
        let scale = 0.4 + 0.6 * amount
        let size = coinSize * scale
        let center = CGPoint(x: width / 2, y: island.midY + dropDistance * amount + lift)
        let blob = CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)

        return ZStack(alignment: .topLeading) {
            // Жидкая перемычка между островом и монетой.
            Canvas { context, _ in
                context.addFilter(.alphaThreshold(min: 0.5, color: dropColor))
                context.addFilter(.blur(radius: 7))
                context.drawLayer { layer in
                    layer.fill(Path(roundedRect: island, cornerRadius: island.height / 2), with: .color(.black))
                    layer.fill(Path(ellipseIn: blob), with: .color(.black))
                }
            }
            coinFace(alert: alert, phase: angle, result: result)
                .frame(width: coinSize, height: coinSize)
                .scaleEffect(scale)
                .opacity(Double(min(1, max(0, amount * 2 - 0.2))))
                .position(center)
        }
    }

    /// Знак выбранной иконки — тот же, что на сплэше.
    private static var markImage: String {
        let name = UIApplication.shared.alternateIconName?.replacingOccurrences(of: "AppIcon-", with: "") ?? "Chrome"
        return "SplashIcon-\(name)"
    }

    /// Капля с знаком выбранной иконки: знак покачивается, по нему пробегает блик.
    /// `phase` растёт со временем (раз в оборот — один блик и одно покачивание).
    private func coinFace(alert: Double, phase: Double, result: Double) -> some View {
        let mark = Self.markImage
        let sway = sin(phase) * 9
        let sweep = (phase / (2 * .pi)).truncatingRemainder(dividingBy: 1) * 1.6 - 0.3
        return ZStack {
            Circle().fill(dropColor)
            Image(mark)
                .resizable()
                // Знак с запасом воздуха по краям капли.
                .frame(width: coinSize * 0.86, height: coinSize * 0.86)
                .overlay {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: max(0, sweep - 0.15)),
                            .init(color: .white.opacity(0.7), location: min(1, max(0, sweep))),
                            .init(color: .clear, location: min(1, sweep + 0.15)),
                        ],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                    .mask(Image(mark).resizable())
                    .blendMode(.screen)
                }
                .rotationEffect(.degrees(sway))
                // Завершение: знак коротко «пружинит» — без галочки.
                .scaleEffect(1 + 0.12 * sin(result * .pi))
        }
        .clipShape(Circle())
        // При ошибке вокруг капли вспыхивает красное свечение.
        .background {
            Circle()
                .fill(Self.failure)
                .blur(radius: 10)
                .opacity(alert)
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

/// Знак ¢ — прямо, как в шрифте: буква C с прямыми срезами концов и вертикальная черта,
/// которая проходит сквозь неё и выступает сверху и снизу. Белый с лёгким объёмом.
struct CentSign: View {
    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let line = s * 0.15
            let r = s * 0.28
            // C, открытая справа: срезы под углом, как у гротеска.
            var letter = Path()
            letter.addArc(center: c, radius: r, startAngle: .degrees(-48), endAngle: .degrees(48), clockwise: true)
            // Черта чуть правее центра, сквозь кольцо.
            let x = c.x + s * 0.03
            var bar = Path()
            bar.move(to: CGPoint(x: x, y: c.y - s * 0.46))
            bar.addLine(to: CGPoint(x: x, y: c.y + s * 0.46))
            let style = StrokeStyle(lineWidth: line, lineCap: .butt)
            let shape = letter.strokedPath(style).union(bar.strokedPath(StrokeStyle(lineWidth: line * 0.62, lineCap: .butt)))
            context.fill(
                shape,
                with: .linearGradient(
                    Gradient(colors: [.white, Color(white: 0.82)]),
                    startPoint: CGPoint(x: c.x, y: c.y - s * 0.5),
                    endPoint: CGPoint(x: c.x, y: c.y + s * 0.5)
                )
            )
        }
        .accessibilityHidden(true)
    }
}

/// Всплывающее сообщение.
struct Toast: Equatable {
    enum Kind {
        case info, warning, error, success

        var tint: Color {
            switch self {
            case .info: .dynamic(light: 0x2563EB, dark: 0x60A5FA)
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

    private let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

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

/// Ввод с внешней клавиатуры — только на iPad, чтобы фокус не мешал нажатиям на iPhone.
private struct HardwareKeyboardInput: ViewModifier {
    var isFocused: FocusState<Bool>.Binding
    let onKey: (KeyPress) -> KeyPress.Result

    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            content
                .focusable()
                .focusEffectDisabled()
                .focused(isFocused)
                .onKeyPress(phases: .down, action: onKey)
                .onAppear { isFocused.wrappedValue = true }
        } else {
            content
        }
    }
}

/// Вне режима правки: долгое нажатие поднимает карточку, дальше она едет за пальцем.
/// Системный жест UIKit: пока палец не задержался, он ничего не перехватывает —
/// нажатия на карточку и прокрутка работают как обычно. Связка жестов SwiftUI
/// «долгое нажатие → перетаскивание» мешала обычным нажатиям, и сумма не вводилась.
private struct HoldToDrag: ViewModifier {
    let isEnabled: Bool
    /// Сдвиг пальца по вертикали от места, где карточку подняли.
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content.gesture(HoldToDragGesture(isEnabled: isEnabled, onChanged: onChanged, onEnded: onEnded))
        } else {
            // iOS 17: переставляют в режиме правки.
            content
        }
    }
}

@available(iOS 18, *)
private struct HoldToDragGesture: UIGestureRecognizerRepresentable {
    let isEnabled: Bool
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let press = UILongPressGestureRecognizer()
        press.minimumPressDuration = 0.4
        press.isEnabled = isEnabled
        return press
    }

    func updateUIGestureRecognizer(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        // Координаты окна: строка сама едет за пальцем, её собственные координаты сдвигаются.
        let y = recognizer.location(in: nil).y
        switch recognizer.state {
        case .began:
            context.coordinator.startY = y
            onChanged(0)
        case .changed:
            onChanged(y - context.coordinator.startY)
        case .ended, .cancelled, .failed:
            onEnded()
        default:
            break
        }
    }

    final class Coordinator {
        var startY: CGFloat = 0
    }
}
