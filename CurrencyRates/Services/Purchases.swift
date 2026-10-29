import Foundation
import Observation
import StoreKit

/// Покупки Pro через StoreKit 2: цены и тарифы из App Store, покупка, восстановление
/// и слежение за подпиской. Что куплено сейчас — решает App Store, а не флаг в приложении:
/// при каждом запуске и каждом изменении покупок Pro включается или выключается по ним.
@MainActor
@Observable
final class Purchases {
    static let shared = Purchases()

    /// Что сейчас делает экран подписки: блокирует кнопки, пока идёт запрос.
    enum State: Equatable {
        case idle, purchasing, restoring
    }

    enum Outcome {
        case success, cancelled, pending, failed
    }

    private(set) var products: [ProPlan: Product] = [:]
    private(set) var state: State = .idle
    /// Цены не загрузились (нет сети или продуктов нет в App Store Connect).
    private(set) var loadFailed = false

    @ObservationIgnored private var store: RatesStore?
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    private init() {}

    /// Запуск при старте приложения: подписка на изменения покупок, цены, текущий доступ.
    func start(_ store: RatesStore) {
        self.store = store
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                // Покупки, сделанные вне приложения: продление, отмена, возврат, «Попросить купить».
                for await result in Transaction.updates {
                    guard let self else { return }
                    await self.handle(result)
                }
            }
        }
        Task {
            await refreshEntitlements()
            await loadProducts()
        }
    }

    // MARK: - Цены

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: ProPlan.allCases.map(\.productID))
            var map: [ProPlan: Product] = [:]
            for product in loaded {
                if let plan = ProPlan(productID: product.id) { map[plan] = product }
            }
            products = map
            loadFailed = map.isEmpty
        } catch {
            loadFailed = true
        }
    }

    /// Цена тарифа на языке пользователя и в его валюте; пока не загрузилась — многоточие.
    func priceText(for plan: ProPlan) -> String {
        guard let price = products[plan]?.displayPrice else { return "…" }
        switch plan {
        case .monthly: return L(.perMonth, price)
        case .yearly: return L(.perYear, price)
        case .lifetime: return L(.oneTime, price)
        }
    }

    /// Есть ли у тарифа пробный период: по данным App Store, а пока они не загрузились — по умолчанию.
    func hasTrial(_ plan: ProPlan) -> Bool {
        guard let product = products[plan] else { return plan.hasTrial }
        return product.subscription?.introductoryOffer != nil
    }

    // MARK: - Покупка и восстановление

    func purchase(_ plan: ProPlan) async -> Outcome {
        guard let product = products[plan] else { return .failed }
        state = .purchasing
        defer { state = .idle }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result else { return .failed }
                await transaction.finish()
                await refreshEntitlements()
                return .success
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    /// «Восстановить покупки»: синхронизация с App Store и повторная проверка доступа.
    /// Возвращает, есть ли после этого Pro.
    func restore() async -> Bool {
        state = .restoring
        defer { state = .idle }
        try? await AppStore.sync()
        await refreshEntitlements()
        return store?.isPro ?? false
    }

    // MARK: - Доступ

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await transaction.finish()
        await refreshEntitlements()
    }

    /// Включает или выключает Pro по действующим покупкам; из нескольких берёт самую «старшую».
    func refreshEntitlements() async {
        var best: ProPlan?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil,
                  let plan = ProPlan(productID: transaction.productID)
            else { continue }
            if best == nil || plan.rank > best!.rank { best = plan }
        }
        guard let store else { return }
        if let best {
            if !store.isPro { store.isPro = true }
            if store.proPlan != best { store.proPlan = best }
        } else if store.isPro {
            store.isPro = false
        }
    }
}

extension ProPlan {
    /// Идентификаторы продуктов — такие же заводятся в App Store Connect.
    var productID: String {
        switch self {
        case .monthly: "com.bahruzakhundov.cento.pro.monthly"
        case .yearly: "com.bahruzakhundov.cento.pro.yearly"
        case .lifetime: "com.bahruzakhundov.cento.pro.lifetime"
        }
    }

    init?(productID: String) {
        guard let plan = Self.allCases.first(where: { $0.productID == productID }) else { return nil }
        self = plan
    }

    /// Чем больше, тем «старше» тариф: навсегда важнее года, год — месяца.
    fileprivate var rank: Int {
        switch self {
        case .monthly: 1
        case .yearly: 2
        case .lifetime: 3
        }
    }
}
