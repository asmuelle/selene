import SeleneCore

/// Scores any `SymptomExtracting` implementation against the labeled corpus.
///
/// Micro-averaged precision/recall/F1 over symptom codes across all cases, plus
/// flow accuracy where a case states an expected flow. Deterministic for a
/// deterministic extractor. Used as a gate: the mock must clear the threshold
/// locally; the real-model eval is documented as device-blocked (no Apple
/// Intelligence in CI — see DESIGN.md M4).
public struct ExtractionEvalReport: Hashable, Sendable {
    public let caseCount: Int
    public let truePositives: Int
    public let falsePositives: Int
    public let falseNegatives: Int
    public let flowChecked: Int
    public let flowCorrect: Int

    public var precision: Double {
        let denom = truePositives + falsePositives
        return denom == 0 ? 1 : Double(truePositives) / Double(denom)
    }

    public var recall: Double {
        let denom = truePositives + falseNegatives
        return denom == 0 ? 1 : Double(truePositives) / Double(denom)
    }

    public var f1: Double {
        let denom = precision + recall
        return denom == 0 ? 0 : 2 * precision * recall / denom
    }

    public var flowAccuracy: Double {
        flowChecked == 0 ? 1 : Double(flowCorrect) / Double(flowChecked)
    }

    /// Documented gating thresholds. The mock clears these locally; a real
    /// FoundationModels extractor must match or beat them before it is allowed
    /// to ship as the default provider.
    public static let precisionGate = 0.85
    public static let recallGate = 0.85
    public static let flowAccuracyGate = 0.80

    public var passesGate: Bool {
        precision >= Self.precisionGate
            && recall >= Self.recallGate
            && flowAccuracy >= Self.flowAccuracyGate
    }
}

public enum ExtractionEval {
    /// Runs `extractor` against the supplied corpus and returns a scored report.
    public static func run(
        _ extractor: any SymptomExtracting,
        corpus: [ExtractionCase] = ExtractionCorpus.cases
    ) async -> ExtractionEvalReport {
        var truePositives = 0
        var falsePositives = 0
        var falseNegatives = 0
        var flowChecked = 0
        var flowCorrect = 0

        for testCase in corpus {
            let result = await extractor.extract(from: testCase.phrase)
            let predicted = result.codes
            let expected = testCase.expectedCodes

            truePositives += predicted.intersection(expected).count
            falsePositives += predicted.subtracting(expected).count
            falseNegatives += expected.subtracting(predicted).count

            if let expectedFlow = testCase.expectedFlow {
                flowChecked += 1
                if result.flow == expectedFlow {
                    flowCorrect += 1
                }
            }
        }

        return ExtractionEvalReport(
            caseCount: corpus.count,
            truePositives: truePositives,
            falsePositives: falsePositives,
            falseNegatives: falseNegatives,
            flowChecked: flowChecked,
            flowCorrect: flowCorrect
        )
    }
}
