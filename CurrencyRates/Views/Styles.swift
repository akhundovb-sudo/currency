import SwiftUI
import UIKit
import CoreText

extension Font {
    /// Шрифт сумм — SF Pro Rounded Bold, масштабируется с Dynamic Type.
    static let amount = Font.system(.title2, design: .rounded).weight(.bold)
}

/// Иконка из Assets/Icons (Iconoir, MIT; толщина линий 2) нужного размера.
struct AppIcon: View {
    let name: String
    var size: CGFloat = 24

    init(_ name: String, size: CGFloat = 24) {
        self.name = name
        self.size = size
    }

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

extension Color {
    /// Цвет вводимой суммы и курсора.
    static let amountHighlight = Color.accentColor

    /// Фон карточки валюты (Semantic/Background/Primary в макете).
    static let cardBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
            : UIColor(red: 0xF3 / 255, green: 0xF4 / 255, blue: 0xF5 / 255, alpha: 1)
    })

    /// Второстепенный текст (Semantic/Foreground/Secondary в макете).
    static let secondaryLabel = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xA1 / 255, green: 0xA1 / 255, blue: 0xA6 / 255, alpha: 1)
            : UIColor(red: 0x59 / 255, green: 0x59 / 255, blue: 0x59 / 255, alpha: 1)
    })
}

extension Color {
    /// Цвет с отдельными оттенками для светлой и тёмной темы (значения — 0xRRGGBB).
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        func ui(_ hex: UInt32) -> UIColor {
            UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        }
        return Color(UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
    }
}

/// Карточка из макета (скругление 20) с лёгким стеклом: полупрозрачная светлая плашка,
/// мягкий блик сверху и светлый ободок. Без теней. Выбранная — с рамкой цвета акцента.
struct CardStyle: ViewModifier {
    var isSelected = false
    @State private var isPopped = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        content
            .background {
                // Чистая белая плашка и мягкая холодная тень — без серого материала и тёмного низа.
                shape
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: Color(red: 0.2, green: 0.25, blue: 0.4).opacity(0.06), radius: 12, y: 4)
                // Фокус — стекло: лёгкое свечение акцента внутри, блик сверху и мягкий ореол вокруг.
                ZStack {
                    if isSelected {
                        ZStack {
                            shape.fill(
                                RadialGradient(
                                    colors: [Color.accentColor.opacity(0.13), Color.accentColor.opacity(0.03)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 220
                                )
                            )
                            shape.fill(
                                LinearGradient(
                                    colors: [Color.glassRim.opacity(0.6), Color.glassRim.opacity(0)],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                        }
                        .shadow(color: Color.accentColor.opacity(0.22), radius: 14, y: 4)
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: isSelected)
            }
            .overlay {
                // Анимация привязана к самому ободку, а не ко всей карточке: иначе она захватывает
                // текст, и при смене валюты подписи курса накладываются друг на друга.
                ZStack {
                    if isSelected {
                        // Стеклянный ободок: светлый сверху, с оттенком акцента снизу.
                        shape.strokeBorder(
                            LinearGradient(
                                colors: [Color.glassRim, Color.accentColor.opacity(0.45)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                        .transition(.opacity.combined(with: .scale(scale: 1.04)))
                    } else {
                        // Светлый ободок: ярче сверху, к низу почти исчезает.
                        shape.strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: isSelected)
            }
            // Выбор: короткий «пружинящий» отклик карточки.
            .scaleEffect(isPopped ? 1.035 : 1)
            .onChange(of: isSelected) { _, selected in
                guard selected else { return }
                withAnimation(.snappy(duration: 0.14)) { isPopped = true }
                withAnimation(.bouncy(duration: 0.4).delay(0.14)) { isPopped = false }
            }
    }
}

extension View {
    func card(selected: Bool = false) -> some View {
        modifier(CardStyle(isSelected: selected))
    }

    /// Строка списка без системной подложки — её заменяет карточка; между карточками 12 pt.
    func cardListRow() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }
}

/// Стеклянная кнопка в iOS 26, обычная — в более ранних версиях.
struct GlassButtonStyle: ViewModifier {
    var prominent = false

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            if prominent {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.glass)
            }
        } else if prominent {
            content.buttonStyle(.borderedProminent)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

/// Стеклянная клавиша: радиальное свечение цвета `tint` внутри, светлеющее к краям,
/// яркий белый ободок и тонкая цветная обводка снаружи. `prominent` — насыщенная заливка.
/// В iOS 26 поверх — прозрачное Liquid Glass для преломления и реакции на нажатие.
struct GlassBubbleStyle: ButtonStyle {
    let tint: Color
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.primary)
            .background {
                GeometryReader { proxy in
                    let radius = max(proxy.size.width, proxy.size.height) * 0.6
                    ZStack {
                        Capsule().fill(Color.glassBase)
                        Capsule().fill(
                            RadialGradient(
                                colors: prominent
                                    ? [tint, tint.opacity(0.55)]
                                    : [tint.opacity(0.22), tint.opacity(0.04)],
                                center: .center,
                                startRadius: 0,
                                endRadius: radius
                            )
                        )
                        // Белый ободок со светлым бликом сверху.
                        Capsule().strokeBorder(
                            LinearGradient(
                                colors: [Color.glassRim, Color.glassRim.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2.5
                        )
                        // Тонкая цветная обводка снаружи ободка.
                        Capsule().strokeBorder(tint.opacity(prominent ? 0.8 : 0.45), lineWidth: 1)
                    }
                }
            }
            .modifier(ClearGlassOverlay())
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

struct ClearGlassOverlay: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.clear.interactive(), in: Capsule())
        } else {
            content
        }
    }
}

/// Нейтральный тон стеклянных кнопок.
extension Color {
    static let glassNeutral = Color.dynamic(light: 0x94A3B8, dark: 0x64748B)

    /// Основа стеклянных кнопок: белая в светлой теме, тёмно-серая (чуть светлее фона) — в тёмной.
    static let glassBase = Color.dynamic(light: 0xFFFFFF, dark: 0x2C2C2E)

    /// Светлый ободок стекла: белый в светлой теме; в тёмной — едва заметный,
    /// иначе на чёрном фоне получаются резкие белые кольца.
    static let glassRim = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.16) : .white
    })
}

