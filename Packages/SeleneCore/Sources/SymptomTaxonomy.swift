/// Fixed symptom vocabulary. Free-text extraction (M2) may only ever map into these
/// codes — the taxonomy is the contract between capture, store, and engine.
public enum SymptomCode: String, CaseIterable, Codable, Sendable {
    // Core cycle set
    case cramps
    case headache
    case bloating
    case breastTenderness
    case fatigue
    case nausea
    case backPain
    case acne
    case spotting

    // Mood set
    case moodSwings
    case anxiety
    case lowMood
    case irritability

    // Perimenopause set (the underserved wedge — first-class, not an afterthought)
    case hotFlashes
    case nightSweats
    case brainFog
    case insomnia
    case cycleIrregularity
    case palpitations
    case jointAches

    /// Symptoms weighted toward the perimenopause funnel and reports.
    public static let perimenopauseSet: Set<SymptomCode> = [
        .hotFlashes, .nightSweats, .brainFog, .insomnia,
        .cycleIrregularity, .palpitations, .jointAches,
    ]

    public var isPerimenopauseSymptom: Bool {
        Self.perimenopauseSet.contains(self)
    }

    /// Human-readable label for UI chips. No medical-claim language by invariant #5.
    public var label: String {
        switch self {
        case .cramps: "Cramps"
        case .headache: "Headache"
        case .bloating: "Bloating"
        case .breastTenderness: "Breast tenderness"
        case .fatigue: "Fatigue"
        case .nausea: "Nausea"
        case .backPain: "Back pain"
        case .acne: "Acne"
        case .spotting: "Spotting"
        case .moodSwings: "Mood swings"
        case .anxiety: "Anxiety"
        case .lowMood: "Low mood"
        case .irritability: "Irritability"
        case .hotFlashes: "Hot flashes"
        case .nightSweats: "Night sweats"
        case .brainFog: "Brain fog"
        case .insomnia: "Insomnia"
        case .cycleIrregularity: "Irregular cycles"
        case .palpitations: "Palpitations"
        case .jointAches: "Joint aches"
        }
    }
}

/// Symptom severity on the fixed 1...4 scale.
public struct Severity: Hashable, Codable, Sendable, Comparable {
    public static let range = 1 ... 4

    public let value: Int

    public init?(_ value: Int) {
        guard Self.range.contains(value) else { return nil }
        self.value = value
    }

    public static let mild = Severity(1)!
    public static let moderate = Severity(2)!
    public static let strong = Severity(3)!
    public static let severe = Severity(4)!

    public static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs.value < rhs.value
    }
}
