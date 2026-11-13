import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Действие «Пересчитать в Cento» в меню «Поделиться»: выделенный текст с ценой (из Safari,
/// Заметок, почты…) сразу пересчитывается во все валюты списка Cento — поверх текущего приложения.
/// Курсы и список валют — из общего контейнера App Group, который заполняет приложение; сеть не нужна.
final class ActionViewController: UIViewController {
    private let model = ActionModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: ActionView(model: model) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        })
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)

        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        Task { @MainActor in
            model.load(text: await Self.text(from: items))
        }
    }

    /// Текст из того, чем поделились: выделение на странице Safari (через Action.js),
    /// обычный текст или подпись к элементу.
    private static func text(from items: [NSExtensionItem]) async -> String {
        var parts: [String] = []
        for item in items {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier),
                   let dict = await load(provider, UTType.propertyList) as? [String: Any],
                   let results = dict[NSExtensionJavaScriptPreprocessingResultsKey] as? [String: Any],
                   let selection = results["selection"] as? String, !selection.isEmpty {
                    parts.append(selection)
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                          let text = await load(provider, UTType.plainText) as? String {
                    parts.append(text)
                }
            }
            if parts.isEmpty, let text = item.attributedContentText?.string, !text.isEmpty {
                parts.append(text)
            }
        }
        return parts.joined(separator: "\n")
    }

    private static func load(_ provider: NSItemProvider, _ type: UTType) async -> NSSecureCoding? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { item, _ in
                continuation.resume(returning: item)
            }
        }
    }
}

// MARK: - Данные

/// Цены из текста, выбранная цена и её валюта, курсы и валюты из приложения.
@MainActor
final class ActionModel: ObservableObject {
    struct Price: Hashable {
        let value: Double
        let currency: String?
    }

    @Published var prices: [Price] = []
    @Published var selected = 0
    @Published var source = "USD"
    @Published var isLoaded = false

    let rates = SharedRates.load()
    let app = WidgetSnapshot.load()

    var numberLocale: Locale { app?.numberLocale ?? .current }
    var language: Locale { app?.language ?? .current }

    /// Валюты пересчёта — список приложения, без исходной.
    var targets: [String] {
        let codes = app?.codes ?? ["USD", "EUR"]
        return codes.filter { $0 != source }
    }

    /// Из чего можно пересчитывать: валюта из текста, местная, валюты списка, затем весь фиат.
    var sources: [String] {
        var codes: [String] = []
        for code in [prices[safe: selected]?.currency, app?.countryCurrency].compactMap({ $0 }) + (app?.codes ?? [])
        where !codes.contains(code) {
            codes.append(code)
        }
        let fiat = (rates?.fiat.keys).map(Array.init)?.sorted() ?? []
        return codes + fiat.filter { !codes.contains($0) && !CurrencyCatalog.isCrypto($0) }
    }

    func load(text: String) {
        var found: [Price] = []
        for line in text.split(whereSeparator: \.isNewline).prefix(40) {
            guard let price = PriceParser.price(in: String(line)) else { continue }
            // «$» у многих стран, но в тексте из сети это почти всегда доллар.
            let currency = price.currency ?? (line.contains("$") ? "USD" : nil)
            let item = Price(value: price.value, currency: currency)
            if !found.contains(item) { found.append(item) }
            if found.count == 6 { break }
        }
        prices = found
        select(0)
        isLoaded = true
    }

    func select(_ index: Int) {
        selected = index
        source = prices[safe: index]?.currency ?? app?.countryCurrency ?? app?.sourceCode ?? "USD"
    }

    func convert(_ value: Double, to code: String) -> Double? {
        rates?.rate(from: source, to: code).map { $0 * value }
    }

    func format(_ value: Double) -> String {
        AmountFormat.amount(value, locale: numberLocale, decimalPlaces: app?.decimalPlaces)
    }

