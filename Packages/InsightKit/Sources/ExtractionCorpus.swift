import SeleneCore

/// One labeled extraction case: a synthetic free-text/voice phrase and the set of
/// symptom codes a correct extraction should produce.
///
/// These phrases are SYNTHETIC — authored for the eval, never sourced from a real
/// user (AGENTS.md: no health data in fixtures). Expected codes are the unit the
/// eval scores precision/recall against; flow is checked where stated.
public struct ExtractionCase: Hashable, Sendable {
    public let phrase: String
    public let expectedCodes: Set<SymptomCode>
    public let expectedFlow: FlowLevel?

    public init(phrase: String, expectedCodes: Set<SymptomCode>, expectedFlow: FlowLevel? = nil) {
        self.phrase = phrase
        self.expectedCodes = expectedCodes
        self.expectedFlow = expectedFlow
    }
}

/// The checked-in labeled corpus for symptom extraction (≥40 cases).
///
/// Perimenopause-weighted, matching the product wedge. Any `SymptomExtracting`
/// implementation — mock or FoundationModels — is scored against this exact set
/// by `ExtractionEval`, with documented gating thresholds.
public enum ExtractionCorpus {
    public static let cases: [ExtractionCase] = perimenopauseCases
        + cycleCases
        + moodCases
        + multiSymptomCases
        + negativeCases

    // MARK: Perimenopause-weighted (the wedge)

    static let perimenopauseCases: [ExtractionCase] = [
        ExtractionCase(
            phrase: "woke up drenched in night sweats again",
            expectedCodes: [.nightSweats]
        ),
        ExtractionCase(
            phrase: "another hot flash hit me during the meeting",
            expectedCodes: [.hotFlashes]
        ),
        ExtractionCase(
            phrase: "so much brain fog today, couldn't concentrate",
            expectedCodes: [.brainFog]
        ),
        ExtractionCase(
            phrase: "barely slept, insomnia is back",
            expectedCodes: [.insomnia]
        ),
        ExtractionCase(
            phrase: "my cycles have been so irregular lately",
            expectedCodes: [.cycleIrregularity]
        ),
        ExtractionCase(
            phrase: "heart was racing, felt like palpitations",
            expectedCodes: [.palpitations]
        ),
        ExtractionCase(
            phrase: "achy joints all morning, stiff joints when I got up",
            expectedCodes: [.jointAches]
        ),
        ExtractionCase(
            phrase: "hot flushes and couldn't sleep all night",
            expectedCodes: [.hotFlashes, .insomnia]
        ),
        ExtractionCase(
            phrase: "night sweats plus foggy and forgetful",
            expectedCodes: [.nightSweats, .brainFog]
        ),
        ExtractionCase(
            phrase: "skipped my period this month, very unpredictable cycle",
            expectedCodes: [.cycleIrregularity]
        ),
        ExtractionCase(
            phrase: "overheating and heart pounding this afternoon",
            expectedCodes: [.hotFlashes, .palpitations]
        ),
        ExtractionCase(
            phrase: "exhausted and brain fog, classic perimenopause day",
            expectedCodes: [.fatigue, .brainFog]
        ),
    ]

    // MARK: Core cycle symptoms

    static let cycleCases: [ExtractionCase] = [
        ExtractionCase(
            phrase: "bad cramps since this morning",
            expectedCodes: [.cramps]
        ),
        ExtractionCase(
            phrase: "terrible headache that won't quit",
            expectedCodes: [.headache]
        ),
        ExtractionCase(
            phrase: "really bloated and uncomfortable",
            expectedCodes: [.bloating]
        ),
        ExtractionCase(
            phrase: "sore breasts, very tender today",
            expectedCodes: [.breastTenderness]
        ),
        ExtractionCase(
            phrase: "so tired, no energy at all",
            expectedCodes: [.fatigue]
        ),
        ExtractionCase(
            phrase: "felt queasy and nauseous after lunch",
            expectedCodes: [.nausea]
        ),
        ExtractionCase(
            phrase: "lower back pain all day",
            expectedCodes: [.backPain]
        ),
        ExtractionCase(
            phrase: "big breakout, acne along my jaw",
            expectedCodes: [.acne]
        ),
        ExtractionCase(
            phrase: "light spotting this morning",
            expectedCodes: [.spotting],
            expectedFlow: .spotting
        ),
        ExtractionCase(
            phrase: "cramps and a migraine together, awful",
            expectedCodes: [.cramps, .headache]
        ),
    ]

    // MARK: Mood set

    static let moodCases: [ExtractionCase] = [
        ExtractionCase(
            phrase: "mood swings all over the place today",
            expectedCodes: [.moodSwings]
        ),
        ExtractionCase(
            phrase: "feeling really anxious and on edge",
            expectedCodes: [.anxiety]
        ),
        ExtractionCase(
            phrase: "low mood, kind of tearful",
            expectedCodes: [.lowMood]
        ),
        ExtractionCase(
            phrase: "so irritable and snappy with everyone",
            expectedCodes: [.irritability]
        ),
        ExtractionCase(
            phrase: "anxious and couldn't sleep",
            expectedCodes: [.anxiety, .insomnia]
        ),
        ExtractionCase(
            phrase: "weepy and exhausted",
            expectedCodes: [.lowMood, .fatigue]
        ),
    ]

    // MARK: Multi-symptom + flow

    static let multiSymptomCases: [ExtractionCase] = [
        ExtractionCase(
            phrase: "heavy flow, bad cramps, and a headache",
            expectedCodes: [.cramps, .headache],
            expectedFlow: .heavy
        ),
        ExtractionCase(
            phrase: "got my period, feeling bloated",
            expectedCodes: [.bloating],
            expectedFlow: .medium
        ),
        ExtractionCase(
            phrase: "period started with light flow and cramping",
            expectedCodes: [.cramps],
            expectedFlow: .light
        ),
        ExtractionCase(
            phrase: "night sweats, hot flashes, and joint pain",
            expectedCodes: [.nightSweats, .hotFlashes, .jointAches]
        ),
        ExtractionCase(
            phrase: "tired, foggy, irritable, and bloated",
            expectedCodes: [.fatigue, .brainFog, .irritability, .bloating]
        ),
        ExtractionCase(
            phrase: "cramps, nausea, and lower back pain",
            expectedCodes: [.cramps, .nausea, .backPain]
        ),
        ExtractionCase(
            phrase: "anxious, palpitations, can't sleep",
            expectedCodes: [.anxiety, .palpitations, .insomnia]
        ),
        ExtractionCase(
            phrase: "mild headache and a little bloated",
            expectedCodes: [.headache, .bloating]
        ),
    ]

    // MARK: Negatives (should extract nothing)

    static let negativeCases: [ExtractionCase] = [
        ExtractionCase(
            phrase: "feeling great today, went for a long run",
            expectedCodes: []
        ),
        ExtractionCase(
            phrase: "had a lovely calm evening with friends",
            expectedCodes: []
        ),
        ExtractionCase(
            phrase: "drank plenty of water and ate well",
            expectedCodes: []
        ),
        ExtractionCase(
            phrase: "nothing to report, an ordinary day",
            expectedCodes: []
        ),
    ]
}
