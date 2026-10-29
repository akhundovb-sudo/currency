import Foundation

// Общее для приложения и виджетов: список криптовалют, флаги, форматирование сумм.

/// Поддерживаемые криптовалюты; `id` — идентификатор в CoinGecko.
struct CryptoAsset: Sendable {
    let code: String
    let id: String
    let name: String

    static let all: [CryptoAsset] = [
        .init(code: "BTC", id: "bitcoin", name: "Bitcoin"),
        .init(code: "ETH", id: "ethereum", name: "Ethereum"),
        .init(code: "USDT", id: "tether", name: "Tether"),
        .init(code: "XRP", id: "ripple", name: "XRP"),
        .init(code: "BNB", id: "binancecoin", name: "BNB"),
        .init(code: "SOL", id: "solana", name: "Solana"),
        .init(code: "USDC", id: "usd-coin", name: "USD Coin"),
        .init(code: "DOGE", id: "dogecoin", name: "Dogecoin"),
        .init(code: "TRX", id: "tron", name: "TRON"),
        .init(code: "ADA", id: "cardano", name: "Cardano"),
        .init(code: "TON", id: "the-open-network", name: "Toncoin"),
        .init(code: "LINK", id: "chainlink", name: "Chainlink"),
        .init(code: "AVAX", id: "avalanche-2", name: "Avalanche"),
        .init(code: "XLM", id: "stellar", name: "Stellar"),
        .init(code: "LTC", id: "litecoin", name: "Litecoin"),
        .init(code: "BCH", id: "bitcoin-cash", name: "Bitcoin Cash"),
        .init(code: "DOT", id: "polkadot", name: "Polkadot"),
        .init(code: "SHIB", id: "shiba-inu", name: "Shiba Inu"),
        .init(code: "HYPE", id: "hyperliquid", name: "Hyperliquid"),
        .init(code: "SUI", id: "sui", name: "Sui"),
        .init(code: "XMR", id: "monero", name: "Monero"),
        .init(code: "HBAR", id: "hedera-hashgraph", name: "Hedera"),
        .init(code: "LEO", id: "leo-token", name: "LEO Token"),
        .init(code: "DAI", id: "dai", name: "Dai"),
        .init(code: "PEPE", id: "pepe", name: "Pepe"),
        .init(code: "UNI", id: "uniswap", name: "Uniswap"),
        .init(code: "TAO", id: "bittensor", name: "Bittensor"),
        .init(code: "NEAR", id: "near", name: "NEAR Protocol"),
        .init(code: "APT", id: "aptos", name: "Aptos"),
        .init(code: "ICP", id: "internet-computer", name: "Internet Computer"),
        .init(code: "ETC", id: "ethereum-classic", name: "Ethereum Classic"),
        .init(code: "ONDO", id: "ondo-finance", name: "Ondo"),
        .init(code: "AAVE", id: "aave", name: "Aave"),
        .init(code: "CRO", id: "crypto-com-chain", name: "Cronos"),
        .init(code: "POL", id: "polygon-ecosystem-token", name: "Polygon"),
        .init(code: "KAS", id: "kaspa", name: "Kaspa"),
        .init(code: "TRUMP", id: "official-trump", name: "Official Trump"),
        .init(code: "ENA", id: "ethena", name: "Ethena"),
        .init(code: "RENDER", id: "render-token", name: "Render"),
        .init(code: "VET", id: "vechain", name: "VeChain"),
        .init(code: "ATOM", id: "cosmos", name: "Cosmos"),
        .init(code: "ALGO", id: "algorand", name: "Algorand"),
        .init(code: "FIL", id: "filecoin", name: "Filecoin"),
        .init(code: "ARB", id: "arbitrum", name: "Arbitrum"),
        .init(code: "OKB", id: "okb", name: "OKB"),
        .init(code: "FET", id: "fetch-ai", name: "Artificial Superintelligence Alliance"),
        .init(code: "WLD", id: "worldcoin-wld", name: "Worldcoin"),
        .init(code: "JUP", id: "jupiter-exchange-solana", name: "Jupiter"),
        .init(code: "OP", id: "optimism", name: "Optimism"),
        .init(code: "INJ", id: "injective-protocol", name: "Injective"),
        .init(code: "TIA", id: "celestia", name: "Celestia"),
        .init(code: "STX", id: "blockstack", name: "Stacks"),
        .init(code: "BONK", id: "bonk", name: "Bonk"),
        .init(code: "SEI", id: "sei-network", name: "Sei"),
        .init(code: "IMX", id: "immutable-x", name: "Immutable"),
        .init(code: "GRT", id: "the-graph", name: "The Graph"),
        .init(code: "QNT", id: "quant-network", name: "Quant"),
        .init(code: "FLOKI", id: "floki", name: "FLOKI"),
        .init(code: "WIF", id: "dogwifcoin", name: "dogwifhat"),
        .init(code: "LDO", id: "lido-dao", name: "Lido DAO"),
        .init(code: "XTZ", id: "tezos", name: "Tezos"),
        .init(code: "PYTH", id: "pyth-network", name: "Pyth Network"),
        .init(code: "ZEC", id: "zcash", name: "Zcash"),
        .init(code: "DASH", id: "dash", name: "Dash"),
        .init(code: "SAND", id: "the-sandbox", name: "The Sandbox"),
        .init(code: "MANA", id: "decentraland", name: "Decentraland"),
        .init(code: "AXS", id: "axie-infinity", name: "Axie Infinity"),
        .init(code: "EOS", id: "eos", name: "EOS"),
        .init(code: "NOT", id: "notcoin", name: "Notcoin"),
    ]

