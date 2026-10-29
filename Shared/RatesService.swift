import Foundation

/// Загрузка курсов из открытых API, не требующих ключа:
/// - фиат — ExchangeRate-API (open.er-api.com), обновляется раз в сутки;
/// - криптовалюты — CoinGecko (api.coingecko.com), обновляется несколько раз в минуту.
struct RatesService: Sendable {
    static let fiatSourceName = "ExchangeRate-API"
    static let fiatSourceURL = URL(string: "https://www.exchangerate-api.com")!
    static let cryptoSourceName = "CoinGecko"
    static let cryptoSourceURL = URL(string: "https://www.coingecko.com")!

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Фиат

    func fetchFiat() async throws -> RateSet {
        let url = URL(string: "https://open.er-api.com/v6/latest/USD")!
        let decoded = try await get(FiatResponse.self, from: url)

        guard decoded.result == "success",
              decoded.baseCode == "USD",
              let rates = decoded.rates, !rates.isEmpty,
              let updated = decoded.timeLastUpdateUnix
        else {
            throw RatesServiceError.badResponse
        }

        return RateSet(
            rates: rates.filter { CryptoAsset.byCode[$0.key] == nil },
            updatedAt: Date(timeIntervalSince1970: updated),
            fetchedAt: .now
        )
    }

    private struct FiatResponse: Decodable {
        let result: String
        let baseCode: String?
        let timeLastUpdateUnix: TimeInterval?
        let rates: [String: Double]?

        enum CodingKeys: String, CodingKey {
            case result
            case baseCode = "base_code"
            case timeLastUpdateUnix = "time_last_update_unix"
            case rates
        }
    }

    // MARK: - Криптовалюты

    func fetchCrypto() async throws -> RateSet {
        var components = URLComponents(string: "https://api.coingecko.com/api/v3/simple/price")!
        components.queryItems = [
            URLQueryItem(name: "ids", value: CryptoAsset.all.map(\.id).joined(separator: ",")),
            URLQueryItem(name: "vs_currencies", value: "usd"),
            URLQueryItem(name: "include_last_updated_at", value: "true"),
        ]
        // Ответ: { "bitcoin": { "usd": 79773, "last_updated_at": 1793088915 }, ... }
        let decoded = try await get([String: [String: Double]].self, from: components.url!)

        var rates: [String: Double] = [:]
        var latestUpdate: TimeInterval = 0
        for asset in CryptoAsset.all {
            guard let entry = decoded[asset.id], let priceUSD = entry["usd"], priceUSD > 0 else { continue }
            rates[asset.code] = 1 / priceUSD
            latestUpdate = max(latestUpdate, entry["last_updated_at"] ?? 0)
        }
        guard !rates.isEmpty else { throw RatesServiceError.badResponse }

        return RateSet(
            rates: rates,
            updatedAt: latestUpdate > 0 ? Date(timeIntervalSince1970: latestUpdate) : .now,
            fetchedAt: .now
        )
    }

    // MARK: - Общее

    private func get<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw RatesServiceError.badResponse }
        if http.statusCode == 429 { throw RatesServiceError.rateLimited }
        guard (200..<300).contains(http.statusCode) else { throw RatesServiceError.badResponse }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

enum RatesServiceError: Error {
    case badResponse
    case rateLimited
}
