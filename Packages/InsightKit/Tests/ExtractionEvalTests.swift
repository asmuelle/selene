@testable import InsightKit
import SeleneCore
import Testing

@Suite("Extraction eval")
struct ExtractionEvalTests {
    @Test("the labeled corpus has at least 40 cases and is perimenopause-weighted")
    func corpusShape() {
        #expect(ExtractionCorpus.cases.count >= 40)
        let perimenopauseCases = ExtractionCorpus.cases.filter { testCase in
            testCase.expectedCodes.contains { $0.isPerimenopauseSymptom }
        }
        #expect(perimenopauseCases.count >= 10)
    }

    @Test("the deterministic extractor clears the documented gate on the corpus")
    func mockClearsGate() async {
        let report = await ExtractionEval.run(KeywordSymptomExtractor())
        #expect(report.caseCount == ExtractionCorpus.cases.count)
        #expect(
            report.passesGate,
            "precision \(report.precision), recall \(report.recall), flow \(report.flowAccuracy)"
        )
        #expect(report.precision >= ExtractionEvalReport.precisionGate)
        #expect(report.recall >= ExtractionEvalReport.recallGate)
        #expect(report.flowAccuracy >= ExtractionEvalReport.flowAccuracyGate)
    }

    @Test("the eval is deterministic for a deterministic extractor")
    func deterministicEval() async {
        let a = await ExtractionEval.run(KeywordSymptomExtractor())
        let b = await ExtractionEval.run(KeywordSymptomExtractor())
        #expect(a == b)
    }

    @Test("negative cases produce no false positives")
    func negativesAreClean() async {
        let extractor = KeywordSymptomExtractor()
        for testCase in ExtractionCorpus.negativeCases {
            let result = await extractor.extract(from: testCase.phrase)
            #expect(result.codes.isEmpty, "false positive on: \"\(testCase.phrase)\"")
        }
    }

    @Test("precision/recall math: a perfect extractor scores 1.0")
    func perfectScore() async {
        // A scripted extractor that returns exactly the expected codes.
        let report = await ExtractionEval.run(
            PerfectExtractor(corpus: ExtractionCorpus.cases)
        )
        #expect(report.precision == 1)
        #expect(report.recall == 1)
        #expect(report.f1 == 1)
    }
}

/// Test-only extractor that echoes the expected labels — used to verify the eval
/// math itself, independent of any real extractor.
private struct PerfectExtractor: SymptomExtracting {
    let isAvailable = true
    let lookup: [String: ExtractionCase]

    init(corpus: [ExtractionCase]) {
        lookup = Dictionary(corpus.map { ($0.phrase, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func extract(from phrase: String) async -> ExtractionResult {
        guard let testCase = lookup[phrase] else { return .empty }
        let symptoms = testCase.expectedCodes.map {
            ExtractedSymptom(code: $0, severity: .moderate, confidence: 1)
        }
        return ExtractionResult(symptoms: symptoms, flow: testCase.expectedFlow)
    }
}