    static let byCode = Dictionary(uniqueKeysWithValues: all.map { ($0.code, $0) })
}

/// Набор курсов из одного источника: сколько единиц валюты стоит 1 USD.
struct RateSet: Codable, Equatable, Sendable {
    let rates: [String: Double]
    /// Время публикации курсов поставщиком.
    let updatedAt: Date
    /// Время, когда приложение получило эти данные.
    let fetchedAt: Date
}

/// Сведения о валюте по коду — без настроек приложения, чтобы ими пользовались и виджеты.
enum CurrencyCatalog {
    /// Коды стран ISO — один раз: список строится заново при каждом обращении к `Locale.Region`.
    private static let isoRegions = Set(Locale.Region.isoRegions.map(\.identifier))

    static func isCrypto(_ code: String) -> Bool {
        CryptoAsset.byCode[code] != nil
    }

    /// Код страны (или «EU») для флага валюты, если его можно определить по коду ISO 4217.
    static func flagRegion(for code: String) -> String? {
        guard !isCrypto(code) else { return nil }
        // Первые две буквы кода — обычно код страны; исключения задаём вручную.
        let overrides = ["EUR": "EU", "ANG": "CW", "XCG": "CW"]
        if let region = overrides[code] { return region }
        guard !code.hasPrefix("X") else { return nil } // наднациональные: XAF, XOF, XDR…
        let region = String(code.prefix(2))
        return isoRegions.contains(region) ? region : nil
    }

    /// Картинка значка в каталоге `Currency.xcassets`: флаг или значок криптовалюты.
    static func imageName(for code: String) -> String? {
        if isCrypto(code) { return "crypto-\(code)" }
        return flagRegion(for: code).map { "flag-\($0)" }
    }

    /// Название валюты на языке `locale`, с заглавной буквы.
    static func name(for code: String, locale: Locale) -> String {
        if let crypto = CryptoAsset.byCode[code] { return crypto.name }
        guard let name = locale.localizedString(forCurrencyCode: code), !name.isEmpty else { return code }
        return name.prefix(1).uppercased(with: locale) + name.dropFirst()
    }
}

/// Числа в формате приложения; `locale` задаёт разделители.
enum AmountFormat {
    /// Курс: больше знаков, чтобы были видны мелкие изменения.
    static func rate(_ value: Double, locale: Locale) -> String {
        if value >= 1000 {
            value.formatted(.number.locale(locale).precision(.fractionLength(0...2)))
        } else if value >= 1 {
            value.formatted(.number.locale(locale).precision(.fractionLength(2...4)))
        } else {
            value.formatted(.number.locale(locale).precision(.significantDigits(2...4)))
        }
    }

    /// Сумма: до двух знаков после запятой, для малых значений — значащие цифры.
    /// `decimalPlaces` — ровно столько знаков (настройка приложения).
    static func amount(_ value: Double, locale: Locale, decimalPlaces: Int?) -> String {
        // Огромные суммы — в научной записи (6,94E16): иначе строка не помещается в карточку.
        if abs(value) >= 1e15 {
            return value.formatted(.number.locale(locale).notation(.scientific).precision(.fractionLength(0...3)))
        }
        if let places = decimalPlaces {
            return value.formatted(.number.locale(locale).precision(.fractionLength(places)))
        }
        if value >= 1 || value == 0 {
            return value.formatted(.number.locale(locale).precision(.fractionLength(0...2)))
        }
        return value.formatted(.number.locale(locale).precision(.significantDigits(2...4)))
    }
}
