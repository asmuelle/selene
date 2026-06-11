@testable import CycleEngine
import SeleneCore
import Testing

@Suite("CycleDetector")
struct CycleDetectorTests {
    private func flowLog(day: Int, flow: FlowLevel = .medium) -> DailyLog {
        DailyLog(day: DayNumber(day), flow: flow)
    }

    @Test("no logs produce no cycles")
    func emptyLogs() {
        #expect(CycleDetector.detectCycles(from: []).isEmpty)
    }

    @Test("consecutive flow days form a single open cycle")
    func singleEpisode() {
        // Arrange
        let logs = (100 ... 104).map { flowLog(day: $0) }

        // Act
        let cycles = CycleDetector.detectCycles(from: logs)

        // Assert
        #expect(cycles.count == 1)
        #expect(cycles[0].startDay == DayNumber(100))
        #expect(cycles[0].endDay == nil)
        #expect(!cycles[0].isAnomalous)
    }

    @Test("a gap above the threshold starts a new cycle and closes the previous one")
    func twoEpisodes() {
        // Arrange: periods at 100-103 and 128-131 (28-day cycle).
        let logs = (100 ... 103).map { flowLog(day: $0) } + (128 ... 131).map { flowLog(day: $0) }

        // Act
        let cycles = CycleDetector.detectCycles(from: logs)

        // Assert
        #expect(cycles.count == 2)
        #expect(cycles[0].startDay == DayNumber(100))
        #expect(cycles[0].endDay == DayNumber(128))
        #expect(cycles[0].length == 28)
        #expect(cycles[1].endDay == nil)
    }

    @Test("spotting never starts or extends a cycle")
    func spottingIgnored() {
        // Arrange: real period at 100, spotting mid-cycle at 114, next period at 128.
        let logs = [
            flowLog(day: 100), flowLog(day: 101),
            flowLog(day: 114, flow: .spotting),
            flowLog(day: 128), flowLog(day: 129),
        ]

        // Act
        let cycles = CycleDetector.detectCycles(from: logs)

        // Assert
        #expect(cycles.count == 2)
        #expect(cycles.map(\.startDay) == [DayNumber(100), DayNumber(128)])
    }

    @Test("a short flow-free gap does not split an episode")
    func shortGapStaysOneEpisode() {
        // Arrange: flow on 100, 101, skip 102-104, flow again on 105 (gap of 4 ≤ 5).
        let logs = [flowLog(day: 100), flowLog(day: 101), flowLog(day: 105)]

        // Act
        let cycles = CycleDetector.detectCycles(from: logs)

        // Assert
        #expect(cycles.count == 1)
    }

    @Test("implausible cycle lengths are flagged anomalous, not dropped")
    func anomalousFlagging() {
        // Arrange: 10-day cycle (too short), then a normal 28-day cycle.
        let logs = [flowLog(day: 100), flowLog(day: 110), flowLog(day: 138)]

        // Act
        let cycles = CycleDetector.detectCycles(from: logs)

        // Assert
        #expect(cycles.count == 3)
        #expect(cycles[0].isAnomalous)
        #expect(cycles[0].length == 10)
        #expect(!cycles[1].isAnomalous)
        #expect(cycles[1].length == 28)
    }

    @Test("unsorted and duplicate logs yield the same cycles as clean input")
    func unsortedInputIsNormalized() {
        // Arrange
        let clean = [flowLog(day: 100), flowLog(day: 101), flowLog(day: 128)]
        let messy = [flowLog(day: 128), flowLog(day: 101), flowLog(day: 100), flowLog(day: 101)]

        // Act
        let fromClean = CycleDetector.detectCycles(from: clean)
        let fromMessy = CycleDetector.detectCycles(from: messy)

        // Assert
        #expect(fromClean == fromMessy)
    }

    @Test("detection is deterministic including cycle ids")
    func deterministicIDs() {
        // Arrange
        let logs = [flowLog(day: 100), flowLog(day: 128)]

        // Act
        let first = CycleDetector.detectCycles(from: logs)
        let second = CycleDetector.detectCycles(from: logs)

        // Assert
        #expect(first.map(\.id) == second.map(\.id))
    }
}
