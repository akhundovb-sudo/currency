import ActivityKit
import Foundation

/// Live Activity «В поездке»: курс местной валюты к домашней на экране блокировки и в Dynamic Island.
/// Запускает и обновляет приложение (без сервера: обновления — когда приложение открыто
/// или обновляет курсы), показывает виджет-расширение.
struct TravelActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Сколько единиц домашней валюты стоит 1 единица местной.
        var rate: Double
        var updatedAt: Date
    }

    /// Местная валюта (страна, где вы сейчас), её страна и домашняя валюта.
    let local: String
    let country: String?
    let home: String
    /// Формат чисел и язык приложения.
    let numberLocaleIdentifier: String
    let languageIdentifier: String

    /// Шаг сумм под курс: у дешёвой валюты — 100 или 1 000, чтобы в домашней было ощутимое число.
    static func step(rate: Double) -> Double {
        rate > 0 ? pow(10, max(0, floor(log10(1 / rate)))) : 1
    }
}
