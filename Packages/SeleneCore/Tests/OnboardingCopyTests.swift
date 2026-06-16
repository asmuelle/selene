import Foundation
@testable import SeleneCore
import Testing

@Suite("Onboarding copy")
struct OnboardingCopyTests {
    /// Same 1.4.1 / SaMD bar (invariant #5) applied to the funnel's questions and
    /// option labels — onboarding is a marketing surface and must make no claim.
    static let bannedWordPrefixes = [
        "diagnos", "treat", "cure", "prevent", "contracept", "conceiv",
        "clinically", "guarantee", "accura", "proven", "fda",
        "medical-grade", "effectiv", "birth control",
    ]

    @Test(
        "no banned medical-claim language in any onboarding string",
        arguments: bannedWordPrefixes
    )
    func bannedLanguageScan(prefix: String) throws {
        let pattern = try NSRegularExpression(
            pattern: "\\b\(NSRegularExpression.escapedPattern(for: prefix))",
            options: [.caseInsensitive]
        )
        for copy in OnboardingFunnel.allShippedStrings {
            let hits = pattern.numberOfMatches(
                in: copy, range: NSRange(copy.startIndex..., in: copy)
            )
            #expect(hits == 0, "banned term '\(prefix)' in onboarding copy: \"\(copy)\"")
        }
    }
}
