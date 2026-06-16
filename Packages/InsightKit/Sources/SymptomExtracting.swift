import SeleneCore

/// A candidate structured entry extracted from free text or a voice transcript.
///
/// Extraction is SUGGESTIVE only: the user's confirm tap is the commit (key flow
/// #1). Candidates carry a confidence the UI can surface; nothing here is
/// auto-persisted. The taxonomy is the contract — extraction may only map into
/// `SymptomCode`.
public struct ExtractedSymptom: Hashable, Sendable {
    public let code: SymptomCode
    public let severity: Severity
    public let confidence: Double

    public init(code: SymptomCode, severity: Severity, confidence: Double) {
        self.code = code
        self.severity = severity
        self.confidence = confidence
    }
}

/// The full result of extracting from one phrase: candidate symptoms plus any
/// flow level mentioned. Empty `symptoms` is a valid result (nothing matched).
public struct ExtractionResult: Hashable, Sendable {
    public let symptoms: [ExtractedSymptom]
    public let flow: FlowLevel?

    public init(symptoms: [ExtractedSymptom], flow: FlowLevel? = nil) {
        self.symptoms = symptoms
        self.flow = flow
    }

    public static let empty = ExtractionResult(symptoms: [], flow: nil)

    /// The set of distinct codes extracted — the unit the eval scores against.
    public var codes: Set<SymptomCode> {
        Set(symptoms.map(\.code))
    }
}

/// The symptom-extraction boundary.
///
/// Implementations turn a phrase into candidate entries. The deterministic
/// `KeywordSymptomExtractor` is the test/default provider and carries the eval
/// harness; the FoundationModels-backed extractor slots in behind this protocol,
/// availability-guarded, without changing any caller (invariant: deterministic
/// before LLM; the model never auto-commits).
public protocol SymptomExtracting: Sendable {
    var isAvailable: Bool { get }
    /// Extracts candidate entries. Never throws: an unavailable or refusing model
    /// returns `.empty`, which the UI treats as "fall through to manual logging"
    /// (invariant #4 — degrade silently, never error).
    func extract(from phrase: String) async -> ExtractionResult
}
