import SeleneCore

// Test-strip classification boundary.
//
// The real implementation (a dedicated Core ML CNN behind the Vision framework)
// ships only when its held-out eval clears the accuracy gate (DESIGN.md). This
// module defines the contract plus the confidence policy that every
// implementation must flow through — and a deterministic mock so the policy is
// fully testable on macOS with no camera, no model, no photos.

public enum StripTestType: String, Codable, Sendable {
    case lh
    case hcg
}

public enum StripLineResult: String, Codable, Sendable {
    case negative
    case positive
    case invalid
}

/// Raw classifier output before policy is applied. Never shown to users directly.
public struct StripClassification: Hashable, Codable, Sendable {
    public let testType: StripTestType
    public let result: StripLineResult
    /// Relative test-line intensity in 0...1 (faint lines score low).
    public let lineIntensity: Double
    /// Classifier confidence in 0...1.
    public let confidence: Double

    public init(
        testType: StripTestType,
        result: StripLineResult,
        lineIntensity: Double,
        confidence: Double
    ) {
        self.testType = testType
        self.result = result
        self.lineIntensity = lineIntensity
        self.confidence = confidence
    }
}

/// Classifier boundary. Input is an opaque pixel payload; processed in memory,
/// never written to disk by default (DESIGN.md flow 3).
public protocol StripClassifying: Sendable {
    func classify(pixelData: [UInt8], testType: StripTestType) throws -> StripClassification
}

/// What the UI is allowed to show (invariant #5: advisory only, never auto-commit).
public enum StripAdvisory: Hashable, Sendable {
    /// Confidence too low — honest non-answer, nothing stored.
    case unclearRetest
    /// Advisory result; requires an explicit user confirmation before any
    /// `StripReading` is persisted.
    case advisory(StripClassification)
}

/// The single gate between classifier output and the UI.
public struct StripConfidencePolicy: Sendable {
    public let minimumConfidence: Double

    public init(minimumConfidence: Double = 0.85) {
        self.minimumConfidence = minimumConfidence
    }

    public func evaluate(_ classification: StripClassification) -> StripAdvisory {
        guard classification.confidence >= minimumConfidence,
              classification.result != .invalid
        else {
            return .unclearRetest
        }
        return .advisory(classification)
    }
}

/// Deterministic mock keyed on the first payload byte — no model, no randomness.
public struct MockStripClassifier: StripClassifying {
    public init() {}

    public func classify(
        pixelData: [UInt8],
        testType: StripTestType
    ) throws -> StripClassification {
        let seedByte = pixelData.first ?? 0
        let confidence = Double(seedByte) / 255.0
        let result: StripLineResult = seedByte > 127 ? .positive : .negative
        return StripClassification(
            testType: testType,
            result: result,
            lineIntensity: confidence,
            confidence: confidence
        )
    }
}
