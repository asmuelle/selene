import SeleneCore

/// The pure entitlement state machine: verified ownership facts plus the
/// injected clock's "today" in, `EntitlementState` out. No IO, no system
/// clock, no StoreKit — fully table-testable.
public enum EntitlementReducer {
    /// Length of the free trial in entitled days (day 1 through day 7).
    public static let trialLengthDays = 7

    public static func state(
        from snapshot: EntitlementSnapshot,
        today: DayNumber
    ) -> EntitlementState {
        switch snapshot.ownership {
        case .lifetime:
            return .active(.lifetime)
        case let .annual(isInTrialPeriod, expiresOnDay):
            if today > expiresOnDay {
                return .expired
            }
            return isInTrialPeriod ? .trial(endsOn: expiresOnDay) : .active(.annual)
        case .none:
            return snapshot.hasEverOwnedEntitlement ? .expired : .free
        }
    }

    /// The trial offer exists only for users who never held any entitlement.
    public static func isTrialOfferAvailable(for snapshot: EntitlementSnapshot) -> Bool {
        !snapshot.hasEverOwnedEntitlement
    }

    /// Last entitled day of a trial that starts today.
    public static func trialEndDay(startingOn day: DayNumber) -> DayNumber {
        day.advanced(by: trialLengthDays - 1)
    }
}
