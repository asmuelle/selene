@testable import Paywall
import SeleneCore
import Testing

/// The pure entitlement state machine, table-tested across every state the
/// product knows: never-trialed, in-trial, expired, subscribed, lifetime.
/// All transitions are driven by snapshots plus an explicit "today" — there
/// is no system clock anywhere in this logic.
@Suite("Entitlement reducer")
struct EntitlementReducerTests {
    let today = DayNumber(20614)

    @Test("never-trialed user is free, with the trial offer available")
    func neverTrialed() {
        // Arrange
        let snapshot = EntitlementSnapshot.neverOwned

        // Act & Assert
        #expect(EntitlementReducer.state(from: snapshot, today: today) == .free)
        #expect(EntitlementReducer.isTrialOfferAvailable(for: snapshot))
    }

    @Test("an in-trial subscription maps to .trial through its last entitled day")
    func inTrial() {
        let endsOn = EntitlementReducer.trialEndDay(startingOn: today)
        let snapshot = EntitlementSnapshot(
            ownership: .annual(isInTrialPeriod: true, expiresOnDay: endsOn),
            hasEverOwnedEntitlement: true
        )

        #expect(endsOn == today.advanced(by: 6), "7 entitled days: day 1 through day 7")
        #expect(EntitlementReducer.state(from: snapshot, today: today) == .trial(endsOn: endsOn))
        #expect(EntitlementReducer.state(from: snapshot, today: endsOn) == .trial(endsOn: endsOn))
        #expect(!EntitlementReducer.isTrialOfferAvailable(for: snapshot))
    }

    @Test("the trial expires the day after its last entitled day — clock-driven, not StoreKit-driven")
    func trialExpiry() {
        let endsOn = EntitlementReducer.trialEndDay(startingOn: today)
        let snapshot = EntitlementSnapshot(
            ownership: .annual(isInTrialPeriod: true, expiresOnDay: endsOn),
            hasEverOwnedEntitlement: true
        )

        #expect(
            EntitlementReducer.state(from: snapshot, today: endsOn.advanced(by: 1)) == .expired
        )
    }

    @Test("a paid annual subscription is .active(.annual) until expiry, then .expired")
    func paidAnnual() {
        let expiresOnDay = today.advanced(by: 200)
        let snapshot = EntitlementSnapshot(
            ownership: .annual(isInTrialPeriod: false, expiresOnDay: expiresOnDay),
            hasEverOwnedEntitlement: true
        )

        #expect(EntitlementReducer.state(from: snapshot, today: today) == .active(.annual))
        #expect(EntitlementReducer.state(from: snapshot, today: expiresOnDay) == .active(.annual))
        #expect(
            EntitlementReducer.state(from: snapshot, today: expiresOnDay.advanced(by: 1)) == .expired
        )
    }

    @Test("lifetime ownership is .active(.lifetime) on any day, forever")
    func lifetime() {
        let snapshot = EntitlementSnapshot(ownership: .lifetime, hasEverOwnedEntitlement: true)

        for offset in [0, 1, 365, 36500] {
            #expect(
                EntitlementReducer.state(from: snapshot, today: today.advanced(by: offset))
                    == .active(.lifetime)
            )
        }
        #expect(!EntitlementReducer.isTrialOfferAvailable(for: snapshot))
    }

    @Test("no current ownership but prior history is .expired — never a second trial")
    func lapsedIsExpiredNotFree() {
        let snapshot = EntitlementSnapshot(ownership: .none, hasEverOwnedEntitlement: true)

        #expect(EntitlementReducer.state(from: snapshot, today: today) == .expired)
        #expect(!EntitlementReducer.isTrialOfferAvailable(for: snapshot))
    }
}