extension ToolbarContent {
    /// Убирает общую подложку панели, чтобы было видно собственное стекло кнопок (iOS 26).
    @ToolbarContentBuilder
    func hidingSharedGlass() -> some ToolbarContent {
        if #available(iOS 26, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}

/// Свайп влево по карточке открывает красный блок удаления высотой с карточку.
/// Нажатие на блок или длинный свайп удаляют сразу.
struct SwipeToDelete: ViewModifier {
    let isEnabled: Bool
    /// Можно ли удалить. Если нет — блок серый, нажатие даёт вибрацию ошибки и закрывает свайп.
    var canDelete = true
    /// Вызывается при попытке удалить, когда удаление недоступно.
    var onBlocked: () -> Void = {}
    let label: String
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var startOffset: CGFloat = 0
    @State private var isDragging = false

    private let revealWidth: CGFloat = 88
    private let gap: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            // Пока блок открыт, нажатие на карточку только закрывает его.
            .overlay {
                if offset < 0 {
                    Color.clear
                        .contentShape(Rectangle())
                        .offset(x: offset)
                        .onTapGesture { withAnimation(.snappy) { offset = 0 } }
                }
            }
            .background(alignment: .trailing) {
                if offset < 0 {
                    Button(action: delete) {
                        AppIcon("icon-trash", size: 24)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background { DeleteBlock(cornerRadius: 20, isDisabled: !canDelete) }
                    }
                    .buttonStyle(.plain)
                    .frame(width: max(0, -offset - gap))
                    .accessibilityLabel(label)
                }
            }
            .modifier(HorizontalSwipe(onChanged: dragChanged, onEnded: dragEnded))
            .onChange(of: isEnabled) { _, enabled in
                if !enabled { withAnimation(.snappy) { offset = 0 } }
            }
            .accessibilityAction(named: label) { if isEnabled { delete() } }
    }

    private func dragChanged(_ translation: CGFloat) {
        guard isEnabled else { return }
        if !isDragging {
            isDragging = true
            startOffset = offset
        }
        offset = min(0, startOffset + translation)
    }

    private func dragEnded() {
        guard isDragging else { return }
        isDragging = false
        if -offset > 220 {
            delete()
        } else {
            withAnimation(.snappy) { offset = -offset > revealWidth / 2 ? -(revealWidth + gap) : 0 }
        }
    }

    private func delete() {
        guard canDelete else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            withAnimation(.snappy) { offset = 0 }
            onBlocked()
            return
        }
        withAnimation(.snappy) {
            offset = 0
            onDelete()
        }
    }
}

/// Горизонтальный жест свайпа. Вертикальное движение всегда остаётся списку:
/// иначе прокрутка и «потяните, чтобы обновить» срабатывали через раз.
private struct HorizontalSwipe: ViewModifier {
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            // Системный жест UIKit: начинается, только если палец идёт вбок,
            // и не отнимает вертикальный свайп у прокрутки.
            content.gesture(HorizontalPanGesture(onChanged: onChanged, onEnded: onEnded))
        } else {
            content.simultaneousGesture(
                DragGesture(minimumDistance: 16)
                    .onChanged { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        onChanged(value.translation.width)
                    }
                    .onEnded { _ in onEnded() }
            )
        }
    }
}

@available(iOS 18, *)
private struct HorizontalPanGesture: UIGestureRecognizerRepresentable {
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began, .changed:
            onChanged(recognizer.translation(in: recognizer.view).x)
        case .ended, .cancelled, .failed:
            onEnded()
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        /// Начинаем только при движении вбок; вертикальное — прокрутка списка.
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y) * 1.2
        }
    }
}

/// Красный блок удаления: ровная заливка, тонкий светлый ободок, лёгкая тень.
struct DeleteBlock: View {
    var cornerRadius: CGFloat = 20
    /// Удаление недоступно — серый блок.
    var isDisabled = false

