import SeleneCore

/// Deterministic, fully scriptable commerce provider — the provider that
/// carries every entitlement test and every non-StoreKit run of the app.
///
/// No randomness, no IO, no network: purchases mutate in-memory state using
/// the injected clock, and failure modes are scripted explicitly.
public actor MockPurchaseProvider: PurchaseProviding {
    public static let annualDurationDays = 365

    public static let defaultCatalog: [PaywallProduct] = [
        PaywallProduct(id: .annual, displayName: "Selene Plus — Annual", displayPrice: "$39.99"),
        PaywallProduct(id: .lifetime, displayName: "Selene Plus — Lifetime", displayPrice: "$89.99"),
    ]

    private let clock: any DayClock
    private let catalog: [PaywallProduct]
    private var snapshot: EntitlementSnapshot
    private var restorableSnapshot: EntitlementSnapshot?
    private var scriptedProductsError: PurchaseError?
    private var scriptedPurchaseError: PurchaseError?
    private var scriptedRestoreError: PurchaseError?
    private var updateContinuations: [Int: AsyncStream<EntitlementSnapshot>.Continuation] = [:]
    private var nextContinuationID = 0

    public init(
        clock: any DayClock,
        initialSnapshot: EntitlementSnapshot = .neverOwned,
        restorableSnapshot: EntitlementSnapshot? = nil,
        catalog: [PaywallProduct] = MockPurchaseProvider.defaultCatalog
    ) {
        self.clock = clock
        snapshot = initialSnapshot
        self.restorableSnapshot = restorableSnapshot
        self.catalog = catalog
    }

    // MARK: - Scripting (test control surface)

    public func script(productsError: PurchaseError?) {
        scriptedProductsError = productsError
    }

    public func script(purchaseError: PurchaseError?) {
        scriptedPurchaseError = purchaseError
    }

    public func script(restoreError: PurchaseError?) {
        scriptedRestoreError = restoreError
    }

    /// Pushes an out-of-band snapshot (simulates a renewal/refund landing via
    /// the transaction-updates stream).
    public func pushUpdate(_ newSnapshot: EntitlementSnapshot) {
        snapshot = newSnapshot
        for continuation in updateContinuations.values {
            continuation.yield(newSnapshot)
        }
    }

    // MARK: - PurchaseProviding

    public func availableProducts() async throws(PurchaseError) -> [PaywallProduct] {
        if let scriptedProductsError {
            throw scriptedProductsError
        }
        return catalog
    }

    public func purchase(_ productID: ProductID) async throws(PurchaseError) -> EntitlementSnapshot {
        if let scriptedPurchaseError {
            throw scriptedPurchaseError
        }
        switch productID {
        case .lifetime:
            snapshot = EntitlementSnapshot(ownership: .lifetime, hasEverOwnedEntitlement: true)
        case .annual:
            // First-ever purchase starts the 7-day free trial (introductory
            // offer); a re-subscribe after expiry is a paid year, no trial.
            let isTrial = EntitlementReducer.isTrialOfferAvailable(for: snapshot)
            let expiresOnDay = isTrial
                ? EntitlementReducer.trialEndDay(startingOn: clock.today)
                : clock.today.advanced(by: Self.annualDurationDays)
            snapshot = EntitlementSnapshot(
                ownership: .annual(isInTrialPeriod: isTrial, expiresOnDay: expiresOnDay),
                hasEverOwnedEntitlement: true
            )
        }
        return snapshot
    }

    public func restorePurchases() async throws(PurchaseError) -> EntitlementSnapshot {
        if let scriptedRestoreError {
            throw scriptedRestoreError
        }
        if let restorableSnapshot {
            snapshot = restorableSnapshot
        }
        return snapshot
    }

    public func currentEntitlements() async -> EntitlementSnapshot {
        snapshot
    }

    public nonisolated func entitlementUpdates() -> AsyncStream<EntitlementSnapshot> {
        AsyncStream { continuation in
            Task { await self.register(continuation) }
        }
    }

    private func register(_ continuation: AsyncStream<EntitlementSnapshot>.Continuation) {
        let id = nextContinuationID
        nextContinuationID += 1
        updateContinuations[id] = continuation
        continuation.onTermination = { _ in
            Task { await self.unregister(id) }
        }
    }

    private func unregister(_ id: Int) {
        updateContinuations[id] = nil
    }
}
