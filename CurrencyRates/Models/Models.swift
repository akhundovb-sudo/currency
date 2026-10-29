import Foundation

/// Кэш названий валют по языкам: `Locale` каждый раз заново ищет их в данных ICU.
private enum NameCache {
    nonisolated(unsafe) static var names: [AppLanguage: [String: String]] = [:]
    nonisolated(unsafe) static var english: [String: String] = [:]
    static let englishLocale = Locale(identifier: "en_US")
}

enum CurrencyKind: String, CaseIterable, Identifiable, Sendable {
    case fiat, crypto

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fiat: L(.fiatShort)
        case .crypto: L(.cryptoShort)
        }
    }
}

/// Валюта: фиатная (код ISO 4217) или криптовалюта из `CryptoAsset.all`.
struct Currency: Identifiable, Hashable, Sendable {
    let code: String

    var id: String { code }
    var name: String { Currency.name(for: code) }
    var kind: CurrencyKind { CryptoAsset.byCode[code] == nil ? .fiat : .crypto }

    /// Локаль выбранного языка: названия валют, числа и даты.
    static var locale: Locale { L10n.current.locale }

    /// Название валюты на языке приложения, с заглавной буквы.
    /// Названия кэшируются: при смене языка весь список строится заново.
    static func name(for code: String) -> String {
        let language = L10n.current
        if let cached = NameCache.names[language]?[code] { return cached }
        let name: String
        if L10n.current == .ru, let ru = ["BTC": "Биткоин", "ETH": "Эфириум"][code] {
            name = ru
        } else {
            name = CurrencyCatalog.name(for: code, locale: locale)
        }
        NameCache.names[language, default: [:]][code] = name
        return name
    }

    /// Английское название — поиск по нему работает на любом языке приложения.
    static func englishName(for code: String) -> String {
        if let cached = NameCache.english[code] { return cached }
        let name = CurrencyCatalog.name(for: code, locale: NameCache.englishLocale)
        NameCache.english[code] = name
        return name
    }

    /// Код страны (или «EU») для флага валюты, если его можно определить по коду ISO 4217.
    var flagRegion: String? { CurrencyCatalog.flagRegion(for: code) }

    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return code.localizedStandardContains(query)
            || name.localizedStandardContains(query)
            || Currency.englishName(for: code).localizedStandardContains(query)
    }
}

/// Последние известные курсы фиатных валют и криптовалют.
struct RatesSnapshot: Codable, Equatable, Sendable {
    var fiat: RateSet?
    var crypto: RateSet?
    /// `true` только для данных из SwiftUI Preview — не реальные курсы.
    var isDemo = false

    func rateSet(for kind: CurrencyKind) -> RateSet? {
        switch kind {
        case .fiat: fiat
        case .crypto: crypto
        }
    }

    /// Сколько единиц `code` стоит 1 USD.
    private func unitsPerUSD(_ code: String) -> Double? {
        rateSet(for: Currency(code: code).kind)?.rates[code]
    }

    /// Сколько единиц `target` стоит 1 единица `source`.
    func rate(from source: String, to target: String) -> Double? {
        guard let sourceRate = unitsPerUSD(source), let targetRate = unitsPerUSD(target), sourceRate > 0 else {
            return nil
        }
        return targetRate / sourceRate
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: L(.themeSystem)
        case .light: L(.themeLight)
        case .dark: L(.themeDark)
        }
    }
}

/// Как показывать числа: разделители разрядов и дробной части.
enum NumberStyle: String, CaseIterable, Identifiable, Sendable {
    /// По языку интерфейса.
    case automatic
    /// 1,234.56
    case international
    /// 1.234,56
    case european
    /// 1 234,56
    case spaced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: L(.formatAutomatic)
        case .international: L(.formatInternational)
        case .european: L(.formatEuropean)
        case .spaced: L(.formatSpaced)
        }
    }

    var locale: Locale {
        switch self {
        case .automatic: Currency.locale
        case .international: Locale(identifier: "en_US")
        case .european: Locale(identifier: "de_DE")
        case .spaced: Locale(identifier: "fr_FR")
        }
    }
}

enum RateFormat {
    /// Выбранный в настройках формат чисел и число знаков после запятой (nil — автоматически).
    /// Задаёт `RatesStore`.
    nonisolated(unsafe) static var style: NumberStyle = .automatic
    nonisolated(unsafe) static var decimalPlaces: Int?

    static var locale: Locale { style.locale }

    /// Курс: больше знаков, чтобы были видны мелкие изменения.
    static func rate(_ value: Double) -> String {
        AmountFormat.rate(value, locale: locale)
    }

