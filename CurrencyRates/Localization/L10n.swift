import Foundation

/// Язык интерфейса, выбираемый в настройках.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case ru, en, tr, fr, es, de

    var id: String { rawValue }

    /// Название языка на нём самом — так его проще найти в списке.
    var nativeName: String {
        switch self {
        case .ru: "Русский"
        case .en: "English"
        case .tr: "Türkçe"
        case .fr: "Français"
        case .es: "Español"
        case .de: "Deutsch"
        }
    }

    var locale: Locale {
        switch self {
        case .ru: Locale(identifier: "ru_RU")
        case .en: Locale(identifier: "en_US")
        case .tr: Locale(identifier: "tr_TR")
        case .fr: Locale(identifier: "fr_FR")
        case .es: Locale(identifier: "es_ES")
        case .de: Locale(identifier: "de_DE")
        }
    }

    /// Язык системы, если он поддерживается, иначе русский.
    static var systemDefault: AppLanguage {
        for identifier in Locale.preferredLanguages {
            let code = Locale(identifier: identifier).language.languageCode?.identifier ?? ""
            if let language = AppLanguage(rawValue: code) { return language }
        }
        return .ru
    }
}

/// Переводы строк интерфейса. Текущий язык задаёт `RatesStore.language`.
enum L10n {
    nonisolated(unsafe) static var current: AppLanguage = .systemDefault

    enum Key {
        case title, settings, edit, done, close, delete, addCurrency
        case updateFailed, retry, loading, demoData, fiatShort, cryptoShort, notLoaded, updatedAt, cachedAt
        case longPressClears, comma, erase, plus, minus, multiply, divide, equals, hideKeyboard
        case alreadyAdded, addToList, nothingFound, noResults, searchPrompt, currencyType
        case sourceHint, enterHint, enteredAmount, noRate
        case appearance, theme, language, source, updated, fiatCurrencies, fiatFooter
        case cryptoCurrencies, cryptoFooter, refreshRates, offlineFooter, version, noData, demoShort
        case themeSystem, themeLight, themeDark
        case minTwoCurrencies, proOnly, proDiscover, seeDetails, proTest
        case errNoInternet, errTimeout, errServer, errRateLimited, errBadResponse
    }

