import SwiftUI
import VisionKit

/// Сканер цен: камера распознаёт числа на ценниках и в меню прямо на устройстве
/// (VisionKit, без интернета и сервера) и поверх каждой цены показывает сумму в выбранной валюте.
/// Нажатие на сумму переносит цену в главный список.
struct PriceScannerView: View {
    @Environment(RatesStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var model = ScanModel()
    @State private var from = ""
    @State private var to = ""

    private var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if isSupported {
                PriceCamera(model: model)
                    .ignoresSafeArea()
                badges
                    .ignoresSafeArea()
            } else {
                unavailable
            }
        }
        .overlay(alignment: .topLeading) { closeButton }
        .overlay(alignment: .bottom) { if isSupported { currencyBar } }
        .onAppear(perform: chooseDefaults)
    }

    // MARK: - Суммы поверх цен

    private var badges: some View {
        ForEach(model.prices) { price in
            if let converted = convert(price.value) {
                Button {
                    usePrice(price.value)
                } label: {
                    Text(verbatim: "≈ \(RateFormat.amount(converted)) \(to)")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.black.opacity(0.85))
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(Capsule().fill(Color.accentButton))
                        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                // Над ценой, чтобы её было видно.
                .position(x: price.bounds.midX, y: max(price.bounds.minY - 22, 60))
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: model.prices.map(\.id))
    }

    // MARK: - Панель валют

    private var currencyBar: some View {
        VStack(spacing: 12) {
            Text(L(.scanHint))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.5), radius: 4)
            HStack(spacing: 10) {
                currencyMenu(selection: $from)
                Button {
                    withAnimation(.smooth(duration: 0.25)) { swap(&from, &to) }
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(CardBubbleStyle())
                .accessibilityLabel(L(.swap))
                currencyMenu(selection: $to)
            }
        }
        .padding(.bottom, 24)
        .environment(\.colorScheme, .dark)
    }

    private func currencyMenu(selection: Binding<String>) -> some View {
        Menu {
            Picker(selection: selection) {
                ForEach(choices, id: \.self) { code in
                    Text(verbatim: "\(code) · \(Currency(code: code).name)").tag(code)
                }
            } label: { EmptyView() }
        } label: {
            HStack(spacing: 8) {
                CurrencyIcon(currency: Currency(code: selection.wrappedValue), size: 26)
                Text(verbatim: selection.wrappedValue)
                    .font(.headline)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.leading, 9)
            .padding(.trailing, 16)
            .frame(height: 44)
        }
        .buttonStyle(CardBubbleStyle())
    }

    // MARK: - Нет камеры

    private var unavailable: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color.secondaryLabel)
            Text(L(.scanUnavailable))
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                Text(L(.openSettings))
                    .fontWeight(.semibold)
                    .padding(.horizontal, 18)
                    .frame(height: 44)
            }
            .buttonStyle(CardBubbleStyle())
        }
        .padding(.horizontal, 32)
        .environment(\.colorScheme, .dark)
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(CardBubbleStyle())
        .environment(\.colorScheme, .dark)
        .accessibilityLabel(L(.close))
        .padding(.leading, 16)
        .padding(.top, 8)
    }

    // MARK: - Валюты

    /// Валюты списка и валюта страны, где вы сейчас.
    private var choices: [String] {
        var codes = store.selectedCodes
        if let local = store.currentCountryCurrency, !codes.contains(local) { codes.insert(local, at: 0) }
        return codes
    }

    /// В поездке цены — в местной валюте, пересчёт — в первую валюту списка (домашнюю).
    private func chooseDefaults() {
        guard from.isEmpty else { return }
        let home = store.selectedCodes.first ?? "USD"
        if let local = store.currentCountryCurrency, local != home {
            from = local
            to = home
        } else {
            from = home
            to = store.selectedCodes.first(where: { $0 != home }) ?? "USD"
        }
    }

    private func convert(_ value: Double) -> Double? {
        store.snapshot?.rate(from: from, to: to).map { $0 * value }
    }

    /// Цена переносится в главный список, если её валюта там есть.
    private func usePrice(_ value: Double) {
        guard store.selectedCodes.contains(from) else { return }
        store.sourceCode = from
        store.amountText = RateFormat.editable(value)
        dismiss()
    }
}

// MARK: - Распознавание

/// Цена в кадре: где она и сколько.
struct ScannedPrice: Identifiable, Equatable {
    let id: RecognizedItem.ID
    var bounds: CGRect
    var value: Double
}

@MainActor
@Observable
final class ScanModel {
    var prices: [ScannedPrice] = []

    func update(_ items: [RecognizedItem]) {
        prices = items.compactMap { item in
            guard case .text(let text) = item,
                  let value = PriceParser.value(in: text.transcript) else { return nil }
            let b = item.bounds
            let xs = [b.topLeft.x, b.topRight.x, b.bottomLeft.x, b.bottomRight.x]
            let ys = [b.topLeft.y, b.topRight.y, b.bottomLeft.y, b.bottomRight.y]
            let rect = CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
            return ScannedPrice(id: item.id, bounds: rect, value: value)
        }
    }
}

/// Камера VisionKit: ищет строки текста и сообщает о них модели.
private struct PriceCamera: UIViewControllerRepresentable {
    let model: ScanModel

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: false
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        // Запускать нужно, когда экран уже на месте.
        if !scanner.isScanning { try? scanner.startScanning() }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let model: ScanModel
        init(model: ScanModel) { self.model = model }

        func dataScanner(_ scanner: DataScannerViewController, didAdd added: [RecognizedItem], allItems: [RecognizedItem]) {
            model.update(allItems)
        }
        func dataScanner(_ scanner: DataScannerViewController, didUpdate updated: [RecognizedItem], allItems: [RecognizedItem]) {
            model.update(allItems)
        }
        func dataScanner(_ scanner: DataScannerViewController, didRemove removed: [RecognizedItem], allItems: [RecognizedItem]) {
            model.update(allItems)
        }
    }
}

/// Достаёт цену из распознанной строки: «12.99», «€ 1 234,50», «1,299.00 ₺», «120 THB».
/// Время, даты и телефоны (с «:», «/», длинные числа) пропускаются.
enum PriceParser {
    nonisolated(unsafe) private static let number = /\d{1,3}(?:[ .,'\u{00A0}\u{202F}]\d{3})*(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?/

    static func value(in text: String) -> Double? {
        guard !text.contains(":"), !text.contains("/") else { return nil }
        let digits = text.filter(\.isNumber)
        guard !digits.isEmpty, digits.count <= 9 else { return nil }
        guard let match = text.firstMatch(of: number) else { return nil }
        return parse(String(match.output))
    }

    static func parse(_ raw: String) -> Double? {
        var s = raw.filter { !" '\u{00A0}\u{202F}".contains($0) }
        let lastDot = s.lastIndex(of: "."), lastComma = s.lastIndex(of: ",")
        // Десятичный разделитель — последний «.» или «,», если после него 1–2 цифры.
        if let sep = [lastDot, lastComma].compactMap({ $0 }).max(),
           s.distance(from: sep, to: s.endIndex) - 1 <= 2 {
            let intPart = s[..<sep].filter(\.isNumber)
            let frac = s[s.index(after: sep)...]
            s = "\(intPart).\(frac)"
        } else {
            s = s.filter(\.isNumber)
        }
        guard let value = Double(s), value > 0 else { return nil }
        return value
    }
}
