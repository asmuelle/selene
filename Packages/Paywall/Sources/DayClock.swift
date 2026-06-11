import Foundation
import SeleneCore

/// The clock seam for entitlement logic.
///
/// Entitlement code never reads the system clock directly: trial start/expiry
/// and every gate decision take "today" from an injected `DayClock`, so the
/// whole state machine is deterministic under test (advance the fixed clock,
/// watch the trial expire).
public protocol DayClock: Sendable {
    var today: DayNumber { get }
}

/// Deterministic clock for tests and scripted runs.
public struct FixedDayClock: DayClock {
    public let today: DayNumber

    public init(today: DayNumber) {
        self.today = today
    }
}

/// Production clock — the single place entitlement code touches `Date()`.
public struct SystemDayClock: DayClock {
    public init() {}

    public var today: DayNumber {
        DayNumber(date: Date())
    }
}
