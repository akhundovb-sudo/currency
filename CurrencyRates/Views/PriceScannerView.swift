import SwiftUI
import VisionKit

/// Сканер цен: камера распознаёт цены на ценниках и в меню прямо на устройстве
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

    /// Пересчитанная цена ложится прямо на исходную: плашка закрывает цифры на ценнике
    /// и по высоте подстраивается под них, как перевод текста в камере.
    private var badges: some View {
        ForEach(model.prices) { price in
            if let converted = convert(price) {
                let height = min(max(price.bounds.height * 1.15, 26), 64)
                Button {
                    usePrice(price)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: height * 0.12) {
                        Text(verbatim: RateFormat.amount(converted))
                            .font(.system(size: height * 0.62, weight: .bold, design: .rounded))
                        Text(verbatim: to)
                            .font(.system(size: height * 0.36, weight: .semibold, design: .rounded))
                            .opacity(0.7)
                    }
                    .monospacedDigit()
                    .foregroundStyle(Color.onAccent)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, height * 0.28)
                    .frame(minWidth: price.bounds.width, minHeight: height)
                    .background(
                        RoundedRectangle(cornerRadius: height * 0.3, style: .continuous)
                            .fill(Color.accentButton)
                            .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                    )
                }
                .buttonStyle(.plain)
                .position(x: price.bounds.midX, y: price.bounds.midY)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.18), value: model.prices)
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

    /// Выбор валюты — меню с валютами из списка приложения, в том же порядке.
    private func currencyMenu(selection: Binding<String>) -> some View {
        Menu {
            Picker(selection: selection) {
                ForEach(store.selectedCodes, id: \.self) { code in
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
            Image("icon-scan")
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
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

    /// Валюты только из списка приложения. По умолчанию — из местной валюты (если она в списке,
    /// иначе первая) в доллар; если доллара нет в списке или он уже выбран — в следующую по списку.
    private func chooseDefaults() {
        guard from.isEmpty else { return }
        let codes = store.selectedCodes
        let local = store.currentCountryCurrency ?? store.localCurrency
        from = local.flatMap { codes.contains($0) ? $0 : nil } ?? codes.first ?? "USD"
        to = (from != "USD" && codes.contains("USD") ? "USD" : nil)
            ?? codes.first(where: { $0 != from }) ?? from
    }

    /// Если рядом с ценой есть знак или код валюты (€, ₺, THB) — считаем из неё, иначе из выбранной.
    private func source(of price: ScannedPrice) -> String {
        if let code = price.currency, store.snapshot?.rate(from: code, to: to) != nil { return code }
        return from
    }

    private func convert(_ price: ScannedPrice) -> Double? {
        let source = source(of: price)
        guard source != to else { return nil }
        return store.snapshot?.rate(from: source, to: to).map { $0 * price.value }
    }

    /// Цена переносится в главный список, если её валюта там есть.
    private func usePrice(_ price: ScannedPrice) {
        let source = source(of: price)
        guard store.selectedCodes.contains(source) else { return }
        store.sourceCode = source
        store.amountText = RateFormat.editable(price.value)
        dismiss()
    }
}

// MARK: - Распознавание

/// Цена в кадре: где она, сколько и в какой валюте (если рядом есть знак или код).
struct ScannedPrice: Identifiable, Equatable {
    let id: RecognizedItem.ID
    var bounds: CGRect
    var value: Double
    var currency: String?
}

@MainActor
@Observable
final class ScanModel {
    /// Цены, которые уже подтвердились и показываются.
    var prices: [ScannedPrice] = []

    /// Кандидат: сколько кадров подряд распознаётся одно и то же значение.
    private struct Track {
        var value: Double
        var currency: String?
        var hits: Int
        var bounds: CGRect
    }
    @ObservationIgnored private var tracks: [RecognizedItem.ID: Track] = [:]

    /// Сколько кадров подряд цена должна совпасть, прежде чем появиться: без этого плашки
    /// мигали на случайных числах и прыгали, пока камера дочитывает цифры.
    private static let confirmations = 3

    func update(_ items: [RecognizedItem]) {
        var next: [RecognizedItem.ID: Track] = [:]
        for item in items {
            guard case .text(let text) = item,
                  let found = PriceParser.price(in: text.transcript) else { continue }
            let rect = Self.rect(of: found, in: item.bounds)
            if var track = tracks[item.id], track.value == found.value {
                track.hits += 1
                track.currency = found.currency ?? track.currency
                // Сглаживание: плашка плавно следует за ценой, а не дёргается за каждым кадром.
                track.bounds = Self.blend(track.bounds, rect, 0.35)
                next[item.id] = track
            } else {
                next[item.id] = Track(value: found.value, currency: found.currency, hits: 1, bounds: rect)
            }
        }
        tracks = next
        prices = next.compactMap { id, track in
            track.hits >= Self.confirmations
                ? ScannedPrice(id: id, bounds: track.bounds, value: track.value, currency: track.currency)
                : nil
        }
        .sorted { $0.bounds.minY < $1.bounds.minY }
    }

    /// Где в строке само число: доля длины текста до него и его длина — вдоль строки.
    private static func rect(of found: PriceParser.Found, in b: RecognizedItem.Bounds) -> CGRect {
        func lerp(_ p: CGPoint, _ q: CGPoint, _ t: CGFloat) -> CGPoint {
            CGPoint(x: p.x + (q.x - p.x) * t, y: p.y + (q.y - p.y) * t)
        }
        let points = [
            lerp(b.topLeft, b.topRight, found.start), lerp(b.topLeft, b.topRight, found.end),
            lerp(b.bottomLeft, b.bottomRight, found.start), lerp(b.bottomLeft, b.bottomRight, found.end),
        ]
        let xs = points.map(\.x), ys = points.map(\.y)
        return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }

    private static func blend(_ a: CGRect, _ b: CGRect, _ t: CGFloat) -> CGRect {
        CGRect(x: a.minX + (b.minX - a.minX) * t, y: a.minY + (b.minY - a.minY) * t,
               width: a.width + (b.width - a.width) * t, height: a.height + (b.height - a.height) * t)
    }
}

/// Камера VisionKit: ищет строки текста и сообщает о них модели.
private struct PriceCamera: UIViewControllerRepresentable {
    let model: ScanModel

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            // Точнее: цифры на ценниках мелкие, а «8» и «3», «,» и «.» путаются.
            qualityLevel: .accurate,
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
