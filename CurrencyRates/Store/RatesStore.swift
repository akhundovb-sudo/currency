import Foundation
import Observation

/// Состояние приложения: выбранные валюты, введённая сумма, настройки и последние курсы.
@MainActor
@Observable
final class RatesStore {
    /// Валюты в списке, в порядке пользователя.
    var selectedCodes: [String] {
        didSet { defaults?.set(selectedCodes, forKey: Keys.selectedCodes) }
    }

    /// Валюта, в которой вводится сумма.
    var sourceCode: String {
        didSet { defaults?.set(sourceCode, forKey: Keys.sourceCode) }
    }

    /// Сумма в том виде, как её ввёл пользователь.
    var amountText: String {
        didSet { defaults?.set(amountText, forKey: Keys.amountText) }
    }

    var theme: AppTheme {
        didSet { defaults?.set(theme.rawValue, forKey: Keys.theme) }
    }

    /// Язык интерфейса.
    var language: AppLanguage {
        didSet {
            L10n.current = language
            defaults?.set(language.rawValue, forKey: Keys.language)
        }
    }

    private(set) var snapshot: RatesSnapshot?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    /// Наборы курсов, успешно загруженные в этом запуске; остальные — из кэша.
    private(set) var freshKinds: Set<CurrencyKind> = []

    private let service: RatesService?
    private let defaults: UserDefaults?
    private let cacheURL: URL?
    private var loadTask: Task<Void, Never>?

    init(
        service: RatesService?,
        defaults: UserDefaults?,
        cacheURL: URL?,
        selectedCodes: [String]? = nil,
        sourceCode: String? = nil,
        amountText: String? = nil,
        snapshot: RatesSnapshot? = nil
    ) {
        self.service = service
        self.defaults = defaults
        self.cacheURL = cacheURL

        self.sourceCode = sourceCode ?? defaults?.string(forKey: Keys.sourceCode) ?? "USD"
        self.selectedCodes = selectedCodes
            ?? defaults?.stringArray(forKey: Keys.selectedCodes)
            ?? Self.defaultSelection
        self.amountText = amountText ?? defaults?.string(forKey: Keys.amountText) ?? ""
        self.theme = defaults?.string(forKey: Keys.theme).flatMap(AppTheme.init(rawValue:)) ?? .system
        let language = defaults?.string(forKey: Keys.language).flatMap(AppLanguage.init(rawValue:)) ?? .systemDefault
        self.language = language
        L10n.current = language
        self.snapshot = snapshot ?? Self.loadCache(from: cacheURL)
        // В списке всегда минимум две валюты, иначе сравнивать нечего.
        for code in Self.defaultSelection where self.selectedCodes.count < Self.minimumCount {
            if !self.selectedCodes.contains(code) { self.selectedCodes.append(code) }
        }
        // Валюта ввода всегда одна из строк списка.
        if !self.selectedCodes.contains(self.sourceCode), let first = self.selectedCodes.first {
            self.sourceCode = first
            self.amountText = ""
        }
        if snapshot?.isDemo == true {
            freshKinds = Set(CurrencyKind.allCases)
        }
    }

    static func live() -> RatesStore {
        let directory = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return RatesStore(
            service: RatesService(),
            defaults: .standard,
            cacheURL: directory.appending(path: "rates-cache-v2.json")
        )
    }

    // MARK: - Сумма и пересчёт

    /// Введённая сумма: результат выражения в строке ввода; пустое поле означает 1.
    var amount: Double {
        Calculator.evaluate(amountText) ?? 1
    }

    /// Сколько единиц `code` стоит 1 единица исходной валюты.
    func unitRate(to code: String) -> Double? {
        snapshot?.rate(from: sourceCode, to: code)
    }

    /// Введённая сумма, пересчитанная в `code`.
    func convertedAmount(to code: String) -> Double? {
        unitRate(to: code).map { $0 * amount }
    }

    /// Делает `code` валютой ввода, сохраняя сравниваемую сумму:
    /// в поле окажется уже пересчитанное значение этой валюты.
    func beginEditing(_ code: String) {
        guard code != sourceCode else { return }
        let value = convertedAmount(to: code)
        sourceCode = code
        amountText = value.map(RateFormat.editable) ?? ""
    }

    /// Нажатие клавиши: цифры, запятая, стирание, действия калькулятора и «=».
    /// Сколько символов помещается в строку ввода на карточке.
    static let maxAmountLength = 15

    /// Нажатие клавиши. Возвращает `false`, если ввод не принят (сумма не помещается).
    @discardableResult
    func press(_ key: KeypadKey) -> Bool {
        var text = amountText
        let lastNumber = Calculator.lastNumber(in: text)
        let endsWithOperator = text.last.map(Calculator.operators.contains) ?? false

        switch key {
        case .digit(let digit):
            guard lastNumber.filter(\.isNumber).count < 12 else { return false }
            if lastNumber == "0" { text.removeLast() }
            text.append(String(digit))
        case .decimal:
            let separator = Calculator.decimalSeparator
            guard !lastNumber.contains(separator) else { return true }
            text += lastNumber.isEmpty ? "0" + separator : separator
        case .backspace:
            if !text.isEmpty { text.removeLast() }
        case .add, .subtract, .multiply, .divide:
            if text.isEmpty { text = RateFormat.editable(amount) }
            if endsWithOperator || text.hasSuffix(Calculator.decimalSeparator) { text.removeLast() }
            text.append(Calculator.symbol(for: key))
        case .equals:
            if let value = Calculator.evaluate(text) { text = RateFormat.editable(value) }
        case .hide:
            return true
        }
        guard text.count <= Self.maxAmountLength else { return false }
        amountText = text
        return true
    }

