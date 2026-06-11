import SeleneCore

/// A purchasable product as the commerce provider presents it: the localized
/// display strings come from the provider (StoreKit's localized price in
/// production, fixed strings from the mock), never hardcoded in views.
public struct PaywallProduct: Hashable, Sendable, Identifiable {
    public let id: ProductID
    public let displayName: String
    /// Localized price string, e.g. "$39.99".
    public let displayPrice: String

    public init(id: ProductID, displayName: String, displayPrice: String) {
        self.id = id
        self.displayName = displayName
        self.displayPrice = displayPrice
    }
}

/// Verified ownership facts from the commerce provider. This is the *input*
/// to the entitlement state machine — `EntitlementReducer` turns a snapshot
/// plus the injected clock's "today" into an `EntitlementState`.
public struct EntitlementSnapshot: Hashable, Sendable {
    public enum Ownership: Hashable, Sendable {
        case none
        /// An annual-subscription transaction (the 7-day trial is its
        /// introductory offer). `expiresOnDay` is the last entitled day.
        case annual(isInTrialPeriod: Bool, expiresOnDay: DayNumber)
        case lifetime
    }

    public let ownership: Ownership
    /// True when any entitlement transaction ever existed (including an
    /// expired trial) — distinguishes never-trialed from expired, and drives
    /// trial-offer eligibility on the paywall.
    public let hasEverOwnedEntitlement: Bool

    public init(ownership: Ownership, hasEverOwnedEntitlement: Bool) {
        self.ownership = ownership
        self.hasEverOwnedEntitlement = hasEverOwnedEntitlement
    }

    public static let neverOwned = EntitlementSnapshot(
        ownership: .none, hasEverOwnedEntitlement: false
    )
}

/// Commerce failures, in product terms. Every case carries human copy at the
/// UI boundary via `userMessage`; none of them ever blocks the free tier.
public enum PurchaseError: Error, Hashable, Sendable {
    /// The store has no products to sell right now (offline, store outage).
    case productsUnavailable
    /// The user dismissed the purchase sheet — not a failure state.
    case purchaseCancelled
    /// The purchase is awaiting approval (e.g. Ask to Buy).
    case purchasePending
    /// The store rejected or could not verify the transaction.
    case purchaseFailed
    case restoreFailed

    public var userMessage: String {
        switch self {
        case .productsUnavailable:
            "The App Store didn't respond. Everything you logged stays available — try again later."
        case .purchaseCancelled:
            "No charge was made."
        case .purchasePending:
            "Your purchase is awaiting approval. Selene unlocks the moment it clears."
        case .purchaseFailed:
            "The App Store couldn't complete that purchase. No charge was made."
        case .restoreFailed:
            "Restore didn't go through. Check your App Store sign-in and try again."
        }
    }
}

/// The commerce boundary. StoreKit 2 implements this in production
/// (`StoreKitPurchaseProvider`); the deterministic `MockPurchaseProvider`
/// carries every test. Nothing outside `Paywall/` may talk to StoreKit.
public protocol PurchaseProviding: Sendable {
    /// Both SKUs with provider-localized display strings.
    func availableProducts() async throws(PurchaseError) -> [PaywallProduct]
    /// Purchases a product and returns the resulting verified snapshot.
    func purchase(_ productID: ProductID) async throws(PurchaseError) -> EntitlementSnapshot
    /// Restores prior purchases and returns the resulting verified snapshot.
    func restorePurchases() async throws(PurchaseError) -> EntitlementSnapshot
    /// The current verified snapshot. Never throws: no provider response
    /// degrades to `.neverOwned` semantics decided by the implementation.
    func currentEntitlements() async -> EntitlementSnapshot
    /// Out-of-band entitlement changes (renewals, refunds, Ask to Buy
    /// approvals — StoreKit's `Transaction.updates` in production).
    func entitlementUpdates() -> AsyncStream<EntitlementSnapshot>
}
