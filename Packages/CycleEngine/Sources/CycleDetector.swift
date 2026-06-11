import SeleneCore

/// Derives `Cycle` boundaries from raw daily logs.
///
/// Pure and deterministic: same logs in, same cycles out. Spotting never starts a
/// cycle (`FlowLevel.isPeriodFlow`), and implausibly long/short cycles are kept but
/// flagged anomalous so the forecaster can exclude them.
public enum CycleDetector {
    public struct Config: Sendable {
        /// Minimum number of flow-free days required before a period day counts
        /// as the start of a new cycle.
        public let minGapDays: Int
        /// Closed-cycle lengths outside this range are flagged anomalous.
        public let plausibleLengthRange: ClosedRange<Int>

        public init(minGapDays: Int, plausibleLengthRange: ClosedRange<Int>) {
            self.minGapDays = minGapDays
            self.plausibleLengthRange = plausibleLengthRange
        }

        public static let standard = Config(minGapDays: 5, plausibleLengthRange: 15 ... 90)
    }

    /// Detects cycles from logs. The most recent cycle is always open (`endDay == nil`).
    public static func detectCycles(
        from logs: [DailyLog],
        config: Config = .standard
    ) -> [Cycle] {
        let periodDays = logs
            .filter { $0.flow?.isPeriodFlow == true }
            .map(\.day)
            .sorted()
            .reduce(into: [DayNumber]()) { unique, day in
                if unique.last != day { unique.append(day) }
            }

        let starts = cycleStarts(periodDays: periodDays, minGapDays: config.minGapDays)
        return zipWithNext(starts).map { start, nextStart in
            let length = nextStart.map { start.distance(to: $0) }
            let isAnomalous = length.map { !config.plausibleLengthRange.contains($0) } ?? false
            return Cycle(
                id: deterministicCycleID(startDay: start),
                startDay: start,
                endDay: nextStart,
                source: .logged,
                isAnomalous: isAnomalous
            )
        }
    }

    // MARK: - Private

    private static func cycleStarts(periodDays: [DayNumber], minGapDays: Int) -> [DayNumber] {
        periodDays.reduce(into: [DayNumber]()) { starts, day in
            guard let previousFlowDay = lastFlowDay(upTo: day, in: periodDays) else {
                starts.append(day)
                return
            }
            if previousFlowDay.distance(to: day) > minGapDays {
                starts.append(day)
            }
        }
    }

    private static func lastFlowDay(upTo day: DayNumber, in sortedDays: [DayNumber]) -> DayNumber? {
        sortedDays.last { $0 < day }
    }

    private static func zipWithNext(_ days: [DayNumber]) -> [(DayNumber, DayNumber?)] {
        days.enumerated().map { index, day in
            (day, index + 1 < days.count ? days[index + 1] : nil)
        }
    }

    /// Cycles get a stable id derived from their start day so repeated detection
    /// runs over the same logs produce identical values (bit-reproducibility).
    private static func deterministicCycleID(startDay: DayNumber) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        let value = UInt64(bitPattern: Int64(startDay.value))
        for index in 0 ..< 8 {
            bytes[index] = UInt8((value >> (8 * UInt64(index))) & 0xFF)
        }
        // Fixed namespace marker in the upper half: "SELENCYC" in ASCII.
        let marker: [UInt8] = [0x53, 0x45, 0x4C, 0x45, 0x4E, 0x43, 0x59, 0x43]
        for index in 0 ..< 8 {
            bytes[8 + index] = marker[index]
        }
        return uuid(from: bytes)
    }

    private static func uuid(from bytes: [UInt8]) -> UUID {
        UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

import struct Foundation.UUID