    // MARK: - Список валют

    func contains(_ code: String) -> Bool {
        selectedCodes.contains(code)
    }

    /// Сколько валют можно держать в списке без подписки: USD и EUR плюс ещё три.
    static let freeLimit = 5

    /// Подписка Pro снимает ограничения. Покупки пока не подключены.
    var isPro = false

    /// Фиатные валюты, доступные для выбора: из загруженных курсов или стандартный список.
    var fiatCodes: [String] {
        let codes = snapshot?.fiat.map { Array($0.rates.keys) } ?? Locale.commonISOCurrencyCodes
        return codes.filter { CryptoAsset.byCode[$0] == nil }.sorted()
    }

    /// Бесплатные валюты: USD, EUR и первые пять остальных по алфавиту.
    var freeCodes: Set<String> {
        let first = fiatCodes.filter { !Self.defaultSelection.contains($0) }.prefix(5)
        return Set(Self.defaultSelection).union(first)
    }

    /// Можно ли добавить валюту без подписки: только из бесплатных и в пределах лимита.
    /// Остальной фиат и вся крипта — только с Pro.
    func canAdd(_ code: String) -> Bool {
        if isPro { return true }
        return freeCodes.contains(code) && selectedCodes.count < Self.freeLimit
    }

    func add(_ code: String) {
        guard !contains(code), canAdd(code) else { return }
        if selectedCodes.isEmpty {
            sourceCode = code
            amountText = ""
        }
        selectedCodes.append(code)
    }

    /// Меньше двух валют оставить нельзя.
    static let minimumCount = 2

    var canRemove: Bool {
        selectedCodes.count > Self.minimumCount
    }

    func remove(_ code: String) {
        remove(codes: [code])
    }

    func remove(atOffsets offsets: IndexSet) {
        remove(codes: offsets.map { selectedCodes[$0] })
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        selectedCodes.move(fromOffsets: source, toOffset: destination)
    }

    /// Если удаляется валюта ввода, ввод переходит к первой оставшейся с тем же эквивалентом.
    private func remove(codes: [String]) {
        let removed = Set(codes)
        let remaining = selectedCodes.filter { !removed.contains($0) }
        guard remaining.count >= Self.minimumCount else { return }
        if removed.contains(sourceCode), let next = remaining.first {
            beginEditing(next)
        }
        selectedCodes = remaining
    }

    // MARK: - Загрузка курсов

    func isShowingCachedData(_ kind: CurrencyKind) -> Bool {
        snapshot?.rateSet(for: kind) != nil && !freshKinds.contains(kind)
    }

    func refresh() async {
        if let loadTask {
            await loadTask.value
            return
        }
        // Отдельная задача, чтобы отмена жеста refreshable не прерывала запрос.
        let task = Task { await performLoad() }
        loadTask = task
        await task.value
        loadTask = nil
    }

    /// Обновляет курсы при возврате в приложение, если данные устарели.
    func refreshIfStale() async {
        let lastFetch = [snapshot?.fiat?.fetchedAt, snapshot?.crypto?.fetchedAt].compactMap { $0 }.min()
        let isStale = lastFetch.map { Date.now.timeIntervalSince($0) > 10 * 60 } ?? true
        if isStale || freshKinds.count < CurrencyKind.allCases.count {
            await refresh()
        }
    }

    private func performLoad() async {
        guard let service else { return }
        isLoading = true
        defer { isLoading = false }

        async let fiatResult = Self.capture { try await service.fetchFiat() }
        async let cryptoResult = Self.capture { try await service.fetchCrypto() }
        let (fiat, crypto) = await (fiatResult, cryptoResult)

        var updated = snapshot ?? RatesSnapshot()
        var problems: [String] = []

        switch fiat {
        case .success(let set):
            updated.fiat = set
            freshKinds.insert(.fiat)
        case .failure(let error):
            if Self.isCancellation(error) { return }
            problems.append("\(L(.fiatShort)): \(Self.message(for: error))")
        }

        switch crypto {
        case .success(let set):
            updated.crypto = set
            freshKinds.insert(.crypto)
        case .failure(let error):
            if Self.isCancellation(error) { return }
            problems.append("\(L(.cryptoShort)): \(Self.message(for: error))")
        }

        snapshot = updated
        errorMessage = problems.isEmpty ? nil : problems.joined(separator: "\n")
        saveCache(updated)
    }

    private static func capture<T: Sendable>(
        _ operation: @Sendable () async throws -> T
    ) async -> Result<T, Error> {
        do { return .success(try await operation()) } catch { return .failure(error) }
    }

    // MARK: - Кэш

    private func saveCache(_ snapshot: RatesSnapshot) {
        guard let cacheURL, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    private static func loadCache(from url: URL?) -> RatesSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(RatesSnapshot.self, from: data)
    }

    // MARK: - Вспомогательное

    private enum Keys {
        static let selectedCodes = "selectedCodes"
        static let sourceCode = "sourceCode"
        static let amountText = "amountText"
        static let theme = "theme"
        static let language = "language"
    }

    /// При первом запуске в списке только доллар и евро.
    private static let defaultSelection = ["USD", "EUR"]

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    private static func message(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return L(.errNoInternet)
            case .timedOut:
                return L(.errTimeout)
            default:
                return L(.errServer)
            }
        }
        if case RatesServiceError.rateLimited = error {
            return L(.errRateLimited)
        }
        return L(.errBadResponse)
    }
}
