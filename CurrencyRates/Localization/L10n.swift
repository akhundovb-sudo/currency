import Foundation

/// Язык интерфейса, выбираемый в настройках.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case ru, en, tr, fr, es, de, zh, ar

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
        case .zh: "中文"
        case .ar: "العربية"
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
        case .zh: Locale(identifier: "zh_Hans_CN")
        case .ar: Locale(identifier: "ar_AE@numbers=latn")  // латинские цифры, как на клавиатуре
        }
    }

    /// Арабский пишется справа налево.
    var isRightToLeft: Bool { self == .ar
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
        case minTwoCurrencies, proOnly, proDiscover, seeDetails, proTest, proSuspended
        case numbers, numberFormat, decimalPlaces, auto, formatFooter
        case example, rates, about, dataFooter
        case proBecome, proSubscription, upgrade
        case proHeadline, planMonthly, planYearly, planLifetime, perMonth, perYear, oneTime
        case bestValue, included, featUnlimited, featFiat, featCrypto, featSupport
        case rateApp, manageSubscription, proActive, support, termsPrivacy
        case appIcon, iconChrome, iconKnit, iconRubber, iconStone, iconBlocks, iconDoodle, iconAmethyst, iconSticker, iconPuffy, iconSponge, iconPlush, iconGummy, iconBubbles, iconHolo
        case getFullAccess, startTrial, trialNote, terms, privacy, restore
        case formatAutomatic, formatInternational, formatEuropean, formatSpaced
        case errNoInternet, errTimeout, errServer, errRateLimited, errBadResponse
    }

    // ru, en, tr, fr, es, de, zh, ar
    private static let table: [Key: [String]] = [
        .title: ["Валюты", "Currencies", "Para Birimleri", "Devises", "Divisas", "Währungen", "货币", "العملات"],
        .settings: ["Настройки", "Settings", "Ayarlar", "Réglages", "Ajustes", "Einstellungen", "设置", "الإعدادات"],
        .edit: ["Править", "Edit", "Düzenle", "Modifier", "Editar", "Bearbeiten", "编辑", "تعديل"],
        .done: ["Готово", "Done", "Bitti", "OK", "OK", "Fertig", "完成", "تم"],
        .close: ["Закрыть", "Close", "Kapat", "Fermer", "Cerrar", "Schließen", "关闭", "إغلاق"],
        .delete: ["Удалить", "Delete", "Sil", "Supprimer", "Eliminar", "Löschen", "删除", "حذف"],
        .addCurrency: ["Добавить валюту", "Add Currency", "Para Birimi Ekle", "Ajouter une devise", "Añadir divisa", "Währung hinzufügen", "添加货币", "إضافة عملة"],
        .updateFailed: ["Не удалось обновить курсы", "Couldn’t update rates", "Kurlar güncellenemedi", "Impossible de mettre à jour les taux", "No se pudieron actualizar los tipos", "Kurse konnten nicht aktualisiert werden", "无法更新汇率", "تعذّر تحديث الأسعار"],
        .retry: ["Повторить загрузку", "Try Again", "Tekrar Dene", "Réessayer", "Reintentar", "Erneut versuchen", "重试", "إعادة المحاولة"],
        .loading: ["Загрузка курсов…", "Loading rates…", "Kurlar yükleniyor…", "Chargement des taux…", "Cargando tipos…", "Kurse werden geladen…", "正在加载汇率…", "جارٍ تحميل الأسعار…"],
        .demoData: ["Демонстрационные данные, не реальные курсы", "Demo data, not real rates", "Demo veriler, gerçek kurlar değil", "Données de démonstration, pas de vrais taux", "Datos de demostración, no son tipos reales", "Demodaten, keine echten Kurse", "演示数据，并非真实汇率", "بيانات تجريبية وليست أسعارًا حقيقية"],
        .fiatShort: ["Фиат", "Fiat", "İtibari", "Fiat", "Fiat", "Fiat", "法币", "نقدية"],
        .cryptoShort: ["Крипта", "Crypto", "Kripto", "Crypto", "Cripto", "Krypto", "加密", "مشفّرة"],
        .notLoaded: ["Курсы ещё не загружены.", "Rates haven’t loaded yet.", "Kurlar henüz yüklenmedi.", "Les taux ne sont pas encore chargés.", "Los tipos aún no se han cargado.", "Kurse wurden noch nicht geladen.", "汇率尚未加载。", "لم يتم تحميل الأسعار بعد."],
        .updatedAt: ["Обновлено: %@", "Updated: %@", "Güncellendi: %@", "Mis à jour : %@", "Actualizado: %@", "Aktualisiert: %@", "更新于：%@", "آخر تحديث: %@"],
        .cachedAt: ["Сохранённые данные, загружены %@", "Saved data, loaded %@", "Kayıtlı veriler, yüklenme: %@", "Données enregistrées, chargées le %@", "Datos guardados, cargados el %@", "Gespeicherte Daten, geladen am %@", "已保存的数据，加载于 %@", "بيانات محفوظة، حُمّلت في %@"],
        .longPressClears: ["Долгое нажатие очищает сумму", "Long press clears the amount", "Uzun basmak tutarı siler", "Un appui long efface le montant", "Mantén pulsado para borrar el importe", "Langes Drücken löscht den Betrag", "长按可清除金额", "اضغط مطولًا لمسح المبلغ"],
        .comma: ["Запятая", "Decimal point", "Ondalık ayırıcı", "Virgule", "Coma decimal", "Komma", "小数点", "الفاصلة العشرية"],
        .erase: ["Стереть", "Delete", "Sil", "Effacer", "Borrar", "Löschen", "删除", "حذف"],
        .plus: ["Плюс", "Plus", "Artı", "Plus", "Más", "Plus", "加", "زائد"],
        .minus: ["Минус", "Minus", "Eksi", "Moins", "Menos", "Minus", "减", "ناقص"],
        .multiply: ["Умножить", "Multiply", "Çarp", "Multiplier", "Multiplicar", "Mal", "乘", "ضرب"],
        .divide: ["Разделить", "Divide", "Böl", "Diviser", "Dividir", "Geteilt", "除", "قسمة"],
        .equals: ["Равно", "Equals", "Eşittir", "Égal", "Igual", "Gleich", "等于", "يساوي"],
        .hideKeyboard: ["Скрыть клавиатуру", "Hide Keyboard", "Klavyeyi Gizle", "Masquer le clavier", "Ocultar teclado", "Tastatur ausblenden", "隐藏键盘", "إخفاء لوحة المفاتيح"],
        .alreadyAdded: ["Уже в списке", "Already in the list", "Zaten listede", "Déjà dans la liste", "Ya está en la lista", "Bereits in der Liste", "已在列表中", "موجودة في القائمة"],
        .addToList: ["Добавить в список", "Add to the list", "Listeye ekle", "Ajouter à la liste", "Añadir a la lista", "Zur Liste hinzufügen", "添加到列表", "إضافة إلى القائمة"],
        .nothingFound: ["Ничего не найдено", "No Results", "Sonuç Yok", "Aucun résultat", "Sin resultados", "Keine Ergebnisse", "无结果", "لا توجد نتائج"],
        .noResults: ["Нет валют по запросу «%@».", "No currencies match “%@”.", "“%@” ile eşleşen para birimi yok.", "Aucune devise ne correspond à « %@ ».", "Ninguna divisa coincide con «%@».", "Keine Währung passt zu „%@“.", "没有与“%@”匹配的货币。", "لا توجد عملات تطابق «%@»."],
        .searchPrompt: ["Код или название", "Code or name", "Kod veya ad", "Code ou nom", "Código o nombre", "Code oder Name", "代码或名称", "الرمز أو الاسم"],
        .currencyType: ["Тип валюты", "Currency type", "Para birimi türü", "Type de devise", "Tipo de divisa", "Währungstyp", "货币类型", "نوع العملة"],
        .sourceHint: ["Сумма вводится в этой валюте", "The amount is entered in this currency", "Tutar bu para biriminde giriliyor", "Le montant est saisi dans cette devise", "El importe se introduce en esta divisa", "Der Betrag wird in dieser Währung eingegeben", "金额以此货币输入", "يُدخل المبلغ بهذه العملة"],
        .enterHint: ["Ввести сумму в этой валюте", "Enter the amount in this currency", "Tutarı bu para biriminde gir", "Saisir le montant dans cette devise", "Introducir el importe en esta divisa", "Betrag in dieser Währung eingeben", "以此货币输入金额", "أدخل المبلغ بهذه العملة"],
        .enteredAmount: ["Вводимая сумма", "Amount entered", "Girilen tutar", "Montant saisi", "Importe introducido", "Eingegebener Betrag", "输入的金额", "المبلغ المُدخل"],
        .noRate: ["Нет курса", "No rate", "Kur yok", "Pas de taux", "Sin tipo", "Kein Kurs", "无汇率", "لا يوجد سعر"],
        .appearance: ["Оформление", "Appearance", "Görünüm", "Apparence", "Apariencia", "Darstellung", "外观", "المظهر"],
        .theme: ["Тема", "Theme", "Tema", "Thème", "Tema", "Design", "主题", "السمة"],
        .language: ["Язык", "Language", "Dil", "Langue", "Idioma", "Sprache", "语言", "اللغة"],
        .source: ["Источник", "Source", "Kaynak", "Source", "Fuente", "Quelle", "来源", "المصدر"],
        .updated: ["Обновлено", "Updated", "Güncellendi", "Mis à jour", "Actualizado", "Aktualisiert", "更新时间", "آخر تحديث"],
        .fiatCurrencies: ["Фиатные валюты", "Fiat currencies", "İtibari paralar", "Devises fiduciaires", "Divisas fiduciarias", "Fiatwährungen", "法定货币", "العملات النقدية"],
        .fiatFooter: ["Поставщик обновляет курсы раз в сутки.", "The provider updates rates once a day.", "Sağlayıcı kurları günde bir kez günceller.", "Le fournisseur met à jour les taux une fois par jour.", "El proveedor actualiza los tipos una vez al día.", "Der Anbieter aktualisiert die Kurse einmal täglich.", "提供方每天更新一次汇率。", "يحدّث المزوّد الأسعار مرة يوميًا."],
        .cryptoCurrencies: ["Криптовалюты", "Cryptocurrencies", "Kripto paralar", "Cryptomonnaies", "Criptomonedas", "Kryptowährungen", "加密货币", "العملات المشفّرة"],
        .cryptoFooter: ["Цены обновляются несколько раз в минуту.", "Prices update several times a minute.", "Fiyatlar dakikada birkaç kez güncellenir.", "Les prix sont mis à jour plusieurs fois par minute.", "Los precios se actualizan varias veces por minuto.", "Preise werden mehrmals pro Minute aktualisiert.", "价格每分钟更新数次。", "تتحدث الأسعار عدة مرات في الدقيقة."],
        .refreshRates: ["Обновить курсы", "Refresh Rates", "Kurları Yenile", "Actualiser les taux", "Actualizar tipos", "Kurse aktualisieren", "刷新汇率", "تحديث الأسعار"],
        .offlineFooter: ["Последние загруженные курсы сохраняются на устройстве и доступны без интернета.", "The latest rates are saved on the device and available offline.", "Son yüklenen kurlar cihazda saklanır ve internetsiz kullanılabilir.", "Les derniers taux sont enregistrés sur l’appareil et disponibles hors ligne.", "Los últimos tipos se guardan en el dispositivo y están disponibles sin conexión.", "Die letzten Kurse werden auf dem Gerät gespeichert und sind offline verfügbar.", "最新汇率保存在设备上，离线也可使用。", "تُحفظ أحدث الأسعار على الجهاز وتتوفر دون اتصال."],
        .version: ["Версия", "Version", "Sürüm", "Version", "Versión", "Version", "版本", "الإصدار"],
        .noData: ["Нет данных", "No data", "Veri yok", "Aucune donnée", "Sin datos", "Keine Daten", "无数据", "لا توجد بيانات"],
        .demoShort: ["Демо-данные", "Demo data", "Demo veriler", "Données de démo", "Datos de demo", "Demodaten", "演示数据", "بيانات تجريبية"],
        .themeSystem: ["Системная", "System", "Sistem", "Système", "Sistema", "System", "跟随系统", "النظام"],
        .themeLight: ["Светлая", "Light", "Açık", "Clair", "Claro", "Hell", "浅色", "فاتح"],
        .themeDark: ["Тёмная", "Dark", "Koyu", "Sombre", "Oscuro", "Dunkel", "深色", "داكن"],
        .proSuspended: ["Pro закончился: валюты Pro отключены и вернутся с подпиской", "Pro has ended: Pro currencies are off until you renew", "Pro sona erdi: Pro para birimleri yenileyene kadar kapalı", "Pro a expiré : les devises Pro reviendront au renouvellement", "Pro ha terminado: las divisas Pro volverán al renovar", "Pro ist abgelaufen: Pro-Währungen kehren nach Verlängerung zurück", "Pro 已到期：Pro 货币已停用，续订后恢复", "انتهى Pro: عملات Pro متوقفة حتى التجديد"],
        .minTwoCurrencies: ["Нельзя удалить: нужно минимум две валюты", "Can’t delete: at least two currencies are required", "Silinemez: en az iki para birimi gerekli", "Suppression impossible : au moins deux devises sont requises", "No se puede eliminar: se necesitan al menos dos divisas", "Löschen nicht möglich: mindestens zwei Währungen nötig", "无法删除：至少需要两种货币", "لا يمكن الحذف: يلزم عملتان على الأقل"],
        .proOnly: ["Доступно с подпиской Pro", "Available with Pro subscription", "Pro abonelikle kullanılabilir", "Disponible avec l’abonnement Pro", "Disponible con la suscripción Pro", "Mit Pro-Abo verfügbar", "Pro 订阅可用", "متاح مع اشتراك Pro"],
        .proDiscover: ["Откройте %@ — валюты без ограничений", "Discover %@ for unlimited currencies", "Sınırsız para birimi için %@’yu keşfedin", "Découvrez %@ pour des devises illimitées", "Descubre %@ para divisas ilimitadas", "Entdecke %@ für unbegrenzte Währungen", "探索 %@，解锁无限货币", "اكتشف %@ لعملات غير محدودة"],
        .seeDetails: ["Подробнее", "See details", "Ayrıntıları gör", "Voir les détails", "Ver detalles", "Details ansehen", "查看详情", "عرض التفاصيل"],
        .proBecome: ["Перейдите на %@", "Become a %@", "%@ olun", "Passez à %@", "Hazte %@", "Werde %@", "升级到 %@", "اشترك في %@"],
        .proSubscription: ["Безлимит валют и вся крипта", "Unlimited currencies and all crypto", "Sınırsız para birimi ve tüm kripto", "Devises illimitées et toutes les cryptos", "Divisas ilimitadas y todas las cripto", "Unbegrenzte Währungen und alle Kryptos", "无限货币和全部加密货币", "عملات بلا حدود وكل العملات المشفرة"],
        .upgrade: ["Перейти", "Upgrade", "Yükselt", "Passer", "Mejorar", "Upgrade", "升级", "ترقية"],
        .proHeadline: ["Полный доступ\nко всем возможностям", "Get unlimited\naccess to all features", "Tüm özelliklere\nsınırsız erişim", "Accès illimité\nà toutes les fonctions", "Acceso ilimitado\na todas las funciones", "Unbegrenzter Zugriff\nauf alle Funktionen", "无限制使用\n全部功能", "وصول غير محدود\nإلى كل الميزات"],
        .planMonthly: ["Месяц", "Monthly", "Aylık", "Mensuel", "Mensual", "Monatlich", "按月", "شهري"],
        .planYearly: ["Год", "Yearly", "Yıllık", "Annuel", "Anual", "Jährlich", "按年", "سنوي"],
        .planLifetime: ["Навсегда", "Lifetime", "Ömür boyu", "À vie", "De por vida", "Lebenslang", "终身", "مدى الحياة"],
        .perMonth: ["%@ / месяц", "%@ / month", "%@ / ay", "%@ / mois", "%@ / mes", "%@ / Monat", "%@ / 月", "%@ / شهر"],
        .perYear: ["%@ / год", "%@ / year", "%@ / yıl", "%@ / an", "%@ / año", "%@ / Jahr", "%@ / 年", "%@ / سنة"],
        .oneTime: ["%@ один раз", "%@ one time", "%@ tek seferlik", "%@ une fois", "%@ un solo pago", "%@ einmalig", "%@ 一次性", "%@ لمرة واحدة"],
        .bestValue: ["ВЫГОДНО", "BEST VALUE", "EN AVANTAJLI", "MEILLEUR PRIX", "MEJOR PRECIO", "BESTER PREIS", "最划算", "أفضل قيمة"],
        .included: ["Что входит", "What’s included", "Neler dahil", "Ce qui est inclus", "Qué incluye", "Was enthalten ist", "包含内容", "ما المضمَّن"],
        .featUnlimited: ["Без ограничения на число валют", "Unlimited currencies in your list", "Listende sınırsız para birimi", "Devises illimitées dans la liste", "Divisas ilimitadas en tu lista", "Unbegrenzt viele Währungen", "列表中货币数量不限", "عملات غير محدودة في قائمتك"],
        .featFiat: ["Все фиатные валюты", "All fiat currencies", "Tüm itibari para birimleri", "Toutes les devises", "Todas las divisas", "Alle Fiatwährungen", "所有法定货币", "كل العملات الورقية"],
        .featCrypto: ["Все криптовалюты", "All cryptocurrencies", "Tüm kripto paralar", "Toutes les cryptomonnaies", "Todas las criptomonedas", "Alle Kryptowährungen", "所有加密货币", "كل العملات المشفّرة"],
        .featSupport: ["Поддержка развития приложения", "Support the app’s development", "Uygulamanın gelişimine destek", "Soutenir le développement", "Apoya el desarrollo de la app", "Unterstütze die Entwicklung", "支持应用的开发", "ادعم تطوير التطبيق"],
        .trialNote: ["7 дней бесплатно, отмена в любой момент", "7-day free trial, cancel anytime", "7 gün ücretsiz, istediğin zaman iptal", "7 jours gratuits, sans engagement", "7 días gratis, cancela cuando quieras", "7 Tage gratis, jederzeit kündbar", "免费试用 7 天，可随时取消", "7 أيام مجانًا، ألغِ في أي وقت"],
        .startTrial: ["Попробовать бесплатно", "Start Free Trial", "Ücretsiz Denemeyi Başlat", "Commencer l’essai gratuit", "Empezar prueba gratis", "Gratis testen", "开始免费试用", "ابدأ التجربة المجانية"],
        .appIcon: ["Иконка приложения", "App Icon", "Uygulama Simgesi", "Icône de l’app", "Icono de la app", "App-Symbol", "应用图标", "أيقونة التطبيق"],
        .iconChrome: ["Хром", "Chrome", "Krom", "Chrome", "Cromo", "Chrom", "铬", "كروم"],
        .iconKnit: ["Вязка", "Knit", "Örgü", "Tricot", "Punto", "Strick", "针织", "تريكو"],
        .iconRubber: ["Резина", "Rubber", "Kauçuk", "Caoutchouc", "Goma", "Gummi", "橡胶", "مطاط"],
        .iconStone: ["Камень", "Stone", "Taş", "Pierre", "Piedra", "Stein", "石头", "حجر"],
        .iconBlocks: ["Кубики", "Blocks", "Bloklar", "Blocs", "Bloques", "Bausteine", "积木", "مكعبات"],
        .iconDoodle: ["Рисунок", "Doodle", "Karalama", "Gribouillis", "Garabato", "Kritzel", "涂鸦", "رسمة"],
        .iconAmethyst: ["Аметист", "Amethyst", "Ametist", "Améthyste", "Amatista", "Amethyst", "紫晶", "جمشت"],
        .iconSticker: ["Стикер", "Sticker", "Çıkartma", "Autocollant", "Pegatina", "Sticker", "贴纸", "ملصق"],
        .iconPuffy: ["Пышный", "Puffy", "Kabarık", "Gonflé", "Inflado", "Aufgeblasen", "蓬松", "منفوخ"],
        .iconSponge: ["Губка", "Sponge", "Sünger", "Éponge", "Esponja", "Schwamm", "海绵", "إسفنج"],
        .iconPlush: ["Плюш", "Plush", "Pelüş", "Peluche", "Peluche", "Plüsch", "毛绒", "قطيفة"],
        .iconGummy: ["Мармелад", "Gummy", "Jelibon", "Bonbon", "Gominola", "Gummi", "软糖", "حلوى"],
        .iconBubbles: ["Пузыри", "Bubbles", "Kabarcık", "Bulles", "Burbujas", "Blasen", "气泡", "فقاعات"],
        .iconHolo: ["Голограмма", "Holo", "Hologram", "Holo", "Holo", "Holo", "镭射", "هولوغرام"],
        .termsPrivacy: ["Условия и конфиденциальность", "Terms & Privacy", "Şartlar ve Gizlilik", "Conditions et confidentialité", "Términos y privacidad", "Bedingungen & Datenschutz", "条款与隐私", "الشروط والخصوصية"],
        .rateApp: ["Оценить приложение", "Rate the App", "Uygulamayı Değerlendir", "Noter l’app", "Valorar la app", "App bewerten", "给应用评分", "قيّم التطبيق"],
        .manageSubscription: ["Управлять", "Manage", "Yönet", "Gérer", "Gestionar", "Verwalten", "管理", "إدارة"],
        .proActive: ["Pro активен", "Pro is active", "Pro etkin", "Pro est actif", "Pro está activo", "Pro ist aktiv", "Pro 已启用", "Pro مُفعّل"],
        .support: ["Поддержка", "Support", "Destek", "Assistance", "Soporte", "Support", "支持", "الدعم"],
        .getFullAccess: ["Получить полный доступ", "Get Full Access", "Tam Erişim Al", "Obtenir l’accès complet", "Obtener acceso completo", "Vollzugriff erhalten", "获取完整权限", "احصل على الوصول الكامل"],
        .terms: ["Условия", "Terms of Use", "Kullanım Şartları", "Conditions", "Términos", "Nutzungsbedingungen", "使用条款", "شروط الاستخدام"],
        .privacy: ["Конфиденциальность", "Privacy Policy", "Gizlilik", "Confidentialité", "Privacidad", "Datenschutz", "隐私政策", "الخصوصية"],
        .restore: ["Восстановить", "Restore", "Geri Yükle", "Restaurer", "Restaurar", "Wiederherstellen", "恢复购买", "استعادة"],
        .example: ["Пример", "Example", "Örnek", "Exemple", "Ejemplo", "Beispiel", "示例", "مثال"],
        .rates: ["Курсы", "Rates", "Kurlar", "Taux", "Tipos", "Kurse", "汇率", "الأسعار"],
        .about: ["О приложении", "About", "Hakkında", "À propos", "Acerca de", "Über", "关于", "حول"],
        .dataFooter: ["Фиат обновляется раз в сутки, крипта — несколько раз в минуту. Последние курсы доступны без интернета.", "Fiat rates update daily, crypto several times a minute. The latest rates work offline.", "İtibari kurlar günde bir, kripto dakikada birkaç kez güncellenir. Son kurlar çevrimdışı da kullanılabilir.", "Les devises sont mises à jour chaque jour, les cryptos plusieurs fois par minute. Les derniers taux restent disponibles hors ligne.", "Las divisas se actualizan a diario y las criptos varias veces por minuto. Los últimos tipos funcionan sin conexión.", "Fiatkurse werden täglich, Krypto mehrmals pro Minute aktualisiert. Die letzten Kurse sind offline verfügbar.", "法币汇率每天更新，加密货币每分钟更新数次。最新汇率离线也可使用。", "تتحدث أسعار العملات النقدية يوميًا والمشفّرة عدة مرات في الدقيقة. تتوفر أحدث الأسعار دون اتصال."],
        .numbers: ["Числа", "Numbers", "Sayılar", "Nombres", "Números", "Zahlen", "数字", "الأرقام"],
        .numberFormat: ["Формат", "Format", "Biçim", "Format", "Formato", "Format", "格式", "التنسيق"],
        .decimalPlaces: ["Знаков после запятой", "Decimal Places", "Ondalık Basamak", "Décimales", "Decimales", "Nachkommastellen", "小数位数", "المنازل العشرية"],
        .auto: ["Авто", "Auto", "Otomatik", "Auto", "Auto", "Auto", "自动", "تلقائي"],
        .formatFooter: ["Как показывать суммы в конвертере. Например, 32,16:", "How amounts appear in the converter. For example, 32.16:", "Tutarların dönüştürücüde nasıl görüneceği. Örneğin 32,16:", "Affichage des montants dans le convertisseur. Par exemple, 32,16 :", "Cómo se muestran los importes en el conversor. Por ejemplo, 32,16:", "So werden Beträge im Umrechner angezeigt. Zum Beispiel 32,16:", "金额在换算器中的显示方式。例如 32.16：", "طريقة عرض المبالغ في المحوّل. مثلًا 32.16:"],
        .formatAutomatic: ["По языку", "By Language", "Dile Göre", "Selon la langue", "Según el idioma", "Nach Sprache", "跟随语言", "حسب اللغة"],
        .formatInternational: ["Международный", "International", "Uluslararası", "International", "Internacional", "International", "国际", "دولي"],
        .formatEuropean: ["Европейский", "European", "Avrupa", "Européen", "Europeo", "Europäisch", "欧洲", "أوروبي"],
        .formatSpaced: ["С пробелами", "With Spaces", "Boşluklu", "Avec espaces", "Con espacios", "Mit Leerzeichen", "带空格", "بمسافات"],
        .proTest: ["Pro (для теста)", "Pro (testing)", "Pro (test için)", "Pro (test)", "Pro (prueba)", "Pro (Test)", "Pro（测试）", "Pro (للاختبار)"],
        .errNoInternet: ["нет подключения к интернету.", "no internet connection.", "internet bağlantısı yok.", "pas de connexion Internet.", "no hay conexión a Internet.", "keine Internetverbindung.", "没有网络连接。", "لا يوجد اتصال بالإنترنت."],
        .errTimeout: ["сервер не ответил вовремя.", "the server didn’t respond in time.", "sunucu zamanında yanıt vermedi.", "le serveur n’a pas répondu à temps.", "el servidor no respondió a tiempo.", "der Server hat nicht rechtzeitig geantwortet.", "服务器未及时响应。", "لم يستجب الخادم في الوقت المحدد."],
        .errServer: ["не удалось связаться с сервером.", "couldn’t reach the server.", "sunucuya ulaşılamadı.", "impossible de joindre le serveur.", "no se pudo conectar con el servidor.", "Server nicht erreichbar.", "无法连接服务器。", "تعذّر الوصول إلى الخادم."],
        .errRateLimited: ["слишком много запросов, попробуйте через минуту.", "too many requests, try again in a minute.", "çok fazla istek, bir dakika sonra tekrar deneyin.", "trop de requêtes, réessayez dans une minute.", "demasiadas solicitudes, inténtalo en un minuto.", "zu viele Anfragen, in einer Minute erneut versuchen.", "请求过多，请一分钟后重试。", "طلبات كثيرة جدًا، حاول بعد دقيقة."],
        .errBadResponse: ["сервер вернул некорректный ответ.", "the server returned an invalid response.", "sunucu geçersiz yanıt döndürdü.", "le serveur a renvoyé une réponse non valide.", "el servidor devolvió una respuesta no válida.", "der Server hat eine ungültige Antwort gesendet.", "服务器返回了无效的响应。", "أعاد الخادم استجابة غير صالحة."],
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
