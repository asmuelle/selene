import CycleEngine
@testable import DoctorVisit
import Foundation
import SeleneCore
import Testing

@Suite("Doctor-visit rendering seam")
struct DoctorVisitRendererTests {
    private func sampleDocument() -> DoctorVisitDocument {
        DoctorVisitDocument(
            dateRange: DayNumber(20340) ... DayNumber(20454),
            generatedAtDay: DayNumber(20454),
            stats: DocumentCycleStats(
                cycleCount: 2, meanLengthDays: 28, shortestLengthDays: 28, longestLengthDays: 28
            ),
            symptomClusters: [
                SymptomClusterRow(
                    code: .nightSweats, dayCount: 3, occurrences: 3,
                    meanSeverity: 2, peakSeverity: .strong
                ),
            ],
            forecastWindows: [
                DocumentForecastWindow(
                    title: DoctorVisitCopy.nextPeriodTitle,
                    medianDay: 20460,
                    intervals: [
                        DocumentForecastInterval(level: 0.5, lowerDay: 20458, upperDay: 20462),
                        DocumentForecastInterval(level: 0.8, lowerDay: 20456, upperDay: 20464),
                    ]
                ),
            ],
            engineVersion: "cycle-engine/1.0.0",
            citations: DoctorVisitCopy.standingCitations
        )
    }

    @Test("plain-text renderer is deterministic and includes the engine interval bounds")
    func plainTextDeterministic() {
        let renderer = PlainTextDoctorVisitRenderer()
        let document = sampleDocument()

        let textA = renderer.plainText(document)
        let textB = renderer.plainText(document)
        #expect(textA == textB)

        // The rendered text surfaces the engine bounds carried in the document.
        #expect(textA.contains("50% window"))
        #expect(textA.contains("Night sweats"))
        #expect(textA.contains(DoctorVisitCopy.disclaimer))
    }

    @Test("renderer emits non-empty UTF-8 bytes")
    func bytesProduced() throws {
        let data = try PlainTextDoctorVisitRenderer().render(sampleDocument())
        #expect(!data.isEmpty)
        #expect(String(data: data, encoding: .utf8) != nil)
    }

    @Test("rendered text introduces no value the document did not carry")
    func noFabricatedValues() {
        // A document with no symptoms must render the empty note, never a guess.
        let empty = DoctorVisitDocument(
            dateRange: DayNumber(0) ... DayNumber(10),
            generatedAtDay: DayNumber(10),
            stats: DocumentCycleStats(
                cycleCount: 0, meanLengthDays: nil,
                shortestLengthDays: nil, longestLengthDays: nil
            ),
            symptomClusters: [],
            forecastWindows: [],
            engineVersion: nil,
            citations: []
        )
        let text = PlainTextDoctorVisitRenderer().plainText(empty)
        #expect(text.contains(DoctorVisitCopy.emptyClustersNote))
        #expect(text.contains(DoctorVisitCopy.emptyCyclesNote))
    }
}
