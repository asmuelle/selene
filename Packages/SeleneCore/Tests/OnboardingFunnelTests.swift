import Foundation
@testable import SeleneCore
import Testing

@Suite("Onboarding funnel")
struct OnboardingFunnelTests {
    @Test("the perimenopause variant lands in perimenopause mode with focus symptoms")
    func perimenopauseVariant() {
        let profile = OnboardingFunnel.profile(
            variant: .perimenopause,
            selectedMode: .cycle, // ignored by the perimenopause variant
            focusSymptoms: [.hotFlashes, .insomnia]
        )
        #expect(profile.mode == .perimenopause)
        #expect(profile.focusSymptoms == [.hotFlashes, .insomnia])
        #expect(profile.hasCompletedOnboarding)
    }

    @Test("the standard variant honours the picked mode")
    func standardVariant() {
        let profile = OnboardingFunnel.profile(
            variant: .standard,
            selectedMode: .tryingToConceive,
            focusSymptoms: []
        )
        #expect(profile.mode == .tryingToConceive)
        #expect(profile.hasCompletedOnboarding)
    }

    @Test("focus selection is filtered to offered perimenopause options")
    func focusFiltered() {
        // .cramps is not an offered perimenopause focus option → dropped.
        let profile = OnboardingFunnel.profile(
            variant: .perimenopause,
            selectedMode: .perimenopause,
            focusSymptoms: [.hotFlashes, .cramps]
        )
        #expect(profile.focusSymptoms == [.hotFlashes])
    }

    @Test("an existing prior is preserved through the funnel")
    func priorPreserved() {
        let existing = UserProfile(mode: .cycle, typicalCycleLengthPrior: 31)
        let profile = OnboardingFunnel.profile(
            variant: .perimenopause,
            selectedMode: .perimenopause,
            focusSymptoms: [.nightSweats],
            existing: existing
        )
        #expect(profile.typicalCycleLengthPrior == 31)
    }

    @Test("every focus option is a perimenopause-taxonomy symptom")
    func optionsAreWedge() {
        let allWedge = OnboardingFunnel.focusOptions.allSatisfy(\.isPerimenopauseSymptom)
        #expect(allWedge)
    }
}
