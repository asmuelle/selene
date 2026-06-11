import SeleneCore

// Entitlements and feature gating.
//
// This is the ONLY module ever permitted network access (StoreKit 2, M3).
// M1 contains no StoreKit yet — just the entitlement state machine and the gate,
// so invariant #7 (manual logging free forever) is enforced and tested from day one.

public enum ProductID: String, CaseIterable, Codable, Sendable {
    case annual = "app.selene.plus.annual"
    case lifetime = "app.selene.plus.lifetime"
}

/// Local entitlement state. Verified against StoreKit in M3; defaults to `.free`.
public enum EntitlementState: Hashable, Codable, Sendable {
    case free
    /// 7-day trial; `endsOn` is the last entitled day.
    case trial(endsOn: DayNumber)
    case active(ProductID)
    case expired

    public func isEntitled(on day: DayNumber) -> Bool {
        switch self {
        case .free, .expired:
            false
        case let .trial(endsOn):
            day <= endsOn
        case .active:
            true
        }
    }
}

/// Every gateable surface in the product.
public enum Feature: CaseIterable, Sendable {
    // Free forever (invariant #7) — never gated, never revocable.
    case manualLogging
    case cycleHistory
    case dataExport
    case dataDelete

    // The AI layer (hard paywall, 7-day trial).
    case insightNarration
    case groundedQA
    case voiceLogging
    case stripReading
    case doctorVisitSummary

    public var isFreeForever: Bool {
        switch self {
        case .manualLogging, .cycleHistory, .dataExport, .dataDelete: true
        case .insightNarration, .groundedQA, .voiceLogging, .stripReading, .doctorVisitSummary: false
        }
    }
}

/// Pure gating function — no side effects, fully table-testable.
public struct FeatureGate: Sendable {
    public init() {}

    public func isUnlocked(
        _ feature: Feature,
        entitlement: EntitlementState,
        today: DayNumber
    ) -> Bool {
        if feature.isFreeForever {
            return true
        }
        return entitlement.isEntitled(on: today)
    }
}