    static let red = Color.dynamic(light: 0xEF4444, dark: 0xF87171)

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(isDisabled ? Color(.systemGray3).gradient : Self.red.gradient)
            .overlay(shape.strokeBorder(.white.opacity(0.35), lineWidth: 1))
    }
}

extension View {
    func swipeToDelete(
        isEnabled: Bool,
        canDelete: Bool = true,
        onBlocked: @escaping () -> Void = {},
        label: String,
        onDelete: @escaping () -> Void
    ) -> some View {
        modifier(SwipeToDelete(isEnabled: isEnabled, canDelete: canDelete, onBlocked: onBlocked, label: label, onDelete: onDelete))
    }
}

/// Кнопка панели в стиле карточек валют: плашка с объёмом (светлый верх, чуть темнее низ),
/// нижняя грань, светлый ободок и мягкая тень.
struct CardBubbleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.primary)
            .background { CardBubbleBackground() }
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

/// Подложка кнопки: симметричная, чтобы текст и иконки визуально стояли ровно по центру.
struct CardBubbleBackground: View {
    var body: some View {
        ZStack {
            Capsule().fill(.thinMaterial)
            Capsule().fill(Color(.secondarySystemGroupedBackground).opacity(0.8))
            Capsule().strokeBorder(Color.glassRim.opacity(0.9), lineWidth: 1)
            Capsule().strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        }
        .shadow(color: Color(red: 0.35, green: 0.37, blue: 0.5).opacity(0.12), radius: 8, y: 0)
    }
}

/// Ловит нажатия в пустые места списка (не в ячейки) и вызывает `onTap`.
/// Нужно потому, что SwiftUI List не передаёт такие нажатия жестам SwiftUI.
struct EmptySpaceTapCatcher: UIViewRepresentable {
    let onTap: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    func makeUIView(context: Context) -> UIView {
        let view = HostView()
        view.coordinator = context.coordinator
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onTap = onTap
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onTap: () -> Void
        init(onTap: @escaping () -> Void) { self.onTap = onTap }

        @objc func handle(_ recognizer: UITapGestureRecognizer) { onTap() }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let view = touch.view else { return false }
            // Пустое место списка — нажатие пришлось на сам скролл, а не на ячейку.
            if view is UIScrollView { return true }
            // Пустое место панели навигации — между кнопками, но не на них.
            var current: UIView? = view
            while let v = current {
                if v is UIControl { return false }
                if v is UINavigationBar { return true }
                current = v.superview
            }
            return false
        }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }

    final class HostView: UIView {
        weak var coordinator: Coordinator?
        private var installed: UITapGestureRecognizer?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window, installed == nil, let coordinator else { return }
            let tap = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.handle(_:)))
            tap.cancelsTouchesInView = false
            tap.delegate = coordinator
            window.addGestureRecognizer(tap)
            installed = tap
        }

        override func willMove(toWindow newWindow: UIWindow?) {
            if newWindow == nil, let installed { installed.view?.removeGestureRecognizer(installed); self.installed = nil }
            super.willMove(toWindow: newWindow)
        }
    }
}

/// Главная кнопка («Готово»): заливка основным цветом, белый текст, светлый ободок.
struct AccentBubbleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background {
                Capsule()
                    .fill(Color.accentColor.gradient)
                    .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 8, y: 2)
            }
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

/// Выключает системный край прокрутки сверху (iOS 26+): его вид меняется от версии к версии
/// и даёт линию; размытие под панелью рисует TopFade.
struct SoftTopEdge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.scrollEdgeEffectHidden(true, for: .top)
        } else {
            content
        }
    }
}

/// Мягкий переход под верхней панелью: плотное размытие под кнопками,
/// плавно сходящее на нет ниже, — одинаково на всех версиях iOS.
struct TopFade: View {
    var body: some View {
        ProgressiveTopBlur()
    }
}

/// Прячет фон системной панели — размытие рисует TopFade.
struct HiddenBarBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbarBackground(.hidden, for: .navigationBar)
    }
}

/// Размытие под панелью: лёгкое матовое стекло под кнопками и заголовком,
/// ниже плавно сходит на нет — без линии и без плотной белой дымки.
private struct ProgressiveTopBlur: View {
    /// На сколько ниже панели продолжается затухание.
    private let fadeLength: CGFloat = 32

    var body: some View {
        GeometryReader { proxy in
            let barBottom = Self.barHeight(reported: proxy.safeAreaInsets.top)
            let height = barBottom + fadeLength
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black.opacity(0.85), location: barBottom / height * 0.8),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .frame(height: height)
        }
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Высота статус-бара и панели. Если SwiftUI сообщил подозрительно малый отступ,
    /// берём отступ окна плюс стандартную высоту панели.
    @MainActor
    private static func barHeight(reported: CGFloat) -> CGFloat {
        if reported > 30 { return reported }
        let window = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
        return (window?.safeAreaInsets.top ?? 59) + 44
    }
}

extension View {
    /// Верхняя панель без фона и без линии: содержимое под ней мягко размывается и затухает.
    func softTopBar() -> some View {
        modifier(HiddenBarBackground())
            .modifier(SoftTopEdge())
            .overlay(alignment: .top) { TopFade() }
    }
}
