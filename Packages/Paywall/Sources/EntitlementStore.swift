import Observation
import SeleneCore

/// Observable entitlement state for the app: pulls verified snapshots from
/// the commerce provider, reduces them against the injected clock, and
/// answers every gate question through `FeatureGate`.
///
/// All entitlement *logic* lives in `EntitlementReducer` (pure) and
/// `FeatureGate` (pure); this class is the wiring — and it still never reads
/// the system clock or touches StoreKit types directly.
@MainActor
@Observable
public final class EntitlementStore {
    /// What just happened, for UI feedback. Distinct from `state`: a restore
    /// that lands on `.active` reports `.restored`, a purchase `.purchased`.
    public enum Activity: Hashable, Sendable {
        case idle
        case purchased(ProductID)
        case restored
        case failed(message: String)
    }

    public private(set) var state: EntitlementState = .free
    public private(set) var products: [PaywallProduct] = []
    public private(set) var isTrialAvailable = true
    public private(set) var activity: Activity = .idle

    private let provider: any PurchaseProviding
    private let clock: any DayClock
    private let gate = FeatureGate()
    private var updatesTask: Task<Void, Never>?

    public init(provider: any PurchaseProviding, clock: any DayClock) {
        self.provider = provider
        self.clock = clock
    }

    /// Gate decision for a feature, as of the injected clock's today.
    public func isUnlocked(_ feature: Feature) -> Bool {
        gate.isUnlocked(feature, entitlement: state, today: clock.today)
    }

    /// Re-derives state from the provider's current entitlements and reloads
    /// products. A product-load failure degrades gracefully: the paywall
    /// renders fallback copy and the free tier is never affected.
    public func refresh() async {
        await apply(provider.currentEntitlements())
        do {
            products = try await provider.availableProducts()
        } catch {
            products = []
        }
    }

    public func purchase(_ productID: ProductID) async {
        do {
            try await apply(provider.purchase(productID))
            activity = .purchased(productID)
        } catch PurchaseError.purchaseCancelled {
            activity = .idle
        } catch {
            activity = .failed(message: error.userMessage)
        }
    }

    public func restore() async {
        do {
            try await apply(provider.restorePurchases())
            activity = .restored
        } catch {
            activity = .failed(message: error.userMessage)
        }
    }

    /// Starts listening for out-of-band entitlement changes (renewals,
    /// refunds, Ask to Buy approvals). Idempotent.
    public func startObservingUpdates() {
        guard updatesTask == nil else {
            return
        }
        let stream = provider.entitlementUpdates()
        updatesTask = Task { [weak self] in
            for await snapshot in stream {
                self?.apply(snapshot)
            }
        }
    }

    public func stopObservingUpdates() {
        updatesTask?.cancel()
        updatesTask = nil
    }

    private func apply(_ snapshot: EntitlementSnapshot) {
        state = EntitlementReducer.state(from: snapshot, today: clock.today)
        isTrialAvailable = EntitlementReducer.isTrialOfferAvailable(for: snapshot)
    }
}
