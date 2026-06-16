import Foundation
@testable import SeleneCore
import Testing

@Suite("UserProfile backward-compatible decoding")
struct UserProfileCompatTests {
    @Test("a pre-M4 profile JSON (no M4 keys) decodes with defaults")
    func preM4ProfileDecodes() throws {
        // Arrange: exactly the shape a pre-M4 build wrote.
        let legacy = """
        {"mode":"cycle","hasSeenBackupGuidance":true}
        """
        let data = Data(legacy.utf8)

        // Act
        let profile = try JSONDecoder().decode(UserProfile.self, from: data)

        // Assert: old fields preserved, new fields defaulted (not a corrupt row).
        #expect(profile.mode == .cycle)
        #expect(profile.hasSeenBackupGuidance)
        #expect(profile.focusSymptoms.isEmpty)
        #expect(!profile.hasCompletedOnboarding)
    }

    @Test("a perimenopause profile with focus symptoms round-trips")
    func roundTripWithFocus() throws {
        let profile = UserProfile(
            mode: .perimenopause,
            focusSymptoms: [.hotFlashes, .nightSweats],
            hasCompletedOnboarding: true
        )
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: data)
        #expect(decoded == profile)
    }

    @Test("an empty object decodes to the default profile")
    func emptyObjectIsDefault() throws {
        let decoded = try JSONDecoder().decode(UserProfile.self, from: Data("{}".utf8))
        #expect(decoded == UserProfile())
    }

    @Test("adoptingPerimenopauseFocus switches mode and records completion")
    func adoptHelper() {
        let base = UserProfile(mode: .cycle, typicalCycleLengthPrior: 30)
        let updated = base.adoptingPerimenopauseFocus([.brainFog])
        #expect(updated.mode == .perimenopause)
        #expect(updated.focusSymptoms == [.brainFog])
        #expect(updated.hasCompletedOnboarding)
        #expect(updated.typicalCycleLengthPrior == 30) // preserved immutably
    }
}