    func name(_ code: String) -> String {
        CurrencyCatalog.name(for: code, locale: language)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

// MARK: - Экран

struct ActionView: View {
    @ObservedObject var model: ActionModel
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !model.isLoaded {
                        ProgressView().padding(.top, 60)
                    } else if model.rates == nil {
                        message("Open Cento once to load exchange rates.")
                    } else if model.prices.isEmpty {
                        message("No price found. Select a price on the page, then tap Share and Convert in Cento.")
                    } else {
                        if model.prices.count > 1 { priceChips }
                        sourceCard
                        conversions
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(Text(verbatim: "Cento"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: onDone) {
                        Text("Done")
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 16)
                            .frame(height: 36)
                            .foregroundStyle(ActionColor.onAccent)
                            .background(Capsule().fill(ActionColor.accent.gradient))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Несколько цен в выделении — переключатель между ними.
    private var priceChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Array(model.prices.enumerated()), id: \.offset) { index, price in
                    Button {
                        withAnimation(.smooth(duration: 0.2)) { model.select(index) }
                    } label: {
                        Text(verbatim: [price.currency, model.format(price.value)].compactMap { $0 }.joined(separator: " "))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .foregroundStyle(index == model.selected ? ActionColor.onAccent : Color.primary)
                            .background(Capsule().fill(index == model.selected ? ActionColor.accent : Color(.secondarySystemGroupedBackground)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    /// Найденная цена и её валюта; валюту можно сменить.
    private var sourceCard: some View {
        let price = model.prices[model.selected]
        return HStack(spacing: 12) {
            Menu {
                Picker(selection: $model.source) {
                    ForEach(model.sources, id: \.self) { code in
                        Text(verbatim: "\(code) · \(model.name(code))").tag(code)
                    }
                } label: { EmptyView() }
            } label: {
                HStack(spacing: 8) {
                    CurrencyFlag(code: model.source, size: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text(verbatim: model.source).font(.headline)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        Text(verbatim: model.name(model.source))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer(minLength: 8)
            Text(verbatim: model.format(price.value))
                .font(.system(.title, design: .rounded).weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    /// Та же цена во всех валютах списка.
    private var conversions: some View {
        let price = model.prices[model.selected]
        return VStack(spacing: 0) {
            ForEach(Array(model.targets.enumerated()), id: \.element) { index, code in
                if index > 0 { Divider().padding(.leading, 64) }
                HStack(spacing: 12) {
                    CurrencyFlag(code: code, size: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: code).font(.headline)
                        Text(verbatim: model.name(code))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Text(verbatim: model.convert(price.value, to: code).map(model.format) ?? "—")
                        .font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func message(_ text: LocalizedStringKey) -> some View {
        VStack(spacing: 16) {
            ScanMark(size: 64)
            Text(text)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 48)
        .padding(.horizontal, 16)
    }
}

/// Цвета акцентных кнопок приложения: лаванда и сливовый текст на ней.
enum ActionColor {
    static let accent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xE9 / 255, green: 0xB3 / 255, blue: 0xFB / 255, alpha: 1)
            : UIColor(red: 0xDA / 255, green: 0x9C / 255, blue: 0xF6 / 255, alpha: 1)
    })
    static let onAccent = Color(red: 0x4A / 255, green: 0x05 / 255, blue: 0x30 / 255)
}

/// Флаг валюты (или значок монеты) кружком, как в приложении.
struct CurrencyFlag: View {
    let code: String
    let size: CGFloat

    var body: some View {
        Group {
            if let name = CurrencyCatalog.imageName(for: code), UIImage(named: name) != nil {
                Image(name).resizable().scaledToFit()
            } else {
                ZStack {
                    Circle().fill(Color.blue.gradient)
                    Image(systemName: CurrencyCatalog.isCrypto(code) ? "bitcoinsign" : "globe")
                        .font(.system(size: size * 0.5, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.75))
    }
}
