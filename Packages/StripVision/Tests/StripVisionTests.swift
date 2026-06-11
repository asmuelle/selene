@testable import StripVision
import Testing

@Suite("Strip confidence policy")
struct StripConfidencePolicyTests {
    @Test("below-threshold confidence yields unclear-retest, never a guess")
    func lowConfidenceIsUnclear() {
        // Arrange
        let policy = StripConfidencePolicy(minimumConfidence: 0.85)
        let faint = StripClassification(
            testType: .lh, result: .positive, lineIntensity: 0.2, confidence: 0.6
        )

        // Act
        let advisory = policy.evaluate(faint)

        // Assert
        #expect(advisory == .unclearRetest)
    }

    @Test("invalid strips are always unclear regardless of confidence")
    func invalidIsAlwaysUnclear() {
        // Arrange
        let policy = StripConfidencePolicy()
        let invalid = StripClassification(
            testType: .hcg, result: .invalid, lineIntensity: 0.9, confidence: 0.99
        )

        // Act & Assert
        #expect(policy.evaluate(invalid) == .unclearRetest)
    }

    @Test("confident results are advisory — they never carry an auto-commit path")
    func confidentResultIsAdvisoryOnly() {
        // Arrange
        let policy = StripConfidencePolicy()
        let clear = StripClassification(
            testType: .lh, result: .positive, lineIntensity: 0.95, confidence: 0.97
        )

        // Act
        let advisory = policy.evaluate(clear)

        // Assert: the only non-unclear case wraps the classification for user
        // confirmation (invariant #5) — there is no third, auto-committing case.
        switch advisory {
        case .unclearRetest:
            Issue.record("confident classification should be advisory")
        case let .advisory(classification):
            #expect(classification == clear)
        }
    }

    @Test("threshold boundary is inclusive")
    func thresholdBoundary() {
        let policy = StripConfidencePolicy(minimumConfidence: 0.85)
        let atThreshold = StripClassification(
            testType: .lh, result: .negative, lineIntensity: 0.5, confidence: 0.85
        )
        #expect(policy.evaluate(atThreshold) == .advisory(atThreshold))
    }
}

@Suite("Mock strip classifier")
struct MockStripClassifierTests {
    @Test("classification is deterministic for identical input")
    func deterministicClassification() throws {
        // Arrange
        let classifier = MockStripClassifier()
        let payload: [UInt8] = [200, 13, 14]

        // Act
        let first = try classifier.classify(pixelData: payload, testType: .lh)
        let second = try classifier.classify(pixelData: payload, testType: .lh)

        // Assert
        #expect(first == second)
        #expect(first.result == .positive)
    }

    @Test("empty payload classifies as low-confidence negative")
    func emptyPayload() throws {
        let classifier = MockStripClassifier()
        let result = try classifier.classify(pixelData: [], testType: .hcg)
        #expect(result.result == .negative)
        #expect(result.confidence == 0)
        // And the policy correctly refuses to surface it.
        #expect(StripConfidencePolicy().evaluate(result) == .unclearRetest)
    }
}
