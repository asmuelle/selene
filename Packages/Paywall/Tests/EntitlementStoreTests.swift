@testable import Paywall
import SeleneCore
import Testing

/// The full entitlement store against the deterministic mock provider:
/// never-trialed → in-trial → expired → re-subscribed, lifetime, restore,
/// cancelled/failed purchases, out-of-band updates, and gate wiring. The
/// clock is injected everywhere — expiry is tested by advancing it.
@MainActor
@Suite("Entitlement store (mock provider)")
struct EntitlementStoreTests {
    let day = DayNumber(20614)

    private func makeStore(
        clock: FixedDayClock,
        initial: EntitlementSnapshot = .neverOwned,
        restorable: EntitlementSnapshot? = nil
    ) -> (EntitlementStore, MockPurchaseProvider) {
        let provider = MockPurchaseProvider(
            clock: clock, initialSnapshot: initial, restorableSnapshot: restorable
        )
        return (EntitlementStore(provider: provider, clock: clock), provider)
    }

    @Test("fresh install: free state, trial available, both SKUs loaded")
    func freshInstall() async {
        let (store, _) = makeStore(clock: FixedDayClock(today: day))

        await store.refresh()

        #expect(store.state == .free)
        #expect(store.isTrialAvailable)
        #expect(store.products.map(\.id).sorted { $0.rawValue < $1.rawValue }
            == [.annual, .lifetime])
        #expect(!store.isUnlocked(.groundedQA))
        #expect(store.isUnlocked(.manualLogging), "free tier never gated (invariant #7)")
    }

    @Test("first annual purchase starts the 7-day trial and unlocks the AI layer")
    func trialPurchase() async {
        let (store, _) = makeStore(clock: FixedDayClock(today: day))
        await store.refresh()

        await store.purchase(.annual)

        #expect(store.state == .trial(endsOn: day.advanced(by: 6)))
        #expect(store.activity == .purchased(.annual))
        #expect(store.isUnlocked(.groundedQA))
        #expect(store.isUnlocked(.doctorVisitSummary))
        #expect(!store.isTrialAvailable, "the trial is once, ever")
    }

    @Test("trial expiry: same provider state, later clock — AI layer locks again")
    func trialExpiry() async {
        // Arrange: trial purchased on `day`.
        let purchaseClock = FixedDayClock(today: day)
        let provider = MockPurchaseProvider(clock: purchaseClock)
        let purchaseStore = EntitlementStore(provider: provider, clock: purchaseClock)
        await purchaseStore.purchase(.annual)

        // Act: a fresh store reads the SAME provider eight days later.
        let lateClock = FixedDayClock(today: day.advanced(by: 7))
        let lateStore = EntitlementStore(provider: provider, clock: lateClock)
        await lateStore.refresh()

        // Assert
        #expect(lateStore.state == .expired)
        #expect(!lateStore.isUnlocked(.groundedQA))
        #expect(lateStore.isUnlocked(.manualLogging))
        #expect(lateStore.isUnlocked(.dataExport))
    }

    @Test("re-subscribing after expiry yields a paid year, never a second trial")
    func resubscribeAfterExpiry() async {
        let lapsed = EntitlementSnapshot(ownership: .none, hasEverOwnedEntitlement: true)
        let (store, _) = makeStore(clock: FixedDayClock(today: day), initial: lapsed)
        await store.refresh()
        #expect(store.state == .expired)

        await store.purchase(.annual)

        #expect(store.state == .active(.annual))
        #expect(!store.isTrialAvailable)
    }

    @Test("lifetime purchase unlocks everything permanently")
    func lifetimePurchase() async {
        let (store, _) = makeStore(clock: FixedDayClock(today: day))

        await store.purchase(.lifetime)

        #expect(store.state == .active(.lifetime))
        for feature in Feature.allCases {
            #expect(store.isUnlocked(feature))
        }
    }

    @Test("restore on a fresh install recovers a prior lifetime purchase")
    func restoreRecoversLifetime() async {
        let owned = EntitlementSnapshot(ownership: .lifetime, hasEverOwnedEntitlement: true)
        let (store, _) = makeStore(clock: FixedDayClock(today: day), restorable: owned)
        await store.refresh()
        #expect(store.state == .free)

        await store.restore()

        #expect(store.state == .active(.lifetime))
        #expect(store.activity == .restored)
        #expect(store.isUnlocked(.groundedQA))
    }

    @Test("restore with nothing to restore stays free and still reports honestly")
    func restoreWithNothing() async {
        let (store, _) = makeStore(clock: FixedDayClock(today: day))
        await store.refresh()

        await store.restore()

        #expect(store.state == .free)
        #expect(store.activity == .restored)
    }

    @Test("a cancelled purchase changes nothing and shows no error")
    func cancelledPurchase() async {
        let (store, provider) = makeStore(clock: FixedDayClock(today: day))
        await provider.script(purchaseError: .purchaseCancelled)
        await store.refresh()

        await store.purchase(.annual)

        #expect(store.state == .free)
        #expect(store.activity == .idle)
    }

    @Test("a failed purchase surfaces human copy and leaves the state untouched")
    func failedPurchase() async {
        let (store, provider) = makeStore(clock: FixedDayClock(today: day))
        await provider.script(purchaseError: .purchaseFailed)

        await store.purchase(.lifetime)

        #expect(store.state == .free)
        #expect(store.activity == .failed(message: PurchaseError.purchaseFailed.userMessage))
    }

    @Test("product-load failure degrades gracefully: empty products, free tier intact")
    func productLoadFailure() async {
        let (store, provider) = makeStore(clock: FixedDayClock(today: day))
        await provider.script(productsError: .productsUnavailable)

        await store.refresh()

        #expect(store.products.isEmpty)
        #expect(store.state == .free)
        #expect(store.isUnlocked(.manualLogging))
    }

    @Test("an out-of-band update (renewal/refund stream) re-derives state")
    func outOfBandUpdate() async {
        let (store, provider) = makeStore(clock: FixedDayClock(today: day))
        await store.refresh()
        store.startObservingUpdates()
        // Give the stream registration a tick before pushing.
        await Task.yield()

        await provider.pushUpdate(
            EntitlementSnapshot(ownership: .lifetime, hasEverOwnedEntitlement: true)
        )
        // Poll briefly: the update hops provider actor → stream → main actor.
        for _ in 0 ..< 200 where store.state != .active(.lifetime) {
            try? await Task.sleep(for: .milliseconds(5))
        }

        #expect(store.state == .active(.lifetime))
        store.stopObservingUpdates()
    }

    @Test("mock provider is deterministic: identical scripts, identical states")
    func mockDeterminism() async {
        var endStates: [EntitlementState] = []
        for _ in 0 ..< 3 {
            let (store, _) = makeStore(clock: FixedDayClock(today: day))
            await store.refresh()
            await store.purchase(.annual)
            endStates.append(store.state)
        }

        #expect(Set(endStates).count == 1)
        #expect(endStates[0] == .trial(endsOn: day.advanced(by: 6)))
    }
}
