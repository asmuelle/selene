import Foundation
import SeleneCore

/// Deterministic synthetic cycle history for UI tests only — never real user
/// data (AGENTS.md: no health data from real users in fixtures).
enum SeedHistory {
    /// Three completed 28-day cycles plus an open one, anchored so that "today"
    /// sits mid-cycle. Gives the engine enough history to forecast immediately.
    static func seedRegularHistory(into store: any SeleneStoring) {
        let today = DayNumber(date: Date())
        let cycleLength = 28
        let anchor = today.advanced(by: -14)
        for cycleIndex in 0 ..< 4 {
            let start = anchor.advanced(by: -cycleLength * cycleIndex)
            for offset in 0 ..< 4 {
                let log = DailyLog(
                    day: start.advanced(by: offset),
                    flow: offset == 0 ? .heavy : .medium,
                    source: .tap
                )
                try? store.saveDailyLog(log)
            }
        }
    }
}