    /// Сумма: до двух знаков после запятой, для малых значений — значащие цифры.
    /// Если в настройках задано число знаков — ровно столько.
    static func amount(_ value: Double) -> String {
        AmountFormat.amount(value, locale: locale, decimalPlaces: decimalPlaces)
    }

    /// Сумма для поля ввода: без разделителей разрядов.
    static func editable(_ value: Double) -> String {
        // Огромные значения длиннее лимита ввода: стирать их можно, добавлять цифры — нет.
        let style = FloatingPointFormatStyle<Double>.number.locale(locale).grouping(.never)
        let text = value >= 1 || value == 0
            ? value.formatted(style.precision(.fractionLength(0...2)))
            : value.formatted(style.precision(.significantDigits(1...4)))
        // В поле ввода — без невидимых знаков направления (арабский ставит их перед минусом).
        return String(text.filter { !Calculator.directionMarks.contains($0) })
    }

    /// Вводимое выражение с разделителями разрядов, как у остальных сумм:
    /// при выборе валюты число не меняет вид. Дробная часть и знаки действий — как набраны.
    static func groupedInput(_ expression: String) -> String {
        let grouping = locale.groupingSeparator ?? ","
        let decimal = Calculator.decimalSeparator
        var result = ""
        var number = ""
        func flush() {
            guard !number.isEmpty else { return }
            let parts = number.components(separatedBy: decimal)
            var integer = parts[0]
            // Знак минуса у отрицательного итога — не цифра: иначе выходит «-,619».
            if integer.hasPrefix("-") {
                result += "-"
                integer.removeFirst()
            }
            var grouped = ""
            while integer.count > 3 {
                grouped = grouping + String(integer.suffix(3)) + grouped
                integer = String(integer.dropLast(3))
            }
            result += integer + grouped
            if parts.count > 1 { result += decimal + parts.dropFirst().joined(separator: decimal) }
            number = ""
        }
        for character in expression {
            if Calculator.operators.contains(character) {
                flush()
                result.append(character)
            } else {
                number.append(character)
            }
        }
        flush()
        return result
    }

    static func date(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(Currency.locale))
    }
}

/// Вычисление выражения из строки ввода, например «12,5+3×2». Умножение и деление — раньше сложения.
enum Calculator {
    static let operators: Set<Character> = ["+", "−", "×", "÷"]

    static func symbol(for key: KeypadKey) -> Character {
        switch key {
        case .add: "+"
        case .subtract: "−"
        case .multiply: "×"
        default: "÷"
        }
    }

    /// Разделитель дробной части выбранного языка: «,» или «.».
    static var decimalSeparator: String { RateFormat.locale.decimalSeparator ?? "," }

    /// Невидимые знаки направления текста: арабский формат ставит их перед минусом
    /// («؜-5»), и без очистки отрицательное число не читалось — сумма сбрасывалась на 1.
    static let directionMarks: Set<Character> = ["\u{200E}", "\u{200F}", "\u{061C}", "\u{202A}", "\u{202B}", "\u{202C}", "\u{202D}", "\u{202E}", "\u{2066}", "\u{2067}", "\u{2068}", "\u{2069}"]

    static func number(_ text: String) -> Double? {
        Double(String(text.filter { !directionMarks.contains($0) }).replacingOccurrences(of: ",", with: "."))
    }

    /// Число, которое вводится сейчас (после последнего знака действия).
    static func lastNumber(in expression: String) -> String {
        guard let index = expression.lastIndex(where: operators.contains) else { return expression }
        return String(expression[expression.index(after: index)...])
    }

    static func evaluate(_ expression: String) -> Double? {
        var numbers: [Double] = []
        var ops: [Character] = []
        var current = ""
        for character in expression {
            if operators.contains(character) {
                guard let value = number(current) else { return nil }
                numbers.append(value)
                ops.append(character)
                current = ""
            } else {
                current.append(character)
            }
        }
        if let value = number(current) {
            numbers.append(value)
        } else if !ops.isEmpty {
            ops.removeLast() // незаконченное «12+» считаем как «12»
        } else {
            return nil
        }

        // Сначала × и ÷, затем + и −.
        var terms = [numbers[0]]
        var additive: [Character] = []
        for (index, op) in ops.enumerated() {
            let rhs = numbers[index + 1]
            switch op {
            case "×": terms[terms.count - 1] *= rhs
            case "÷":
                guard rhs != 0 else { return nil }
                terms[terms.count - 1] /= rhs
            default:
                additive.append(op)
                terms.append(rhs)
            }
        }
        var result = terms[0]
        for (index, op) in additive.enumerated() {
            result = op == "+" ? result + terms[index + 1] : result - terms[index + 1]
        }
        return result.isFinite ? result : nil
    }
}