    // ru, en, tr, fr, es, de
    private static let table: [Key: [String]] = [
        .title: ["Валюты", "Currencies", "Para Birimleri", "Devises", "Divisas", "Währungen"],
        .settings: ["Настройки", "Settings", "Ayarlar", "Réglages", "Ajustes", "Einstellungen"],
        .edit: ["Править", "Edit", "Düzenle", "Modifier", "Editar", "Bearbeiten"],
        .done: ["Готово", "Done", "Bitti", "OK", "OK", "Fertig"],
        .close: ["Закрыть", "Close", "Kapat", "Fermer", "Cerrar", "Schließen"],
        .delete: ["Удалить", "Delete", "Sil", "Supprimer", "Eliminar", "Löschen"],
        .addCurrency: ["Добавить валюту", "Add Currency", "Para Birimi Ekle", "Ajouter une devise", "Añadir divisa", "Währung hinzufügen"],
        .updateFailed: ["Не удалось обновить курсы", "Couldn’t update rates", "Kurlar güncellenemedi", "Impossible de mettre à jour les taux", "No se pudieron actualizar los tipos", "Kurse konnten nicht aktualisiert werden"],
        .retry: ["Повторить загрузку", "Try Again", "Tekrar Dene", "Réessayer", "Reintentar", "Erneut versuchen"],
        .loading: ["Загрузка курсов…", "Loading rates…", "Kurlar yükleniyor…", "Chargement des taux…", "Cargando tipos…", "Kurse werden geladen…"],
        .demoData: ["Демонстрационные данные, не реальные курсы", "Demo data, not real rates", "Demo veriler, gerçek kurlar değil", "Données de démonstration, pas de vrais taux", "Datos de demostración, no son tipos reales", "Demodaten, keine echten Kurse"],
        .fiatShort: ["Фиат", "Fiat", "İtibari", "Fiat", "Fiat", "Fiat"],
        .cryptoShort: ["Крипта", "Crypto", "Kripto", "Crypto", "Cripto", "Krypto"],
        .notLoaded: ["Курсы ещё не загружены.", "Rates haven’t loaded yet.", "Kurlar henüz yüklenmedi.", "Les taux ne sont pas encore chargés.", "Los tipos aún no se han cargado.", "Kurse wurden noch nicht geladen."],
        .updatedAt: ["Обновлено: %@", "Updated: %@", "Güncellendi: %@", "Mis à jour : %@", "Actualizado: %@", "Aktualisiert: %@"],
        .cachedAt: ["Сохранённые данные, загружены %@", "Saved data, loaded %@", "Kayıtlı veriler, yüklenme: %@", "Données enregistrées, chargées le %@", "Datos guardados, cargados el %@", "Gespeicherte Daten, geladen am %@"],
        .longPressClears: ["Долгое нажатие очищает сумму", "Long press clears the amount", "Uzun basmak tutarı siler", "Un appui long efface le montant", "Mantén pulsado para borrar el importe", "Langes Drücken löscht den Betrag"],
        .comma: ["Запятая", "Decimal point", "Ondalık ayırıcı", "Virgule", "Coma decimal", "Komma"],
        .erase: ["Стереть", "Delete", "Sil", "Effacer", "Borrar", "Löschen"],
        .plus: ["Плюс", "Plus", "Artı", "Plus", "Más", "Plus"],
        .minus: ["Минус", "Minus", "Eksi", "Moins", "Menos", "Minus"],
        .multiply: ["Умножить", "Multiply", "Çarp", "Multiplier", "Multiplicar", "Mal"],
        .divide: ["Разделить", "Divide", "Böl", "Diviser", "Dividir", "Geteilt"],
        .equals: ["Равно", "Equals", "Eşittir", "Égal", "Igual", "Gleich"],
        .hideKeyboard: ["Скрыть клавиатуру", "Hide Keyboard", "Klavyeyi Gizle", "Masquer le clavier", "Ocultar teclado", "Tastatur ausblenden"],
        .alreadyAdded: ["Уже в списке", "Already in the list", "Zaten listede", "Déjà dans la liste", "Ya está en la lista", "Bereits in der Liste"],
        .addToList: ["Добавить в список", "Add to the list", "Listeye ekle", "Ajouter à la liste", "Añadir a la lista", "Zur Liste hinzufügen"],
        .nothingFound: ["Ничего не найдено", "No Results", "Sonuç Yok", "Aucun résultat", "Sin resultados", "Keine Ergebnisse"],
        .noResults: ["Нет валют по запросу «%@».", "No currencies match “%@”.", "“%@” ile eşleşen para birimi yok.", "Aucune devise ne correspond à « %@ ».", "Ninguna divisa coincide con «%@».", "Keine Währung passt zu „%@“."],
        .searchPrompt: ["Код или название", "Code or name", "Kod veya ad", "Code ou nom", "Código o nombre", "Code oder Name"],
        .currencyType: ["Тип валюты", "Currency type", "Para birimi türü", "Type de devise", "Tipo de divisa", "Währungstyp"],
        .sourceHint: ["Сумма вводится в этой валюте", "The amount is entered in this currency", "Tutar bu para biriminde giriliyor", "Le montant est saisi dans cette devise", "El importe se introduce en esta divisa", "Der Betrag wird in dieser Währung eingegeben"],
        .enterHint: ["Ввести сумму в этой валюте", "Enter the amount in this currency", "Tutarı bu para biriminde gir", "Saisir le montant dans cette devise", "Introducir el importe en esta divisa", "Betrag in dieser Währung eingeben"],
        .enteredAmount: ["Вводимая сумма", "Amount entered", "Girilen tutar", "Montant saisi", "Importe introducido", "Eingegebener Betrag"],
        .noRate: ["Нет курса", "No rate", "Kur yok", "Pas de taux", "Sin tipo", "Kein Kurs"],
        .appearance: ["Оформление", "Appearance", "Görünüm", "Apparence", "Apariencia", "Darstellung"],
        .theme: ["Тема", "Theme", "Tema", "Thème", "Tema", "Design"],
        .language: ["Язык", "Language", "Dil", "Langue", "Idioma", "Sprache"],
        .source: ["Источник", "Source", "Kaynak", "Source", "Fuente", "Quelle"],
        .updated: ["Обновлено", "Updated", "Güncellendi", "Mis à jour", "Actualizado", "Aktualisiert"],
        .fiatCurrencies: ["Фиатные валюты", "Fiat currencies", "İtibari paralar", "Devises fiduciaires", "Divisas fiduciarias", "Fiatwährungen"],
        .fiatFooter: ["Поставщик обновляет курсы раз в сутки.", "The provider updates rates once a day.", "Sağlayıcı kurları günde bir kez günceller.", "Le fournisseur met à jour les taux une fois par jour.", "El proveedor actualiza los tipos una vez al día.", "Der Anbieter aktualisiert die Kurse einmal täglich."],
        .cryptoCurrencies: ["Криптовалюты", "Cryptocurrencies", "Kripto paralar", "Cryptomonnaies", "Criptomonedas", "Kryptowährungen"],
        .cryptoFooter: ["Цены обновляются несколько раз в минуту.", "Prices update several times a minute.", "Fiyatlar dakikada birkaç kez güncellenir.", "Les prix sont mis à jour plusieurs fois par minute.", "Los precios se actualizan varias veces por minuto.", "Preise werden mehrmals pro Minute aktualisiert."],
        .refreshRates: ["Обновить курсы", "Refresh Rates", "Kurları Yenile", "Actualiser les taux", "Actualizar tipos", "Kurse aktualisieren"],
        .offlineFooter: ["Последние загруженные курсы сохраняются на устройстве и доступны без интернета.", "The latest rates are saved on the device and available offline.", "Son yüklenen kurlar cihazda saklanır ve internetsiz kullanılabilir.", "Les derniers taux sont enregistrés sur l’appareil et disponibles hors ligne.", "Los últimos tipos se guardan en el dispositivo y están disponibles sin conexión.", "Die letzten Kurse werden auf dem Gerät gespeichert und sind offline verfügbar."],
        .version: ["Версия", "Version", "Sürüm", "Version", "Versión", "Version"],
        .noData: ["Нет данных", "No data", "Veri yok", "Aucune donnée", "Sin datos", "Keine Daten"],
        .demoShort: ["Демо-данные", "Demo data", "Demo veriler", "Données de démo", "Datos de demo", "Demodaten"],
        .themeSystem: ["Системная", "System", "Sistem", "Système", "Sistema", "System"],
        .themeLight: ["Светлая", "Light", "Açık", "Clair", "Claro", "Hell"],
        .themeDark: ["Тёмная", "Dark", "Koyu", "Sombre", "Oscuro", "Dunkel"],
        .minTwoCurrencies: ["Нельзя удалить: нужно минимум две валюты", "Can’t delete: at least two currencies are required", "Silinemez: en az iki para birimi gerekli", "Suppression impossible : au moins deux devises sont requises", "No se puede eliminar: se necesitan al menos dos divisas", "Löschen nicht möglich: mindestens zwei Währungen nötig"],
        .proOnly: ["Доступно с подпиской Pro", "Available with Pro subscription", "Pro abonelikle kullanılabilir", "Disponible avec l’abonnement Pro", "Disponible con la suscripción Pro", "Mit Pro-Abo verfügbar"],
        .proDiscover: ["Откройте %@ — валюты без ограничений", "Discover %@ for unlimited currencies", "Sınırsız para birimi için %@’yu keşfedin", "Découvrez %@ pour des devises illimitées", "Descubre %@ para divisas ilimitadas", "Entdecke %@ für unbegrenzte Währungen"],
        .seeDetails: ["Подробнее", "See details", "Ayrıntıları gör", "Voir les détails", "Ver detalles", "Details ansehen"],
        .proTest: ["Pro (для теста)", "Pro (testing)", "Pro (test için)", "Pro (test)", "Pro (prueba)", "Pro (Test)"],
        .errNoInternet: ["нет подключения к интернету.", "no internet connection.", "internet bağlantısı yok.", "pas de connexion Internet.", "no hay conexión a Internet.", "keine Internetverbindung."],
        .errTimeout: ["сервер не ответил вовремя.", "the server didn’t respond in time.", "sunucu zamanında yanıt vermedi.", "le serveur n’a pas répondu à temps.", "el servidor no respondió a tiempo.", "der Server hat nicht rechtzeitig geantwortet."],
        .errServer: ["не удалось связаться с сервером.", "couldn’t reach the server.", "sunucuya ulaşılamadı.", "impossible de joindre le serveur.", "no se pudo conectar con el servidor.", "Server nicht erreichbar."],
        .errRateLimited: ["слишком много запросов, попробуйте через минуту.", "too many requests, try again in a minute.", "çok fazla istek, bir dakika sonra tekrar deneyin.", "trop de requêtes, réessayez dans une minute.", "demasiadas solicitudes, inténtalo en un minuto.", "zu viele Anfragen, in einer Minute erneut versuchen."],
        .errBadResponse: ["сервер вернул некорректный ответ.", "the server returned an invalid response.", "sunucu geçersiz yanıt döndürdü.", "le serveur a renvoyé une réponse non valide.", "el servidor devolvió una respuesta no válida.", "der Server hat eine ungültige Antwort gesendet."],
    ]

    static func string(_ key: Key) -> String {
        let index = AppLanguage.allCases.firstIndex(of: current) ?? 0
        return table[key]?[index] ?? ""
    }
}

/// Перевод строки интерфейса; для строк с `%@` — подставляет аргументы.
func L(_ key: L10n.Key, _ arguments: String...) -> String {
    let format = L10n.string(key)
    return arguments.isEmpty ? format : String(format: format, arguments: arguments.map { $0 as CVarArg })
}
