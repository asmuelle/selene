import CycleEngine
import SeleneCore
import Testing

@Suite("Symptom cluster analyzer")
struct SymptomClusterAnalyzerTests {
    private let range = DayNumber(100) ... DayNumber(200)

    private func event(_ day: Int, _ code: SymptomCode, _ severity: Severity) -> SymptomEvent {
        SymptomEvent(day: DayNumber(day), code: code, severity: severity)
    }

    @Test("aggregates frequency and mean severity per symptom")
    func aggregatesCorrectly() {
        let events = [
            event(110, .hotFlashes, .moderate),
            event(120, .hotFlashes, .severe),
            event(130, .cramps, .mild),
        ]
        let rows = SymptomClusterAnalyzer.clusters(from: events, in: range)
        let hot = rows.first { $0.code == .hotFlashes }
        #expect(hot?.dayCount == 2)
        #expect(hot?.occurrences == 2)
        #expect(hot?.meanSeverity == 3) // (2 + 4) / 2
        #expect(hot?.peakSeverity == .severe)
    }

    @Test("events outside the range are excluded")
    func excludesOutOfRange() {
        let events = [
            event(50, .cramps, .strong), // before range
            event(150, .cramps, .mild), // in range
            event(250, .cramps, .severe), // after range
        ]
        let rows = SymptomClusterAnalyzer.clusters(from: events, in: range)
        #expect(rows.count == 1)
        #expect(rows.first?.occurrences == 1)
    }

    @Test("ordering is by occurrences then mean severity then taxonomy, reproducibly")
    func deterministicOrdering() {
        let events = [
            event(110, .cramps, .mild),
            event(120, .cramps, .mild),
            event(130, .hotFlashes, .severe),
            event(140, .fatigue, .moderate),
        ]
        let a = SymptomClusterAnalyzer.clusters(from: events, in: range)
        let b = SymptomClusterAnalyzer.clusters(from: events.reversed(), in: range)
        #expect(a == b)
        // cramps (2 occ) leads; then hotFlashes vs fatigue tie on 1 occ → severity.
        #expect(a.first?.code == .cramps)
        #expect(a.dropFirst().first?.code == .hotFlashes)
    }

    @Test("perimenopause filter keeps only the wedge symptoms in order")
    func perimenopauseFilter() {
        let events = [
            event(110, .cramps, .strong),
            event(120, .nightSweats, .moderate),
            event(130, .brainFog, .mild),
        ]
        let rows = SymptomClusterAnalyzer.perimenopauseClusters(from: events, in: range)
        let allWedge = rows.allSatisfy(\.code.isPerimenopauseSymptom)
        #expect(allWedge)
        #expect(Set(rows.map(\.code)) == [.nightSweats, .brainFog])
    }

    @Test("empty input yields an empty table")
    func emptyInput() {
        #expect(SymptomClusterAnalyzer.clusters(from: [], in: range).isEmpty)
    }
}
