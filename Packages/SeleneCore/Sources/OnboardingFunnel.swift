/// The perimenopause onboarding funnel: a small profile question set plus the
/// pure reducer that turns answers into a `UserProfile`.
///
/// The funnel is a separate marketing/onboarding variant into the same product
/// (DESIGN.md M3/M4). It only ever writes local profile fields — no account, no
/// network (invariant #6). Copy here is user-facing and scanned for banned
/// medical-claim language by the onboarding copy test (invariant #5).
public enum OnboardingFunnel {
    /// Which funnel variant the user entered through (ASO / landing split).
    public enum Variant: String, CaseIterable, Sendable {
        case standard
        case perimenopause
    }

    /// The mode-selection question — the funnel's first branch.
    public static let modeQuestion =
        "What would you like Selene to focus on?"

    /// The perimenopause focus-symptom question.
    public static let focusQuestion =
        "Which changes have you noticed recently? Pick any that apply."

    /// The focus-symptom options offered in the perimenopause funnel, in display
    /// order. Drawn from the taxonomy's perimenopause set so they map cleanly.
    public static let focusOptions: [SymptomCode] = [
        .hotFlashes, .nightSweats, .insomnia, .brainFog,
        .cycleIrregularity, .palpitations, .jointAches,
    ]

    /// Mode option labels — no medical-claim language.
    public static func modeLabel(_ mode: TrackingMode) -> String {
        switch mode {
        case .cycle: "Tracking my cycle"
        case .tryingToConceive: "Planning for pregnancy"
        case .perimenopause: "Changes around perimenopause"
        }
    }

    /// All user-facing onboarding strings, for the banned-language scan.
    public static var allShippedStrings: [String] {
        [modeQuestion, focusQuestion]
            + TrackingMode.allCases.map(modeLabel)
            + focusOptions.map(\.label)
    }

    /// Pure reducer: builds the profile from the funnel answers, preserving any
    /// existing prior. The perimenopause variant lands in perimenopause mode with
    /// the chosen focus symptoms; the standard variant honours the picked mode.
    public static func profile(
        variant: Variant,
        selectedMode: TrackingMode,
        focusSymptoms: Set<SymptomCode>,
        existing: UserProfile = UserProfile()
    ) -> UserProfile {
        switch variant {
        case .perimenopause:
            existing.adoptingPerimenopauseFocus(filteredFocus(focusSymptoms))
        case .standard:
            UserProfile(
                mode: selectedMode,
                typicalCycleLengthPrior: existing.typicalCycleLengthPrior,
                hasSeenBackupGuidance: existing.hasSeenBackupGuidance,
                focusSymptoms: filteredFocus(focusSymptoms),
                hasCompletedOnboarding: true
            )
        }
    }

    /// Keeps only offered, perimenopause-relevant codes — defends the profile
    /// against unexpected input at the boundary.
    private static func filteredFocus(_ symptoms: Set<SymptomCode>) -> Set<SymptomCode> {
        symptoms.intersection(focusOptions)
    }
}
