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

    /// Валюты Pro, отключённые после окончания подписки. Хранятся, чтобы вернуть их
    /// в список, когда Pro снова появится.
    private(set) var suspendedCodes: [String] {
        didSet { defaults?.set(suspendedCodes, forKey: Keys.suspendedCodes) }
    }

    /// Сумма в том виде, как её ввёл пользователь.
    var amountText: String {
        didSet { defaults?.set(amountText, forKey: Keys.amountText) }
    }

    /// В поле лежит пересчитанная сумма (после выбора валюты), а не набранная вручную:
    /// первая цифра заменяет её целиком, как в калькуляторе. Иначе у длинной суммы
    /// (например, 402 миллиарда) цифры упирались в лимит и «не нажимались».
    private(set) var replacesOnNextInput = false

    var theme: AppTheme {
        didSet { defaults?.set(theme.rawValue, forKey: Keys.theme) }
    }

    /// Язык интерфейса.
    var language: AppLanguage {
        didSet {
            L10n.current = language
            defaults?.set(language.rawValue, forKey: Keys.language)
            // Формат «по языку»: набранная сумма переходит на разделитель нового языка.
            // Иначе «12.5» после смены en → ru выглядело как «1 2.5», а запятая ломала сумму.
            if numberStyle == .automatic {
                let old = oldValue.locale.decimalSeparator ?? "."
                let new = Calculator.decimalSeparator
                if old != new { amountText = amountText.replacingOccurrences(of: old, with: new) }
            }
        }
    }

    /// Формат чисел. Набранная сумма переводится на новый разделитель дробной части.
    var numberStyle: NumberStyle {
        didSet {
            let old = oldValue.locale.decimalSeparator ?? "."
            RateFormat.style = numberStyle
            let new = Calculator.decimalSeparator
            if old != new { amountText = amountText.replacingOccurrences(of: old, with: new) }
            defaults?.set(numberStyle.rawValue, forKey: Keys.numberStyle)
        }
    }

    /// Знаков после запятой в суммах; nil — автоматически.
    static let defaultDecimalPlaces = 2

    var decimalPlaces: Int? {
        didSet {
            RateFormat.decimalPlaces = decimalPlaces
            defaults?.set(decimalPlaces ?? -1, forKey: Keys.decimalPlaces)
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

        let local = defaults?.string(forKey: Keys.localCurrency)
        self.localCurrency = local
        self.currentCountry = defaults?.string(forKey: Keys.currentCountry)
        self.currentCountryCurrency = defaults?.string(forKey: Keys.currentCountryCurrency)
        let starting = Self.startingCodes(local: local)
        self.sourceCode = sourceCode ?? defaults?.string(forKey: Keys.sourceCode) ?? starting[0]
        self.selectedCodes = selectedCodes
            ?? defaults?.stringArray(forKey: Keys.selectedCodes)
            ?? starting
        self.amountText = amountText ?? defaults?.string(forKey: Keys.amountText) ?? ""
        self.suspendedCodes = defaults?.stringArray(forKey: Keys.suspendedCodes) ?? []
        self.theme = defaults?.string(forKey: Keys.theme).flatMap(AppTheme.init(rawValue:)) ?? .system
        let language = defaults?.string(forKey: Keys.language).flatMap(AppLanguage.init(rawValue:)) ?? .systemDefault
        self.language = language
        let pro = defaults?.bool(forKey: Keys.isPro) ?? false
        self.isPro = pro
        // Pro, включённый переключателем для проверки, без тарифа — показываем как годовой.
        self.proPlan = defaults?.string(forKey: Keys.proPlan).flatMap(ProPlan.init(rawValue:)) ?? (pro ? .yearly : nil)
        let style = defaults?.string(forKey: Keys.numberStyle).flatMap(NumberStyle.init(rawValue:)) ?? .automatic
        self.numberStyle = style
        RateFormat.style = style
        // По умолчанию — 2 знака после запятой; −1 в настройках означает «Авто».
        let savedPlaces = defaults?.object(forKey: Keys.decimalPlaces) as? Int ?? Self.defaultDecimalPlaces
        let places: Int? = savedPlaces >= 0 ? savedPlaces : nil
        self.decimalPlaces = places
        RateFormat.decimalPlaces = places
        L10n.current = language
        self.snapshot = snapshot ?? Self.loadCache(from: cacheURL)
        // В списке всегда минимум две валюты, иначе сравнивать нечего.
        for code in starting where self.selectedCodes.count < Self.minimumCount {
            if !self.selectedCodes.contains(code) { self.selectedCodes.append(code) }
        }
        applyPlanLimits()
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
    /// Может быть отрицательной («5 − 10») — тогда и остальные суммы с минусом.
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
        replacesOnNextInput = !amountText.isEmpty
    }

    /// Нажатие клавиши: цифры, запятая, стирание, действия калькулятора и «=».
    /// Сколько символов помещается в строку ввода на карточке.
    static let maxAmountLength = 15

    /// Нажатие клавиши. Возвращает `false`, если ввод не принят (сумма не помещается).
    @discardableResult
    func press(_ key: KeypadKey) -> Bool {
        var text = amountText
        // Цифра или запятая сразу после выбора валюты начинают ввод заново.
        if replacesOnNextInput {
            replacesOnNextInput = false
            switch key {
            case .digit, .decimal: text = ""
            default: break
            }
        }
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
        // Лимит длины — только для ввода: стирать длинную сумму можно всегда.
        guard text.count <= Self.maxAmountLength || text.count < amountText.count else { return false }
        amountText = text
        return true
    }

    // MARK: - Список валют

    func contains(_ code: String) -> Bool {
        selectedCodes.contains(code)
    }

    /// Сколько валют можно держать в списке без подписки: USD и EUR плюс ещё две.
    static let freeLimit = 4

    /// Сколько валют по алфавиту (кроме USD и EUR) доступны без подписки.
    static let freeChoiceCount = 3

    /// Подписка Pro снимает ограничения. Покупки пока не подключены —
    /// для проверки флаг переключается в настройках.
    var isPro: Bool {
        didSet {
            defaults?.set(isPro, forKey: Keys.isPro)
            if !isPro { proPlan = nil } else if proPlan == nil { proPlan = .yearly }
            applyPlanLimits()
        }
    }

    /// Какой тариф Pro куплен — показывается в настройках. `nil` — Pro включён переключателем для проверки.
    var proPlan: ProPlan? {
        didSet { defaults?.set(proPlan?.rawValue, forKey: Keys.proPlan) }
    }

    /// Фиатные валюты, доступные для выбора: из загруженных курсов или стандартный список.
    var fiatCodes: [String] {
        let codes = snapshot?.fiat.map { Array($0.rates.keys) } ?? Locale.commonISOCurrencyCodes
        return codes.filter { CryptoAsset.byCode[$0] == nil }.sorted()
    }

    /// Бесплатные валюты: USD, EUR и первые три остальных по алфавиту.
    var freeCodes: Set<String> {
        let starting = Self.startingCodes(local: localCurrency)
        let first = fiatCodes.filter { !starting.contains($0) }.prefix(Self.freeChoiceCount)
        return Set(starting).union(first)
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

    /// Удалить можно любую валюту, пока в списке остаётся минимум две.
    func canDelete(_ code: String) -> Bool {
        canRemove
    }

    /// Приводит список к текущему плану.
    /// Без Pro: валюты, недоступные бесплатно, и всё сверх лимита отключаются —
    /// уходят из списка в `suspendedCodes`. С Pro: отключённые возвращаются на место.
    private func applyPlanLimits() {
        if isPro {
            guard !suspendedCodes.isEmpty else { return }
            selectedCodes += suspendedCodes.filter { !selectedCodes.contains($0) }
            suspendedCodes = []
            return
        }
        let free = freeCodes
        var kept: [String] = []
        var dropped: [String] = []
        for code in selectedCodes {
            if free.contains(code) && kept.count < Self.freeLimit {
                kept.append(code)
            } else {
                dropped.append(code)
            }
        }
        guard !dropped.isEmpty else { return }
        // Минимум две валюты: если бесплатных не хватило — добавляем стартовые.
        for code in Self.startingCodes(local: localCurrency) where kept.count < Self.minimumCount && !kept.contains(code) {
            kept.append(code)
        }
        // Если отключается валюта ввода — ввод переходит на первую оставшуюся с тем же эквивалентом.
        if dropped.contains(sourceCode), let next = kept.first {
            beginEditing(next)
        }
        suspendedCodes += dropped.filter { !suspendedCodes.contains($0) }
        selectedCodes = kept
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
        guard !removed.isEmpty else { return }
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
        static let suspendedCodes = "suspendedCodes"
        static let sourceCode = "sourceCode"
        static let amountText = "amountText"
        static let theme = "theme"
        static let language = "language"
        static let isPro = "isPro"
        static let proPlan = "proPlan"
        static let numberStyle = "numberStyle"
        static let decimalPlaces = "decimalPlaces"
        static let localCurrency = "localCurrency"
        static let currentCountry = "currentCountry"
        static let currentCountryCurrency = "currentCountryCurrency"
    }

    /// Стартовые валюты: местная (по геолокации) и доллар; если местную не определили
    /// или это сам доллар — доллар и евро.
    static func startingCodes(local: String?) -> [String] {
        if let local, local != "USD" { return [local, "USD"] }
        return ["USD", "EUR"]
    }

    /// Местная валюта, определённая по геолокации; входит в бесплатные.
    private(set) var localCurrency: String? {
        didSet { defaults?.set(localCurrency, forKey: Keys.localCurrency) }
    }

    /// Страна, где пользователь сейчас (по последнему определению геолокации), и её валюта —
    /// для виджета «Путешествие».
    private(set) var currentCountry: String? {
        didSet { defaults?.set(currentCountry, forKey: Keys.currentCountry) }
    }

    private(set) var currentCountryCurrency: String? {
        didSet { defaults?.set(currentCountryCurrency, forKey: Keys.currentCountryCurrency) }
    }

    func updateCurrentCountry(_ country: String, currency: String) {
        guard CryptoAsset.byCode[currency] == nil else { return }
        currentCountry = country
        currentCountryCurrency = currency
    }

    /// Местная валюта определена (один раз). Если список ещё стартовый (USD и EUR) —
    /// первой становится местная валюта, второй — доллар.
    func applyLocalCurrency(_ code: String) {
        guard localCurrency == nil, CryptoAsset.byCode[code] == nil,
              Locale.commonISOCurrencyCodes.contains(code) else { return }
        localCurrency = code
        let fallback = Self.startingCodes(local: nil)
        guard code != "USD", selectedCodes == fallback else { return }
        selectedCodes = Self.startingCodes(local: code)
        sourceCode = code
        amountText = ""
    }

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

/// Тарифы Pro.
enum ProPlan: String, CaseIterable, Identifiable {
    case monthly, yearly, lifetime
    var id: Self { self }

    var title: String {
        switch self {
        case .monthly: L(.planMonthly)
        case .yearly: L(.planYearly)
        case .lifetime: L(.planLifetime)
        }
    }

    /// У подписок 7 дней бесплатно, у покупки навсегда пробного периода нет.
    var hasTrial: Bool { self != .lifetime }

    var isSubscription: Bool { self != .lifetime }

    /// Цены-заглушки, пока не подключён StoreKit: реальные придут из App Store.
    /// Год — почти в 2,5 раза дешевле помесячной оплаты, навсегда — как два года.
    var price: String {
        switch self {
        case .monthly: L(.perMonth, "$1.99")
        case .yearly: L(.perYear, "$9.99")
        case .lifetime: L(.oneTime, "$19.99")
        }
    }
}

/// Внешние ссылки приложения.
enum AppLinks {
    /// Стандартное лицензионное соглашение Apple — подходит, пока нет своих условий.
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// TODO: заменить на страницу своей политики конфиденциальности.
    static let privacy = URL(string: "https://www.apple.com/legal/privacy/")!
    /// Одна страница с условиями и политикой конфиденциальности (строка в настройках).
    /// TODO: заменить на свою страницу, где есть оба документа.
    static let legal = URL(string: "https://www.apple.com/legal/privacy/")!
    /// Управление подписками в App Store.
    static let manageSubscriptions = URL(string: "https://apps.apple.com/account/subscriptions")!
}
