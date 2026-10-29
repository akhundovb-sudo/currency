import Foundation

/// Язык интерфейса, выбираемый в настройках.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    // Порядок важен: по нему выбирается столбец в таблице переводов. Новые языки — только в конец.
    case ru, en, tr, fr, es, de, zh, ar, ja, pt, ko, zhHant = "zh-Hant", it, pl

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
        case .zh: "中文（简体）"
        case .ar: "العربية"
        case .ja: "日本語"
        case .pt: "Português (Brasil)"
        case .ko: "한국어"
        case .zhHant: "中文（繁體）"
        case .it: "Italiano"
        case .pl: "Polski"
        }
    }

    /// Название по-английски: по нему список языков в настройках идёт по алфавиту.
    var englishName: String {
        switch self {
        case .ru: "Russian"
        case .en: "English"
        case .tr: "Turkish"
        case .fr: "French"
        case .es: "Spanish"
        case .de: "German"
        case .zh: "Chinese (Simplified)"
        case .ar: "Arabic"
        case .ja: "Japanese"
        case .pt: "Portuguese (Brazil)"
        case .ko: "Korean"
        case .zhHant: "Chinese (Traditional)"
        case .it: "Italian"
        case .pl: "Polish"
        }
    }

    /// Все языки по алфавиту (по английскому названию).
    static var sortedByName: [AppLanguage] {
        allCases.sorted { $0.englishName < $1.englishName }
    }

    /// Локаль языка; создаётся один раз — её спрашивают при каждом форматировании числа.
    var locale: Locale {
        if let cached = Self.locales[self] { return cached }
        let locale = makeLocale()
        Self.locales[self] = locale
        return locale
    }

    nonisolated(unsafe) private static var locales: [AppLanguage: Locale] = [:]

    private func makeLocale() -> Locale {
        switch self {
        case .ru: Locale(identifier: "ru_RU")
        case .en: Locale(identifier: "en_US")
        case .tr: Locale(identifier: "tr_TR")
        case .fr: Locale(identifier: "fr_FR")
        case .es: Locale(identifier: "es_ES")
        case .de: Locale(identifier: "de_DE")
        case .zh: Locale(identifier: "zh_Hans_CN")
        case .ar: Locale(identifier: "ar_AE@numbers=latn")  // латинские цифры, как на клавиатуре
        case .ja: Locale(identifier: "ja_JP")
        case .pt: Locale(identifier: "pt_BR")
        case .ko: Locale(identifier: "ko_KR")
        case .zhHant: Locale(identifier: "zh_Hant_TW")
        case .it: Locale(identifier: "it_IT")
        case .pl: Locale(identifier: "pl_PL")
        }
    }

    /// Арабский пишется справа налево.
    var isRightToLeft: Bool { self == .ar
    }

    /// Язык системы, если он поддерживается, иначе английский.
    static var systemDefault: AppLanguage {
        for identifier in Locale.preferredLanguages {
            let language = Locale(identifier: identifier).language
            let code = language.languageCode?.identifier ?? ""
            // Китайский: традиционное письмо (Тайвань, Гонконг, Макао) — отдельный язык.
            if code == "zh" {
                let isTraditional = language.script?.identifier == "Hant"
                    || ["TW", "HK", "MO"].contains(language.region?.identifier ?? "")
                return isTraditional ? .zhHant : .zh
            }
            if let match = AppLanguage(rawValue: code) { return match }
        }
        return .en
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
        case minTwoCurrencies, proOnly, proDiscover, seeDetails, proSuspended, freeSetChanged
        case numbers, numberFormat, decimalPlaces, auto, formatFooter
        case example, rates, about, dataFooter
        case proBecome, proSubscription, upgrade
        case proHeadline, planMonthly, planYearly, planLifetime, perMonth, perYear, oneTime
        case bestValue, included, featUnlimited, featFiat, featCrypto, featSupport
        case rateApp, manageSubscription, proActive, support, termsPrivacy
        case appIcon, iconChrome, iconKnit, iconRubber, iconStone, iconBlocks, iconDoodle, iconPixel, iconEngraving, iconAmethyst, iconSticker, iconPuffy, iconSponge, iconPlush, iconGummy, iconBubbles, iconHolo
        case getFullAccess, startTrial, trialNote, terms, privacy, restore
        case formatAutomatic, formatInternational, formatEuropean, formatSpaced
        case errNoInternet, errTimeout, errServer, errRateLimited, errBadResponse
    }

    // ru, en, tr, fr, es, de, zh, ar, ja, pt, ko, zh-Hant, it, pl
    private static let table: [Key: [String]] = [
        .title: ["Cento", "Cento", "Cento", "Cento", "Cento", "Cento", "Cento", "Cento", "Cento", "Cento", "Cento", "Cento", "Cento", "Cento"],
        .settings: ["Настройки", "Settings", "Ayarlar", "Réglages", "Ajustes", "Einstellungen", "设置", "الإعدادات", "設定", "Ajustes", "설정", "設定", "Impostazioni", "Ustawienia"],
        .edit: ["Править", "Edit", "Düzenle", "Modifier", "Editar", "Bearbeiten", "编辑", "تعديل", "編集", "Editar", "편집", "編輯", "Modifica", "Edytuj"],
        .done: ["Готово", "Done", "Bitti", "OK", "OK", "Fertig", "完成", "تم", "完了", "OK", "완료", "完成", "Fine", "Gotowe"],
        .close: ["Закрыть", "Close", "Kapat", "Fermer", "Cerrar", "Schließen", "关闭", "إغلاق", "閉じる", "Fechar", "닫기", "關閉", "Chiudi", "Zamknij"],
        .delete: ["Удалить", "Delete", "Sil", "Supprimer", "Eliminar", "Löschen", "删除", "حذف", "削除", "Excluir", "삭제", "刪除", "Elimina", "Usuń"],
        .addCurrency: ["Добавить валюту", "Add Currency", "Para Birimi Ekle", "Ajouter une devise", "Añadir divisa", "Währung hinzufügen", "添加货币", "إضافة عملة", "通貨を追加", "Adicionar moeda", "통화 추가", "新增貨幣", "Aggiungi valuta", "Dodaj walutę"],
        .updateFailed: ["Не удалось обновить курсы", "Couldn’t update rates", "Kurlar güncellenemedi", "Impossible de mettre à jour les taux", "No se pudieron actualizar los tipos", "Kurse konnten nicht aktualisiert werden", "无法更新汇率", "تعذّر تحديث الأسعار", "レートを更新できませんでした", "Não foi possível atualizar as cotações", "환율을 업데이트할 수 없습니다", "無法更新匯率", "Impossibile aggiornare i tassi", "Nie udało się zaktualizować kursów"],
        .retry: ["Повторить загрузку", "Try Again", "Tekrar Dene", "Réessayer", "Reintentar", "Erneut versuchen", "重试", "إعادة المحاولة", "再試行", "Tentar novamente", "다시 시도", "重試", "Riprova", "Spróbuj ponownie"],
        .loading: ["Загрузка курсов…", "Loading rates…", "Kurlar yükleniyor…", "Chargement des taux…", "Cargando tipos…", "Kurse werden geladen…", "正在加载汇率…", "جارٍ تحميل الأسعار…", "レートを読み込み中…", "Carregando cotações…", "환율 불러오는 중…", "正在載入匯率…", "Caricamento dei tassi…", "Wczytywanie kursów…"],
        .demoData: ["Демонстрационные данные, не реальные курсы", "Demo data, not real rates", "Demo veriler, gerçek kurlar değil", "Données de démonstration, pas de vrais taux", "Datos de demostración, no son tipos reales", "Demodaten, keine echten Kurse", "演示数据，并非真实汇率", "بيانات تجريبية وليست أسعارًا حقيقية", "デモデータです。実際のレートではありません", "Dados de demonstração, não são cotações reais", "데모 데이터이며 실제 환율이 아닙니다", "示範資料，並非真實匯率", "Dati dimostrativi, non sono tassi reali", "Dane demonstracyjne, nie są to prawdziwe kursy"],
        .fiatShort: ["Фиат", "Fiat", "İtibari", "Fiat", "Fiat", "Fiat", "法币", "نقدية", "法定通貨", "Fiat", "법정화폐", "法幣", "Fiat", "Fiat"],
        .cryptoShort: ["Крипта", "Crypto", "Kripto", "Crypto", "Cripto", "Krypto", "加密", "مشفّرة", "暗号資産", "Cripto", "암호화폐", "加密", "Cripto", "Krypto"],
        .notLoaded: ["Курсы ещё не загружены.", "Rates haven’t loaded yet.", "Kurlar henüz yüklenmedi.", "Les taux ne sont pas encore chargés.", "Los tipos aún no se han cargado.", "Kurse wurden noch nicht geladen.", "汇率尚未加载。", "لم يتم تحميل الأسعار بعد.", "レートはまだ読み込まれていません。", "As cotações ainda não foram carregadas.", "환율을 아직 불러오지 못했습니다.", "匯率尚未載入。", "I tassi non sono ancora stati caricati.", "Kursy nie zostały jeszcze wczytane."],
        .updatedAt: ["Обновлено: %@", "Updated: %@", "Güncellendi: %@", "Mis à jour : %@", "Actualizado: %@", "Aktualisiert: %@", "更新于：%@", "آخر تحديث: %@", "更新: %@", "Atualizado: %@", "업데이트: %@", "更新於：%@", "Aggiornato: %@", "Zaktualizowano: %@"],
        .cachedAt: ["Сохранённые данные, загружены %@", "Saved data, loaded %@", "Kayıtlı veriler, yüklenme: %@", "Données enregistrées, chargées le %@", "Datos guardados, cargados el %@", "Gespeicherte Daten, geladen am %@", "已保存的数据，加载于 %@", "بيانات محفوظة، حُمّلت في %@", "保存済みデータ（読み込み: %@）", "Dados salvos, carregados em %@", "저장된 데이터, %@에 불러옴", "已儲存的資料，載入於 %@", "Dati salvati, caricati il %@", "Zapisane dane, wczytane %@"],
        .longPressClears: ["Долгое нажатие очищает сумму", "Long press clears the amount", "Uzun basmak tutarı siler", "Un appui long efface le montant", "Mantén pulsado para borrar el importe", "Langes Drücken löscht den Betrag", "长按可清除金额", "اضغط مطولًا لمسح المبلغ", "長押しで金額をクリア", "Mantenha pressionado para apagar o valor", "길게 누르면 금액이 지워집니다", "長按可清除金額", "Tieni premuto per cancellare l’importo", "Przytrzymaj, aby wyczyścić kwotę"],
        .comma: ["Запятая", "Decimal point", "Ondalık ayırıcı", "Virgule", "Coma decimal", "Komma", "小数点", "الفاصلة العشرية", "小数点", "Vírgula decimal", "소수점", "小數點", "Virgola decimale", "Przecinek dziesiętny"],
        .erase: ["Стереть", "Delete", "Sil", "Effacer", "Borrar", "Löschen", "删除", "حذف", "削除", "Apagar", "지우기", "刪除", "Cancella", "Usuń"],
        .plus: ["Плюс", "Plus", "Artı", "Plus", "Más", "Plus", "加", "زائد", "プラス", "Mais", "더하기", "加", "Più", "Plus"],
        .minus: ["Минус", "Minus", "Eksi", "Moins", "Menos", "Minus", "减", "ناقص", "マイナス", "Menos", "빼기", "減", "Meno", "Minus"],
        .multiply: ["Умножить", "Multiply", "Çarp", "Multiplier", "Multiplicar", "Mal", "乘", "ضرب", "掛ける", "Multiplicar", "곱하기", "乘", "Moltiplica", "Pomnóż"],
        .divide: ["Разделить", "Divide", "Böl", "Diviser", "Dividir", "Geteilt", "除", "قسمة", "割る", "Dividir", "나누기", "除", "Dividi", "Podziel"],
        .equals: ["Равно", "Equals", "Eşittir", "Égal", "Igual", "Gleich", "等于", "يساوي", "イコール", "Igual", "등호", "等於", "Uguale", "Równa się"],
        .hideKeyboard: ["Скрыть клавиатуру", "Hide Keyboard", "Klavyeyi Gizle", "Masquer le clavier", "Ocultar teclado", "Tastatur ausblenden", "隐藏键盘", "إخفاء لوحة المفاتيح", "キーボードを閉じる", "Ocultar teclado", "키보드 숨기기", "隱藏鍵盤", "Nascondi tastiera", "Ukryj klawiaturę"],
        .alreadyAdded: ["Уже в списке", "Already in the list", "Zaten listede", "Déjà dans la liste", "Ya está en la lista", "Bereits in der Liste", "已在列表中", "موجودة في القائمة", "すでにリストにあります", "Já está na lista", "이미 목록에 있음", "已在列表中", "Già nell’elenco", "Już na liście"],
        .addToList: ["Добавить в список", "Add to the list", "Listeye ekle", "Ajouter à la liste", "Añadir a la lista", "Zur Liste hinzufügen", "添加到列表", "إضافة إلى القائمة", "リストに追加", "Adicionar à lista", "목록에 추가", "加入列表", "Aggiungi all’elenco", "Dodaj do listy"],
        .nothingFound: ["Ничего не найдено", "No Results", "Sonuç Yok", "Aucun résultat", "Sin resultados", "Keine Ergebnisse", "无结果", "لا توجد نتائج", "結果なし", "Nenhum resultado", "결과 없음", "無結果", "Nessun risultato", "Brak wyników"],
        .noResults: ["Нет валют по запросу «%@».", "No currencies match “%@”.", "“%@” ile eşleşen para birimi yok.", "Aucune devise ne correspond à « %@ ».", "Ninguna divisa coincide con «%@».", "Keine Währung passt zu „%@“.", "没有与“%@”匹配的货币。", "لا توجد عملات تطابق «%@».", "「%@」に一致する通貨はありません。", "Nenhuma moeda corresponde a “%@”.", "“%@”에 해당하는 통화가 없습니다.", "沒有符合「%@」的貨幣。", "Nessuna valuta corrisponde a “%@”.", "Brak walut pasujących do „%@”."],
        .searchPrompt: ["Код или название", "Code or name", "Kod veya ad", "Code ou nom", "Código o nombre", "Code oder Name", "代码或名称", "الرمز أو الاسم", "コードまたは名前", "Código ou nome", "코드 또는 이름", "代碼或名稱", "Codice o nome", "Kod lub nazwa"],
        .currencyType: ["Тип валюты", "Currency type", "Para birimi türü", "Type de devise", "Tipo de divisa", "Währungstyp", "货币类型", "نوع العملة", "通貨の種類", "Tipo de moeda", "통화 유형", "貨幣類型", "Tipo di valuta", "Typ waluty"],
        .sourceHint: ["Сумма вводится в этой валюте", "The amount is entered in this currency", "Tutar bu para biriminde giriliyor", "Le montant est saisi dans cette devise", "El importe se introduce en esta divisa", "Der Betrag wird in dieser Währung eingegeben", "金额以此货币输入", "يُدخل المبلغ بهذه العملة", "この通貨で金額を入力します", "O valor é inserido nesta moeda", "이 통화로 금액을 입력합니다", "以此貨幣輸入金額", "L’importo viene inserito in questa valuta", "Kwota jest wprowadzana w tej walucie"],
        .enterHint: ["Ввести сумму в этой валюте", "Enter the amount in this currency", "Tutarı bu para biriminde gir", "Saisir le montant dans cette devise", "Introducir el importe en esta divisa", "Betrag in dieser Währung eingeben", "以此货币输入金额", "أدخل المبلغ بهذه العملة", "この通貨で金額を入力", "Inserir o valor nesta moeda", "이 통화로 금액 입력", "以此貨幣輸入金額", "Inserisci l’importo in questa valuta", "Wpisz kwotę w tej walucie"],
        .enteredAmount: ["Вводимая сумма", "Amount entered", "Girilen tutar", "Montant saisi", "Importe introducido", "Eingegebener Betrag", "输入的金额", "المبلغ المُدخل", "入力金額", "Valor inserido", "입력 금액", "輸入的金額", "Importo inserito", "Wpisana kwota"],
        .noRate: ["Нет курса", "No rate", "Kur yok", "Pas de taux", "Sin tipo", "Kein Kurs", "无汇率", "لا يوجد سعر", "レートなし", "Sem cotação", "환율 없음", "無匯率", "Nessun tasso", "Brak kursu"],
        .appearance: ["Оформление", "Appearance", "Görünüm", "Apparence", "Apariencia", "Darstellung", "外观", "المظهر", "外観", "Aparência", "화면 스타일", "外觀", "Aspetto", "Wygląd"],
        .theme: ["Тема", "Theme", "Tema", "Thème", "Tema", "Design", "主题", "السمة", "テーマ", "Tema", "테마", "主題", "Tema", "Motyw"],
        .language: ["Язык", "Language", "Dil", "Langue", "Idioma", "Sprache", "语言", "اللغة", "言語", "Idioma", "언어", "語言", "Lingua", "Język"],
        .source: ["Источник", "Source", "Kaynak", "Source", "Fuente", "Quelle", "来源", "المصدر", "提供元", "Fonte", "출처", "來源", "Fonte", "Źródło"],
        .updated: ["Обновлено", "Updated", "Güncellendi", "Mis à jour", "Actualizado", "Aktualisiert", "更新时间", "آخر تحديث", "更新日時", "Atualizado", "업데이트됨", "更新時間", "Aggiornato", "Zaktualizowano"],
        .fiatCurrencies: ["Фиатные валюты", "Fiat currencies", "İtibari paralar", "Devises fiduciaires", "Divisas fiduciarias", "Fiatwährungen", "法定货币", "العملات النقدية", "法定通貨", "Moedas fiduciárias", "법정화폐", "法定貨幣", "Valute fiat", "Waluty fiat"],
        .fiatFooter: ["Поставщик обновляет курсы раз в сутки.", "The provider updates rates once a day.", "Sağlayıcı kurları günde bir kez günceller.", "Le fournisseur met à jour les taux une fois par jour.", "El proveedor actualiza los tipos una vez al día.", "Der Anbieter aktualisiert die Kurse einmal täglich.", "提供方每天更新一次汇率。", "يحدّث المزوّد الأسعار مرة يوميًا.", "提供元は1日1回レートを更新します。", "O provedor atualiza as cotações uma vez por dia.", "제공업체가 하루에 한 번 환율을 업데이트합니다.", "提供者每天更新一次匯率。", "Il fornitore aggiorna i tassi una volta al giorno.", "Dostawca aktualizuje kursy raz dziennie."],
        .cryptoCurrencies: ["Криптовалюты", "Cryptocurrencies", "Kripto paralar", "Cryptomonnaies", "Criptomonedas", "Kryptowährungen", "加密货币", "العملات المشفّرة", "暗号資産", "Criptomoedas", "암호화폐", "加密貨幣", "Criptovalute", "Kryptowaluty"],
        .cryptoFooter: ["Цены обновляются несколько раз в минуту.", "Prices update several times a minute.", "Fiyatlar dakikada birkaç kez güncellenir.", "Les prix sont mis à jour plusieurs fois par minute.", "Los precios se actualizan varias veces por minuto.", "Preise werden mehrmals pro Minute aktualisiert.", "价格每分钟更新数次。", "تتحدث الأسعار عدة مرات في الدقيقة.", "価格は1分間に数回更新されます。", "Os preços são atualizados várias vezes por minuto.", "가격은 분당 여러 번 업데이트됩니다.", "價格每分鐘更新數次。", "I prezzi vengono aggiornati più volte al minuto.", "Ceny są aktualizowane kilka razy na minutę."],
        .refreshRates: ["Обновить курсы", "Refresh Rates", "Kurları Yenile", "Actualiser les taux", "Actualizar tipos", "Kurse aktualisieren", "刷新汇率", "تحديث الأسعار", "レートを更新", "Atualizar cotações", "환율 새로고침", "重新整理匯率", "Aggiorna tassi", "Odśwież kursy"],
        .offlineFooter: ["Последние загруженные курсы сохраняются на устройстве и доступны без интернета.", "The latest rates are saved on the device and available offline.", "Son yüklenen kurlar cihazda saklanır ve internetsiz kullanılabilir.", "Les derniers taux sont enregistrés sur l’appareil et disponibles hors ligne.", "Los últimos tipos se guardan en el dispositivo y están disponibles sin conexión.", "Die letzten Kurse werden auf dem Gerät gespeichert und sind offline verfügbar.", "最新汇率保存在设备上，离线也可使用。", "تُحفظ أحدث الأسعار على الجهاز وتتوفر دون اتصال.", "最新のレートは端末に保存され、オフラインでも使えます。", "As cotações mais recentes ficam salvas no dispositivo e funcionam offline.", "최신 환율은 기기에 저장되어 오프라인에서도 사용할 수 있습니다.", "最新匯率會儲存在裝置上，離線時也能使用。", "Gli ultimi tassi sono salvati sul dispositivo e disponibili offline.", "Najnowsze kursy są zapisywane na urządzeniu i dostępne offline."],
        .version: ["Версия", "Version", "Sürüm", "Version", "Versión", "Version", "版本", "الإصدار", "バージョン", "Versão", "버전", "版本", "Versione", "Wersja"],
        .noData: ["Нет данных", "No data", "Veri yok", "Aucune donnée", "Sin datos", "Keine Daten", "无数据", "لا توجد بيانات", "データなし", "Sem dados", "데이터 없음", "無資料", "Nessun dato", "Brak danych"],
        .demoShort: ["Демо-данные", "Demo data", "Demo veriler", "Données de démo", "Datos de demo", "Demodaten", "演示数据", "بيانات تجريبية", "デモデータ", "Dados de demo", "데모 데이터", "示範資料", "Dati demo", "Dane demo"],
        .themeSystem: ["Системная", "System", "Sistem", "Système", "Sistema", "System", "跟随系统", "النظام", "システム", "Sistema", "시스템", "跟隨系統", "Sistema", "Systemowy"],
        .themeLight: ["Светлая", "Light", "Açık", "Clair", "Claro", "Hell", "浅色", "فاتح", "ライト", "Claro", "라이트", "淺色", "Chiaro", "Jasny"],
        .themeDark: ["Тёмная", "Dark", "Koyu", "Sombre", "Oscuro", "Dunkel", "深色", "داكن", "ダーク", "Escuro", "다크", "深色", "Scuro", "Ciemny"],
        .proSuspended: ["Pro закончился: валюты Pro отключены и вернутся с подпиской", "Pro has ended: Pro currencies are off until you renew", "Pro sona erdi: Pro para birimleri yenileyene kadar kapalı", "Pro a expiré : les devises Pro reviendront au renouvellement", "Pro ha terminado: las divisas Pro volverán al renovar", "Pro ist abgelaufen: Pro-Währungen kehren nach Verlängerung zurück", "Pro 已到期：Pro 货币已停用，续订后恢复", "انتهى Pro: عملات Pro متوقفة حتى التجديد", "Pro が終了しました。更新するまで Pro の通貨は無効です", "O Pro terminou: as moedas Pro ficam desativadas até renovar", "Pro가 종료되었습니다. 갱신할 때까지 Pro 통화가 꺼져 있습니다", "Pro 已到期：Pro 貨幣已停用，續訂後恢復", "Pro è scaduto: le valute Pro restano disattivate fino al rinnovo", "Pro wygasło: waluty Pro są wyłączone do odnowienia"],
        .freeSetChanged: ["Без подписки бесплатно 3 валюты. Отключено: %@ — вернётся с Pro", "Without Pro, 3 currencies are free. Turned off: %@ — back with Pro", "Pro olmadan 3 para birimi ücretsiz: %@ Pro ile geri gelir", "Sans Pro, 3 devises sont gratuites : %@ reviendra avec Pro", "Sin Pro, 3 divisas son gratis: %@ volverá con Pro", "Ohne Pro sind 3 Währungen kostenlos: %@ kehrt mit Pro zurück", "未订阅 Pro 时可免费使用 3 种货币：%@ 已停用，订阅 Pro 后恢复", "بدون Pro تتوفر 3 عملات مجانًا: %@ متوقفة حتى الاشتراك في Pro", "Pro なしで無料の通貨は3つです。%@ は Pro で再び使えます", "Sem o Pro, 3 moedas são grátis: %@ volta com o Pro", "Pro 없이 무료 통화는 3개입니다. %@은(는) Pro로 다시 사용할 수 있습니다", "未訂閱 Pro 時可免費使用 3 種貨幣：%@ 已停用，訂閱 Pro 後恢復", "Senza Pro, 3 valute sono gratuite: %@ torna con Pro", "Bez Pro darmowe są 3 waluty: %@ wróci z Pro"],
        .minTwoCurrencies: ["Нельзя удалить: нужно минимум две валюты", "Can’t delete: at least two currencies are required", "Silinemez: en az iki para birimi gerekli", "Suppression impossible : au moins deux devises sont requises", "No se puede eliminar: se necesitan al menos dos divisas", "Löschen nicht möglich: mindestens zwei Währungen nötig", "无法删除：至少需要两种货币", "لا يمكن الحذف: يلزم عملتان على الأقل", "削除できません。通貨は2つ以上必要です", "Não é possível excluir: são necessárias ao menos duas moedas", "삭제할 수 없습니다. 통화가 최소 2개 필요합니다", "無法刪除：至少需要兩種貨幣", "Impossibile eliminare: servono almeno due valute", "Nie można usunąć: potrzebne są co najmniej dwie waluty"],
        .proOnly: ["Доступно с подпиской Pro", "Available with Pro subscription", "Pro abonelikle kullanılabilir", "Disponible avec l’abonnement Pro", "Disponible con la suscripción Pro", "Mit Pro-Abo verfügbar", "Pro 订阅可用", "متاح مع اشتراك Pro", "Pro サブスクリプションで利用可能", "Disponível com a assinatura Pro", "Pro 구독으로 이용 가능", "Pro 訂閱可用", "Disponibile con l’abbonamento Pro", "Dostępne z subskrypcją Pro"],
        .proDiscover: ["Откройте %@ — валюты без ограничений", "Discover %@ for unlimited currencies", "Sınırsız para birimi için %@’yu keşfedin", "Découvrez %@ pour des devises illimitées", "Descubre %@ para divisas ilimitadas", "Entdecke %@ für unbegrenzte Währungen", "探索 %@，解锁无限货币", "اكتشف %@ لعملات غير محدودة", "%@ で通貨を無制限に", "Descubra o %@ e tenha moedas ilimitadas", "무제한 통화를 위해 %@ 알아보기", "探索 %@，解鎖無限貨幣", "Scopri %@ per valute illimitate", "Poznaj %@ i korzystaj z nieograniczonej liczby walut"],
        .seeDetails: ["Подробнее", "See details", "Ayrıntıları gör", "Voir les détails", "Ver detalles", "Details ansehen", "查看详情", "عرض التفاصيل", "詳細を見る", "Ver detalhes", "자세히 보기", "查看詳情", "Vedi dettagli", "Zobacz szczegóły"],
        .proBecome: ["Перейдите на %@", "Become a %@", "%@ olun", "Passez à %@", "Hazte %@", "Werde %@", "升级到 %@", "اشترك في %@", "%@ にアップグレード", "Assine o %@", "%@로 업그레이드", "升級到 %@", "Passa a %@", "Przejdź na %@"],
        .proSubscription: ["Безлимит валют и вся крипта", "Unlimited currencies and all crypto", "Sınırsız para birimi ve tüm kripto", "Devises illimitées et toutes les cryptos", "Divisas ilimitadas y todas las cripto", "Unbegrenzte Währungen und alle Kryptos", "无限货币和全部加密货币", "عملات بلا حدود وكل العملات المشفرة", "通貨無制限＋すべての暗号資産", "Moedas ilimitadas e todas as criptomoedas", "무제한 통화와 모든 암호화폐", "無限貨幣和全部加密貨幣", "Valute illimitate e tutte le criptovalute", "Nieograniczone waluty i wszystkie kryptowaluty"],
        .upgrade: ["Перейти", "Upgrade", "Yükselt", "Passer", "Mejorar", "Upgrade", "升级", "ترقية", "アップグレード", "Assinar", "업그레이드", "升級", "Passa", "Ulepsz"],
        .proHeadline: ["Полный доступ\nко всем возможностям", "Get unlimited\naccess to all features", "Tüm özelliklere\nsınırsız erişim", "Accès illimité\nà toutes les fonctions", "Acceso ilimitado\na todas las funciones", "Unbegrenzter Zugriff\nauf alle Funktionen", "无限制使用\n全部功能", "وصول غير محدود\nإلى كل الميزات", "すべての機能を\n無制限に利用", "Acesso ilimitado\na todos os recursos", "모든 기능을\n제한 없이", "無限制使用\n全部功能", "Accesso illimitato\na tutte le funzioni", "Nieograniczony dostęp\ndo wszystkich funkcji"],
        .planMonthly: ["Месяц", "Monthly", "Aylık", "Mensuel", "Mensual", "Monatlich", "按月", "شهري", "月額", "Mensal", "월간", "按月", "Mensile", "Miesięcznie"],
        .planYearly: ["Год", "Yearly", "Yıllık", "Annuel", "Anual", "Jährlich", "按年", "سنوي", "年額", "Anual", "연간", "按年", "Annuale", "Rocznie"],
        .planLifetime: ["Навсегда", "Lifetime", "Ömür boyu", "À vie", "De por vida", "Lebenslang", "终身", "مدى الحياة", "買い切り", "Vitalício", "평생", "終身", "A vita", "Dożywotnio"],
        .perMonth: ["%@ / месяц", "%@ / month", "%@ / ay", "%@ / mois", "%@ / mes", "%@ / Monat", "%@ / 月", "%@ / شهر", "%@ / 月", "%@ / mês", "%@ / 월", "%@ / 月", "%@ / mese", "%@ / mies."],
        .perYear: ["%@ / год", "%@ / year", "%@ / yıl", "%@ / an", "%@ / año", "%@ / Jahr", "%@ / 年", "%@ / سنة", "%@ / 年", "%@ / ano", "%@ / 년", "%@ / 年", "%@ / anno", "%@ / rok"],
        .oneTime: ["%@ один раз", "%@ one time", "%@ tek seferlik", "%@ une fois", "%@ un solo pago", "%@ einmalig", "%@ 一次性", "%@ لمرة واحدة", "%@ 買い切り", "%@ pagamento único", "%@ 1회 결제", "%@ 一次性", "%@ una tantum", "%@ jednorazowo"],
        .bestValue: ["ВЫГОДНО", "BEST VALUE", "EN AVANTAJLI", "MEILLEUR PRIX", "MEJOR PRECIO", "BESTER PREIS", "最划算", "أفضل قيمة", "おトク", "MELHOR VALOR", "최고 혜택", "最划算", "MIGLIOR PREZZO", "NAJLEPSZA OFERTA"],
        .included: ["Что входит", "What’s included", "Neler dahil", "Ce qui est inclus", "Qué incluye", "Was enthalten ist", "包含内容", "ما المضمَّن", "含まれるもの", "O que está incluído", "포함 내용", "包含內容", "Cosa include", "Co zawiera"],
        .featUnlimited: ["Без ограничения на число валют", "Unlimited currencies in your list", "Listende sınırsız para birimi", "Devises illimitées dans la liste", "Divisas ilimitadas en tu lista", "Unbegrenzt viele Währungen", "列表中货币数量不限", "عملات غير محدودة في قائمتك", "リストの通貨数が無制限", "Moedas ilimitadas na sua lista", "목록의 통화 수 무제한", "列表中貨幣數量不限", "Valute illimitate nell’elenco", "Nieograniczona liczba walut na liście"],
        .featFiat: ["Все фиатные валюты", "All fiat currencies", "Tüm itibari para birimleri", "Toutes les devises", "Todas las divisas", "Alle Fiatwährungen", "所有法定货币", "كل العملات الورقية", "すべての法定通貨", "Todas as moedas fiduciárias", "모든 법정화폐", "所有法定貨幣", "Tutte le valute fiat", "Wszystkie waluty fiat"],
        .featCrypto: ["Все криптовалюты", "All cryptocurrencies", "Tüm kripto paralar", "Toutes les cryptomonnaies", "Todas las criptomonedas", "Alle Kryptowährungen", "所有加密货币", "كل العملات المشفّرة", "すべての暗号資産", "Todas as criptomoedas", "모든 암호화폐", "所有加密貨幣", "Tutte le criptovalute", "Wszystkie kryptowaluty"],
        .featSupport: ["Поддержка развития приложения", "Support the app’s development", "Uygulamanın gelişimine destek", "Soutenir le développement", "Apoya el desarrollo de la app", "Unterstütze die Entwicklung", "支持应用的开发", "ادعم تطوير التطبيق", "アプリの開発を応援", "Apoie o desenvolvimento do app", "앱 개발 지원", "支持 App 的開發", "Sostieni lo sviluppo dell’app", "Wesprzyj rozwój aplikacji"],
        .trialNote: ["7 дней бесплатно, отмена в любой момент", "7-day free trial, cancel anytime", "7 gün ücretsiz, istediğin zaman iptal", "7 jours gratuits, sans engagement", "7 días gratis, cancela cuando quieras", "7 Tage gratis, jederzeit kündbar", "免费试用 7 天，可随时取消", "7 أيام مجانًا، ألغِ في أي وقت", "7日間無料、いつでもキャンセル可能", "7 dias grátis, cancele quando quiser", "7일 무료, 언제든지 취소 가능", "免費試用 7 天，隨時可取消", "7 giorni gratis, annulla quando vuoi", "7 dni za darmo, anuluj w dowolnej chwili"],
        .startTrial: ["Попробовать бесплатно", "Start Free Trial", "Ücretsiz Denemeyi Başlat", "Commencer l’essai gratuit", "Empezar prueba gratis", "Gratis testen", "开始免费试用", "ابدأ التجربة المجانية", "無料で試す", "Começar teste grátis", "무료 체험 시작", "開始免費試用", "Inizia la prova gratuita", "Rozpocznij bezpłatny okres próbny"],
        .appIcon: ["Иконка приложения", "App Icon", "Uygulama Simgesi", "Icône de l’app", "Icono de la app", "App-Symbol", "应用图标", "أيقونة التطبيق", "アプリアイコン", "Ícone do app", "앱 아이콘", "App 圖示", "Icona dell’app", "Ikona aplikacji"],
        .iconChrome: ["Хром", "Chrome", "Krom", "Chrome", "Cromo", "Chrom", "铬", "كروم", "クローム", "Cromo", "크롬", "鉻", "Cromo", "Chrom"],
        .iconKnit: ["Вязка", "Knit", "Örgü", "Tricot", "Punto", "Strick", "针织", "تريكو", "ニット", "Tricô", "니트", "針織", "Maglia", "Dzianina"],
        .iconRubber: ["Резина", "Rubber", "Kauçuk", "Caoutchouc", "Goma", "Gummi", "橡胶", "مطاط", "ラバー", "Borracha", "고무", "橡膠", "Gomma", "Guma"],
        .iconStone: ["Камень", "Stone", "Taş", "Pierre", "Piedra", "Stein", "石头", "حجر", "ストーン", "Pedra", "돌", "石頭", "Pietra", "Kamień"],
        .iconBlocks: ["Кубики", "Blocks", "Bloklar", "Blocs", "Bloques", "Bausteine", "积木", "مكعبات", "ブロック", "Blocos", "블록", "積木", "Blocchi", "Klocki"],
        .iconDoodle: ["Рисунок", "Doodle", "Karalama", "Gribouillis", "Garabato", "Kritzel", "涂鸦", "رسمة", "落書き", "Rabisco", "낙서", "塗鴉", "Scarabocchio", "Bazgroły"],
        .iconPixel: ["Пиксели", "Pixel", "Piksel", "Pixel", "Píxel", "Pixel", "像素", "بكسل", "ピクセル", "Pixel", "픽셀", "像素", "Pixel", "Piksele"],
        .iconEngraving: ["Гравюра", "Engraving", "Gravür", "Gravure", "Grabado", "Gravur", "版画", "نقش", "版画", "Gravura", "판화", "版畫", "Incisione", "Rycina"],
        .iconAmethyst: ["Аметист", "Amethyst", "Ametist", "Améthyste", "Amatista", "Amethyst", "紫晶", "جمشت", "アメジスト", "Ametista", "자수정", "紫水晶", "Ametista", "Ametyst"],
        .iconSticker: ["Стикер", "Sticker", "Çıkartma", "Autocollant", "Pegatina", "Sticker", "贴纸", "ملصق", "ステッカー", "Adesivo", "스티커", "貼紙", "Adesivo", "Naklejka"],
        .iconPuffy: ["Пышный", "Puffy", "Kabarık", "Gonflé", "Inflado", "Aufgeblasen", "蓬松", "منفوخ", "ぷっくり", "Inflado", "퐁실", "蓬鬆", "Gonfio", "Napompowany"],
        .iconSponge: ["Губка", "Sponge", "Sünger", "Éponge", "Esponja", "Schwamm", "海绵", "إسفنج", "スポンジ", "Esponja", "스펀지", "海綿", "Spugna", "Gąbka"],
        .iconPlush: ["Плюш", "Plush", "Pelüş", "Peluche", "Peluche", "Plüsch", "毛绒", "قطيفة", "ぬいぐるみ", "Pelúcia", "플러시", "毛絨", "Peluche", "Pluszak"],
        .iconGummy: ["Мармелад", "Gummy", "Jelibon", "Bonbon", "Gominola", "Gummi", "软糖", "حلوى", "グミ", "Gelatina", "젤리", "軟糖", "Gommoso", "Żelka"],
        .iconBubbles: ["Пузыри", "Bubbles", "Kabarcık", "Bulles", "Burbujas", "Blasen", "气泡", "فقاعات", "バブル", "Bolhas", "버블", "氣泡", "Bolle", "Bąbelki"],
        .iconHolo: ["Голограмма", "Holo", "Hologram", "Holo", "Holo", "Holo", "镭射", "هولوغرام", "ホログラム", "Holo", "홀로그램", "雷射", "Olografico", "Holo"],
        .termsPrivacy: ["Условия и конфиденциальность", "Terms & Privacy", "Şartlar ve Gizlilik", "Conditions et confidentialité", "Términos y privacidad", "Bedingungen & Datenschutz", "条款与隐私", "الشروط والخصوصية", "利用規約とプライバシー", "Termos e privacidade", "약관 및 개인정보", "條款與隱私權", "Termini e privacy", "Warunki i prywatność"],
        .rateApp: ["Оценить приложение", "Rate the App", "Uygulamayı Değerlendir", "Noter l’app", "Valorar la app", "App bewerten", "给应用评分", "قيّم التطبيق", "アプリを評価", "Avaliar o app", "앱 평가하기", "為 App 評分", "Valuta l’app", "Oceń aplikację"],
        .manageSubscription: ["Управлять", "Manage", "Yönet", "Gérer", "Gestionar", "Verwalten", "管理", "إدارة", "管理", "Gerenciar", "관리", "管理", "Gestisci", "Zarządzaj"],
        .proActive: ["Pro активен", "Pro is active", "Pro etkin", "Pro est actif", "Pro está activo", "Pro ist aktiv", "Pro 已启用", "Pro مُفعّل", "Pro は有効です", "Pro ativo", "Pro 사용 중", "Pro 已啟用", "Pro attivo", "Pro jest aktywne"],
        .support: ["Поддержка", "Support", "Destek", "Assistance", "Soporte", "Support", "支持", "الدعم", "サポート", "Suporte", "지원", "支援", "Assistenza", "Pomoc"],
        .getFullAccess: ["Получить полный доступ", "Get Full Access", "Tam Erişim Al", "Obtenir l’accès complet", "Obtener acceso completo", "Vollzugriff erhalten", "获取完整权限", "احصل على الوصول الكامل", "フルアクセスを取得", "Obter acesso completo", "전체 이용권 받기", "取得完整權限", "Ottieni l’accesso completo", "Uzyskaj pełny dostęp"],
        .terms: ["Условия", "Terms of Use", "Kullanım Şartları", "Conditions", "Términos", "Nutzungsbedingungen", "使用条款", "شروط الاستخدام", "利用規約", "Termos de Uso", "이용 약관", "使用條款", "Termini di utilizzo", "Warunki użytkowania"],
        .privacy: ["Конфиденциальность", "Privacy Policy", "Gizlilik", "Confidentialité", "Privacidad", "Datenschutz", "隐私政策", "الخصوصية", "プライバシーポリシー", "Política de Privacidade", "개인정보 처리방침", "隱私權政策", "Informativa sulla privacy", "Polityka prywatności"],
        .restore: ["Восстановить", "Restore", "Geri Yükle", "Restaurer", "Restaurar", "Wiederherstellen", "恢复购买", "استعادة", "購入を復元", "Restaurar", "복원", "恢復購買", "Ripristina", "Przywróć"],
        .example: ["Пример", "Example", "Örnek", "Exemple", "Ejemplo", "Beispiel", "示例", "مثال", "例", "Exemplo", "예시", "範例", "Esempio", "Przykład"],
        .rates: ["Курсы", "Rates", "Kurlar", "Taux", "Tipos", "Kurse", "汇率", "الأسعار", "レート", "Cotações", "환율", "匯率", "Tassi", "Kursy"],
        .about: ["О приложении", "About", "Hakkında", "À propos", "Acerca de", "Über", "关于", "حول", "このアプリについて", "Sobre", "정보", "關於", "Informazioni", "O aplikacji"],
        .dataFooter: ["Фиат обновляется раз в сутки, крипта — несколько раз в минуту. Последние курсы доступны без интернета.", "Fiat rates update daily, crypto several times a minute. The latest rates work offline.", "İtibari kurlar günde bir, kripto dakikada birkaç kez güncellenir. Son kurlar çevrimdışı da kullanılabilir.", "Les devises sont mises à jour chaque jour, les cryptos plusieurs fois par minute. Les derniers taux restent disponibles hors ligne.", "Las divisas se actualizan a diario y las criptos varias veces por minuto. Los últimos tipos funcionan sin conexión.", "Fiatkurse werden täglich, Krypto mehrmals pro Minute aktualisiert. Die letzten Kurse sind offline verfügbar.", "法币汇率每天更新，加密货币每分钟更新数次。最新汇率离线也可使用。", "تتحدث أسعار العملات النقدية يوميًا والمشفّرة عدة مرات في الدقيقة. تتوفر أحدث الأسعار دون اتصال.", "法定通貨は1日1回、暗号資産は1分間に数回更新されます。最新のレートはオフラインでも使えます。", "As moedas fiduciárias são atualizadas diariamente e as criptomoedas várias vezes por minuto. As cotações mais recentes funcionam offline.", "법정화폐는 하루에 한 번, 암호화폐는 분당 여러 번 업데이트됩니다. 최신 환율은 오프라인에서도 사용할 수 있습니다.", "法幣匯率每天更新，加密貨幣每分鐘更新數次。最新匯率離線時也能使用。", "Le valute fiat si aggiornano ogni giorno, le criptovalute più volte al minuto. Gli ultimi tassi funzionano offline.", "Kursy walut fiat aktualizują się raz dziennie, kryptowalut — kilka razy na minutę. Najnowsze kursy działają offline."],
        .numbers: ["Числа", "Numbers", "Sayılar", "Nombres", "Números", "Zahlen", "数字", "الأرقام", "数字", "Números", "숫자", "數字", "Numeri", "Liczby"],
        .numberFormat: ["Формат", "Format", "Biçim", "Format", "Formato", "Format", "格式", "التنسيق", "形式", "Formato", "형식", "格式", "Formato", "Format"],
        .decimalPlaces: ["Знаков после запятой", "Decimal Places", "Ondalık Basamak", "Décimales", "Decimales", "Nachkommastellen", "小数位数", "المنازل العشرية", "小数点以下の桁数", "Casas decimais", "소수 자릿수", "小數位數", "Cifre decimali", "Miejsca po przecinku"],
        .auto: ["Авто", "Auto", "Otomatik", "Auto", "Auto", "Auto", "自动", "تلقائي", "自動", "Auto", "자동", "自動", "Auto", "Auto"],
        .formatFooter: ["Как показывать суммы в конвертере. Например, 32,16:", "How amounts appear in the converter. For example, 32.16:", "Tutarların dönüştürücüde nasıl görüneceği. Örneğin 32,16:", "Affichage des montants dans le convertisseur. Par exemple, 32,16 :", "Cómo se muestran los importes en el conversor. Por ejemplo, 32,16:", "So werden Beträge im Umrechner angezeigt. Zum Beispiel 32,16:", "金额在换算器中的显示方式。例如 32.16：", "طريقة عرض المبالغ في المحوّل. مثلًا 32.16:", "換算画面での金額の表示形式です。例: 32.16", "Como os valores aparecem no conversor. Por exemplo, 32,16:", "변환기에서 금액이 표시되는 방식입니다. 예: 32.16", "金額在換算器中的顯示方式。例如 32.16：", "Come vengono mostrati gli importi nel convertitore. Ad esempio, 32,16:", "Sposób wyświetlania kwot w przeliczniku. Na przykład 32,16:"],
        .formatAutomatic: ["По языку", "By Language", "Dile Göre", "Selon la langue", "Según el idioma", "Nach Sprache", "跟随语言", "حسب اللغة", "言語に合わせる", "Conforme o idioma", "언어에 따름", "跟隨語言", "In base alla lingua", "Według języka"],
        .formatInternational: ["Международный", "International", "Uluslararası", "International", "Internacional", "International", "国际", "دولي", "国際", "Internacional", "국제", "國際", "Internazionale", "Międzynarodowy"],
        .formatEuropean: ["Европейский", "European", "Avrupa", "Européen", "Europeo", "Europäisch", "欧洲", "أوروبي", "ヨーロッパ", "Europeu", "유럽", "歐洲", "Europeo", "Europejski"],
        .formatSpaced: ["С пробелами", "With Spaces", "Boşluklu", "Avec espaces", "Con espacios", "Mit Leerzeichen", "带空格", "بمسافات", "スペース区切り", "Com espaços", "공백 포함", "帶空格", "Con spazi", "Ze spacjami"],
        .errNoInternet: ["нет подключения к интернету.", "no internet connection.", "internet bağlantısı yok.", "pas de connexion Internet.", "no hay conexión a Internet.", "keine Internetverbindung.", "没有网络连接。", "لا يوجد اتصال بالإنترنت.", "インターネットに接続されていません。", "sem conexão com a internet.", "인터넷에 연결되어 있지 않습니다.", "沒有網路連線。", "nessuna connessione a Internet.", "brak połączenia z internetem."],
        .errTimeout: ["сервер не ответил вовремя.", "the server didn’t respond in time.", "sunucu zamanında yanıt vermedi.", "le serveur n’a pas répondu à temps.", "el servidor no respondió a tiempo.", "der Server hat nicht rechtzeitig geantwortet.", "服务器未及时响应。", "لم يستجب الخادم في الوقت المحدد.", "サーバーの応答がありませんでした。", "o servidor não respondeu a tempo.", "서버가 제시간에 응답하지 않았습니다.", "伺服器未及時回應。", "il server non ha risposto in tempo.", "serwer nie odpowiedział na czas."],
        .errServer: ["не удалось связаться с сервером.", "couldn’t reach the server.", "sunucuya ulaşılamadı.", "impossible de joindre le serveur.", "no se pudo conectar con el servidor.", "Server nicht erreichbar.", "无法连接服务器。", "تعذّر الوصول إلى الخادم.", "サーバーに接続できませんでした。", "não foi possível conectar ao servidor.", "서버에 연결할 수 없습니다.", "無法連線至伺服器。", "impossibile raggiungere il server.", "nie udało się połączyć z serwerem."],
        .errRateLimited: ["слишком много запросов, попробуйте через минуту.", "too many requests, try again in a minute.", "çok fazla istek, bir dakika sonra tekrar deneyin.", "trop de requêtes, réessayez dans une minute.", "demasiadas solicitudes, inténtalo en un minuto.", "zu viele Anfragen, in einer Minute erneut versuchen.", "请求过多，请一分钟后重试。", "طلبات كثيرة جدًا، حاول بعد دقيقة.", "リクエストが多すぎます。1分後にもう一度お試しください。", "muitas solicitações, tente novamente em um minuto.", "요청이 너무 많습니다. 1분 후에 다시 시도하세요.", "請求過多，請於一分鐘後再試。", "troppe richieste, riprova tra un minuto.", "zbyt wiele żądań, spróbuj ponownie za minutę."],
        .errBadResponse: ["сервер вернул некорректный ответ.", "the server returned an invalid response.", "sunucu geçersiz yanıt döndürdü.", "le serveur a renvoyé une réponse non valide.", "el servidor devolvió una respuesta no válida.", "der Server hat eine ungültige Antwort gesendet.", "服务器返回了无效的响应。", "أعاد الخادم استجابة غير صالحة.", "サーバーから無効な応答が返されました。", "o servidor retornou uma resposta inválida.", "서버가 잘못된 응답을 반환했습니다.", "伺服器傳回了無效的回應。", "il server ha restituito una risposta non valida.", "serwer zwrócił nieprawidłową odpowiedź."],
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
