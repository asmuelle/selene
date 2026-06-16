import CycleEngine
@testable import InsightKit
import SeleneCore
import Testing

@Suite("Insight ordering (perimenopause funnel)")
struct InsightOrderingTests {
    @Test("perimenopause mode leads with perimenopause-relevant surfaces")
    func perimenopauseLeads() {
        let order = InsightOrdering.surfaces(for: UserProfile(mode: .perimenopause))
        #expect(order.first == .perimenopauseSymptomReport)
        // The forecast wheel still appears — engine numbers are never removed,
        // only reordered.
        #expect(order.contains(.forecastWheel))
        // The doctor-visit prompt (the wedge's conversion artifact) is surfaced early.
        let promptIndex = order.firstIndex(of: .doctorVisitPrompt)
        let wheelIndex = order.firstIndex(of: .forecastWheel)
        #expect((promptIndex ?? .max) < (wheelIndex ?? .min))
    }

    @Test("cycle mode leads with the forecast wheel")
    func cycleLeadsWithWheel() {
        let order = InsightOrdering.surfaces(for: UserProfile(mode: .cycle))
        #expect(order.first == .forecastWheel)
        #expect(!order.contains(.perimenopauseSymptomReport))
    }

    @Test("TTC mode also leads with the forecast wheel")
    func ttcLeadsWithWheel() {
        let order = InsightOrdering.surfaces(for: UserProfile(mode: .tryingToConceive))
        #expect(order.first == .forecastWheel)
    }

    @Test("recent perimenopause symptoms boost the report even in cycle mode")
    func clusterSignalBoosts() {
        let clusters = [
            SymptomClusterRow(
                code: .hotFlashes, dayCount: 4, occurrences: 4,
                meanSeverity: 3, peakSeverity: .strong
            ),
        ]
        let order = InsightOrdering.surfaces(
            for: UserProfile(mode: .cycle), recentClusters: clusters
        )
        #expect(order.contains(.perimenopauseSymptomReport))
        #expect(order.first == .forecastWheel) // wheel still leads in cycle mode
    }

    @Test("no perimenopause signal in cycle mode keeps the report out")
    func noBoostWithoutSignal() {
        let clusters = [
            SymptomClusterRow(
                code: .cramps, dayCount: 2, occurrences: 2,
                meanSeverity: 2, peakSeverity: .moderate
            ),
        ]
        let order = InsightOrdering.surfaces(
            for: UserProfile(mode: .cycle), recentClusters: clusters
        )
        #expect(!order.contains(.perimenopauseSymptomReport))
    }

    @Test("ordering is deterministic")
    func deterministic() {
        let profile = UserProfile(mode: .perimenopause)
        #expect(InsightOrdering.surfaces(for: profile) == InsightOrdering.surfaces(for: profile))
    }
}
