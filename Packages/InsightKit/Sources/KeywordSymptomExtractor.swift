import SeleneCore

/// Deterministic rule-based symptom extractor.
///
/// Same phrase in, same candidates out — no model, no network, no randomness. It
/// is the default/test provider behind `SymptomExtracting` and the baseline the
/// extraction eval scores; the FoundationModels extractor must beat or match it
/// before it ships. Maps only into the fixed `SymptomCode` taxonomy.
public struct KeywordSymptomExtractor: SymptomExtracting {
    public let isAvailable = true

    public init() {}

    public func extract(from phrase: String) async -> ExtractionResult {
        let lower = phrase.lowercased()
        let severity = Self.severity(in: lower)
        let codes = Self.lexicon
            .filter { _, markers in markers.contains { lower.contains($0) } }
            .map(\.key)
        let symptoms = codes
            .sorted { Self.index($0) < Self.index($1) }
            .map { ExtractedSymptom(code: $0, severity: severity, confidence: 0.9) }
        return ExtractionResult(symptoms: symptoms, flow: Self.flow(in: lower))
    }

    // MARK: - Lexicon

    /// Phrase markers per symptom code. Ordered/duplicated markers are fine; the
    /// match is substring containment. Kept intentionally small and auditable.
    static let lexicon: [SymptomCode: [String]] = [
        .cramps: ["cramp", "cramping"],
        .headache: ["headache", "migraine", "head hurts"],
        .bloating: ["bloat", "bloated"],
        .breastTenderness: ["breast tender", "sore breast", "tender breast"],
        .fatigue: ["tired", "exhausted", "fatigue", "no energy", "wiped out"],
        .nausea: ["nausea", "nauseous", "queasy", "sick to my stomach"],
        .backPain: ["back pain", "back ache", "backache", "lower back"],
        .acne: ["acne", "breakout", "pimple", "spots on my face"],
        .spotting: ["spotting", "spotted"],
        .moodSwings: ["mood swing", "moody", "all over the place"],
        .anxiety: ["anxious", "anxiety", "on edge", "panicky"],
        .lowMood: ["low mood", "down", "depressed", "tearful", "weepy"],
        .irritability: ["irritable", "irritated", "snappy", "short fuse"],
        .hotFlashes: ["hot flash", "hot flush", "flushing", "overheating"],
        .nightSweats: ["night sweat", "sweating at night", "drenched"],
        .brainFog: ["brain fog", "foggy", "can't concentrate", "forgetful"],
        .insomnia: ["insomnia", "can't sleep", "couldn't sleep", "barely slept", "awake all night"],
        .cycleIrregularity: ["irregular", "skipped", "late period", "unpredictable cycle"],
        .palpitations: ["palpitation", "racing heart", "heart pounding", "fluttering"],
        .jointAches: ["joint ache", "joint pain", "achy joints", "stiff joints"],
    ]

    /// Severity cue words → fixed 1...4 scale. Defaults to moderate when a
    /// symptom is present without an intensity cue.
    static func severity(in lower: String) -> Severity {
        let severe = ["unbearable", "severe", "worst", "terrible", "really bad", "agony"]
        let strong = ["bad", "strong", "intense", "heavy", "a lot"]
        let mild = ["slight", "mild", "a little", "bit of", "minor", "barely"]
        if severe.contains(where: lower.contains) { return .severe }
        if strong.contains(where: lower.contains) { return .strong }
        if mild.contains(where: lower.contains) { return .mild }
        return .moderate
    }

    static func flow(in lower: String) -> FlowLevel? {
        if lower.contains("heavy flow") || lower.contains("heavy bleed") { return .heavy }
        if lower.contains("light flow") || lower.contains("light bleed") { return .light }
        if lower.contains("spotting") || lower.contains("spotted") { return .spotting }
        if lower.contains("period started") || lower.contains("got my period") { return .medium }
        return nil
    }

    private static func index(_ code: SymptomCode) -> Int {
        SymptomCode.allCases.firstIndex(of: code) ?? .max
    }
}
