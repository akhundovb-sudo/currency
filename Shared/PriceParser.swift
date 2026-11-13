import Foundation
import CoreGraphics

/// Достаёт цену из распознанной строки: «12.99», «€ 1 234,50», «1,299.00 ₺», «120 THB», «Pasta ..... 14,50».
/// Сначала — число рядом со знаком или кодом валюты, потом — число с копейками, потом — последнее число.
/// Время, даты, проценты, вес и объём пропускаются.
enum PriceParser {
    struct Found: Equatable {
        let value: Double
        let currency: String?
        /// Где число в строке: начало и конец как доля длины текста (с прилегающим знаком валюты).
        var start: CGFloat = 0
        var end: CGFloat = 1
    }

    /// Знаки, которые однозначно указывают валюту. «$», «¥», «kr» — у нескольких стран, их не угадываем.
    static let symbols: [String: String] = [
        "€": "EUR", "£": "GBP", "₺": "TRY", "₽": "RUB", "₼": "AZN", "₹": "INR", "฿": "THB",
        "₩": "KRW", "₴": "UAH", "₸": "KZT", "₾": "GEL", "₫": "VND", "₱": "PHP", "₪": "ILS",
        "zł": "PLN", "Kč": "CZK", "Ft": "HUF", "lei": "RON", "R$": "BRL", "AED": "AED", "د.إ": "AED",
    ]

    /// Число с разделителями разрядов и копейками: «1 234,50», «1,299.00», «12.99», «120».
    /// Строковый Regex, а не литерал /…/: общий код собирается и в виджете (режим Swift 5).
    nonisolated(unsafe) private static let number = try! Regex(
        #"\d{1,3}(?:[ .,'\x{00A0}\x{202F}]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?"#
    )

    /// После числа — единицы, а не цена.
    private static let units = ["%", "g", "kg", "mg", "ml", "l", "cl", "cm", "mm", "km", "гр", "г", "кг", "мл", "л", "шт", "pcs", "x", "×"]

    static func price(in text: String) -> Found? {
        guard !text.contains(":"), !text.contains("/") else { return nil }
        let candidates: [(range: Range<String.Index>, value: Double)] = text.matches(of: number).compactMap { match in
            guard let value = parse(String(text[match.range])), value < 10_000_000 else { return nil }
            // Пропускаем «500 g», «20%», «2 x».
            let after = text[match.range.upperBound...].trimmingCharacters(in: .whitespaces).lowercased()
            if units.contains(where: { unit in
                after.hasPrefix(unit) && (after.count == unit.count || !after.dropFirst(unit.count).first!.isLetter)
            }) { return nil }
            return (match.range, value)
        }
        guard !candidates.isEmpty else { return nil }

        let total = CGFloat(max(text.count, 1))
        func found(_ c: (range: Range<String.Index>, value: Double), _ code: String?) -> Found {
            // Плашка закрывает и знак валюты рядом с числом.
            let pad = code == nil ? 0 : 1
            let start = max(text.distance(from: text.startIndex, to: c.range.lowerBound) - pad, 0)
            let end = min(text.distance(from: text.startIndex, to: c.range.upperBound) + pad, text.count)
            return Found(value: c.value, currency: code, start: CGFloat(start) / total, end: CGFloat(end) / total)
        }

        // Число рядом со знаком или кодом валюты (до или после, в пределах пары символов).
        for candidate in candidates {
            if let code = currency(near: candidate.range, in: text) {
                return found(candidate, code)
            }
        }
        // Без знака: цена обычно с копейками или стоит в конце строки (меню).
        let withCents = candidates.last { text[$0.range].contains(where: { $0 == "." || $0 == "," })
            && text[$0.range].split(whereSeparator: { $0 == "." || $0 == "," }).last?.count ?? 0 <= 2 }
        let pick = withCents ?? candidates.last!
        // Одна цифра без знака валюты — скорее номер, количество или размер, а не цена.
        guard withCents != nil || text[pick.range].filter(\.isNumber).count >= 2 else { return nil }
        return found(pick, nil)
    }

    private static func currency(near range: Range<String.Index>, in text: String) -> String? {
        let before = String(text[..<range.lowerBound].suffix(4)).trimmingCharacters(in: .whitespaces)
        let after = String(text[range.upperBound...].prefix(4)).trimmingCharacters(in: .whitespaces)
        for (mark, code) in symbols {
            if before.hasSuffix(mark) || after.hasPrefix(mark) { return code }
        }
        // ISO-код рядом: «120 THB», «USD 15».
        let codeAfter = String(after.prefix(3)).uppercased(), codeBefore = String(before.suffix(3)).uppercased()
        for code in [codeAfter, codeBefore] where code.count == 3 && code.allSatisfy(\.isLetter)
            && Locale.commonISOCurrencyCodes.contains(code) {
            return code
        }
        return nil
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
