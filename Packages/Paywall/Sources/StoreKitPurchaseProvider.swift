import Foundation
import SeleneCore
import StoreKit

/// The production commerce provider: StoreKit 2 behind `PurchaseProviding`.
///
/// This file is the ONLY place in the product that talks to StoreKit — and
/// `Paywall/` is the only module permitted any network surface (invariant #1).
/// It is config-gated: the composition root selects it via
/// `PaywallConfiguration` and defaults to the deterministic mock everywhere
/// else, so no test ever depends on App Store connectivity.
public actor StoreKitPurchaseProvider: PurchaseProviding {
    private let clock: any DayClock

    public init(clock: any DayClock = SystemDayClock()) {
        self.clock = clock
    }

    // MARK: - Products

    public func availableProducts() async throws(PurchaseError) -> [PaywallProduct] {
        let storeProducts = try await loadProducts(for: ProductID.allCases.map(\.rawValue))
        let mapped = storeProducts.compactMap { product -> PaywallProduct? in
            guard let id = ProductID(rawValue: product.id) else {
                return nil
            }
            return PaywallProduct(
                id: id, displayName: product.displayName, displayPrice: product.displayPrice
            )
        }
        guard !mapped.isEmpty else {
            throw .productsUnavailable
        }
        return mapped.sorted { $0.id.rawValue < $1.id.rawValue }
    }

    /// StoreKit product loading is eventually-consistent on a cold start: on a
    /// freshly booted device or CI simulator, `Product.products(for:)` can
    /// briefly return empty or throw before the StoreKit configuration has
    /// synced. Retry a bounded number of times so the paywall is robust on
    /// first launch. Returns immediately once products are available.
    private func loadProducts(for ids: [String]) async throws(PurchaseError) -> [Product] {
        for attempt in 0 ..< 10 {
            if let products = try? await Product.products(for: ids), !products.isEmpty {
                return products
            }
            if attempt < 9 {
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
        throw .productsUnavailable
    }

    // MARK: - Purchase / restore

    public func purchase(_ productID: ProductID) async throws(PurchaseError) -> EntitlementSnapshot {
        let result: Product.PurchaseResult
        do {
            let products = try await loadProducts(for: [productID.rawValue])
            guard let product = products.first else {
                throw PurchaseError.productsUnavailable
            }
            result = try await product.purchase()
        } catch let error as PurchaseError {
            throw error
        } catch {
            throw .purchaseFailed
        }

        switch result {
        case let .success(verification):
            guard case let .verified(transaction) = verification else {
                throw .purchaseFailed
            }
            await transaction.finish()
            return await currentEntitlements()
        case .userCancelled:
            throw .purchaseCancelled
        case .pending:
            throw .purchasePending
        @unknown default:
            throw .purchaseFailed
        }
    }

    public func restorePurchases() async throws(PurchaseError) -> EntitlementSnapshot {
        do {
            try await AppStore.sync()
        } catch {
            throw .restoreFailed
        }
        return await currentEntitlements()
    }

    // MARK: - Entitlements

    public func currentEntitlements() async -> EntitlementSnapshot {
        var ownership = EntitlementSnapshot.Ownership.none
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            guard
                case let .verified(transaction) = entitlement,
                let productID = ProductID(rawValue: transaction.productID),
                transaction.revocationDate == nil
            else {
                continue
            }
            switch productID {
            case .lifetime:
                ownership = .lifetime
            case .annual where ownership != .lifetime:
                ownership = annualOwnership(of: transaction)
            case .annual:
                break
            }
        }
        let hasEverOwned: Bool = if ownership != .none {
            true
        } else {
            await hasAnyHistoricalTransaction()
        }
        return EntitlementSnapshot(ownership: ownership, hasEverOwnedEntitlement: hasEverOwned)
    }

    public nonisolated func entitlementUpdates() -> AsyncStream<EntitlementSnapshot> {
        AsyncStream { continuation in
            let task = Task {
                for await update in StoreKit.Transaction.updates {
                    if case let .verified(transaction) = update {
                        await transaction.finish()
                    }
                    await continuation.yield(self.currentEntitlements())
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Mapping

    private func annualOwnership(
        of transaction: StoreKit.Transaction
    ) -> EntitlementSnapshot.Ownership {
        // A subscription transaction always carries an expiration; degrade to
        // "expires today" if it ever doesn't, rather than inventing duration.
        let expiresOnDay = transaction.expirationDate.map(DayNumber.init(date:)) ?? clock.today
        let isInTrialPeriod: Bool = if #available(iOS 17.2, macOS 14.2, *) {
            transaction.offer?.type == .introductory
        } else {
            false
        }
        return .annual(isInTrialPeriod: isInTrialPeriod, expiresOnDay: expiresOnDay)
    }

    private func hasAnyHistoricalTransaction() async -> Bool {
        for productID in ProductID.allCases {
            if await StoreKit.Transaction.latest(for: productID.rawValue) != nil {
                return true
            }
        }
        return false
    }
}
