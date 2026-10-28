import SwiftUI
import UIKit

/// Клавиша ввода суммы.
enum KeypadKey: Hashable {
    case digit(Int)
    case decimal
    case backspace
    case add, subtract, multiply, divide, equals
    /// Скрыть клавиатуру — не меняет сумму.
    case hide

    var isOperator: Bool {
        switch self {
        case .add, .subtract, .multiply, .divide, .equals, .backspace: true
        default: false
        }
    }
}

/// Цифровая клавиатура со стеклянными клавишами и рядом действий калькулятора.
struct AmountKeypad: View {
    let onKey: (KeypadKey) -> Void
    /// Долгое нажатие на ⌫ очищает сумму.
    let onClear: () -> Void
    let onDone: () -> Void

    private let operators: [KeypadKey] = [.divide, .multiply, .subtract, .add, .equals]

    private let rows: [[KeypadKey]] = [
        [.digit(1), .digit(2), .digit(3)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(7), .digit(8), .digit(9)],
        [.decimal, .digit(0), .hide],
    ]

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(operators, id: \.self) { key in
                    KeypadButton(key: key, onTap: { onKey(key) })
                }
                KeypadButton(key: .backspace, onTap: { onKey(.backspace) }, onLongPress: onClear)
            }

            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                ForEach(rows, id: \.self) { row in
                    GridRow {
                        ForEach(row, id: \.self) { key in
                            KeypadButton(key: key, onTap: { key == .hide ? onDone() : onKey(key) })
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .background {
            // Стеклянная панель со скруглённым верхом, продолжается под нижнюю безопасную зону.
            PanelGlass()
                .ignoresSafeArea(edges: .bottom)
        }
        // Вся панель, включая зазоры между клавишами и безопасную зону, ловит нажатия:
        // иначе они проходят сквозь стекло к карточке под ней и выбирают её.
        .contentShape(Rectangle())
        .onTapGesture {}
    }
}

/// Стеклянная подложка клавиатуры: Liquid Glass в iOS 26, полупрозрачный материал — раньше.
private struct PanelGlass: View {
    private let shape = UnevenRoundedRectangle(topLeadingRadius: 36, topTrailingRadius: 36, style: .continuous)
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if colorScheme == .dark {
            // Тёмная тема: плотная панель — сквозь стекло просвечивали карточки, и клавиши
            // смотрелись грязно. Сверху — тонкая светлая кромка.
            shape
                .fill(Color(white: 0.11))
                .overlay(
                    shape.strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.12), .clear], startPoint: .top, endPoint: .init(x: 0.5, y: 0.15)),
                        lineWidth: 1
                    )
                )
        } else if #available(iOS 26, *) {
            Color.clear
                .glassEffect(.regular.tint(Color.glassNeutral.opacity(0.22)), in: shape)
        } else {
            shape
                .fill(.regularMaterial)
                .overlay(shape.fill(Color.glassNeutral.opacity(0.13)))
        }
    }
}

private struct KeypadButton: View {
    let key: KeypadKey
    let onTap: () -> Void
    var onLongPress: (() -> Void)?

    @ScaledMetric(relativeTo: .title) private var height = 56
    @State private var isBouncing = false

    var body: some View {
        Button(action: tap) {
            label
                .frame(maxWidth: .infinity)
                .frame(height: min(key.isOperator ? height * 0.8 : height, 80))
        }
        .buttonStyle(GlassBubbleStyle(tint: tint))
        .scaleEffect(isBouncing ? 0.88 : 1)
        // Долгое нажатие — только у ⌫, чтобы не мешать анимации нажатия остальных клавиш.
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in onLongPress?() },
            including: onLongPress == nil ? .subviews : .all
        )
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(key == .backspace ? L(.longPressClears) : "")
    }

    private func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        // Отскок на каждое нажатие — заметен даже при быстром касании.
        withAnimation(.easeOut(duration: 0.07)) { isBouncing = true }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.07)) { isBouncing = false }
        onTap()
    }

    @ViewBuilder
    private var label: some View {
        switch key {
        case .digit(let digit):
            Text("\(digit)").font(.title)
        case .decimal:
            Text(Calculator.decimalSeparator).font(.title)
        case .backspace:
            AppIcon("icon-backspace", size: 26)
                .foregroundStyle(Color.primary)
        default:
            AppIcon(operatorSymbol, size: key == .hide ? 28 : 24)
                .foregroundStyle(operatorColor)
        }
    }

    private var accessibilityLabel: String {
        switch key {
        case .digit(let digit): "\(digit)"
        case .decimal: L(.comma)
        case .backspace: L(.erase)
        case .add: L(.plus)
        case .subtract: L(.minus)
        case .multiply: L(.multiply)
        case .divide: L(.divide)
        case .equals: L(.equals)
        case .hide: L(.hideKeyboard)
        }
    }

    /// Цвет стекла клавиши: у цифр — нейтральный, у знаков — цвет акцента.
    private var tint: Color {
        switch key {
        case .digit, .decimal, .hide: .glassNeutral
        case .backspace: .glassNeutral
        default: operatorColor
        }
    }

    /// Своя палитра знаков; «=» — цвет акцента.
    private var operatorColor: Color {
        switch key {
        case .divide: .operatorDivide
        case .multiply: .operatorMultiply
        case .subtract: .operatorSubtract
        case .add: .operatorAdd
        case .hide, .backspace: .primary
        default: .accentColor                                      // = основной цвет
        }
    }

    private var operatorSymbol: String {
        switch key {
        case .add: "icon-plus"
        case .subtract: "icon-minus"
        case .multiply: "icon-multiply"
        case .divide: "icon-divide"
        case .hide: "icon-keyboard-hide"
        default: "icon-equal"
        }
    }
}

#Preview {
    VStack {
        Spacer()
        AmountKeypad(onKey: { _ in }, onClear: {}, onDone: {})
    }
}

extension Color {
    static let operatorDivide = Color.dynamic(light: 0x0284C7, dark: 0x38BDF8)   // небесно-синий
    static let operatorMultiply = Color.dynamic(light: 0xCA8A04, dark: 0xFACC15) // золотисто-жёлтый, чтобы не путать с красным «−»
    static let operatorSubtract = Color.dynamic(light: 0xE11D48, dark: 0xFB7185) // розовый
    static let operatorAdd = Color.dynamic(light: 0x059669, dark: 0x34D399)      // изумрудный
}
