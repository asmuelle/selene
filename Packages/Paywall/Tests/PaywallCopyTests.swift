import Foundation
@testable import Paywall
import Testing

/// The 1.4.1 review pass as a test: paywall copy must contain no
/// medical-claim language, and must state the honest essentials — price,
/// trial terms, and the privacy promise.
@Suite("Paywall copy")
struct PaywallCopyTests {
    /// Word-prefix patterns of claim language that must never appear on a
    /// purchase surface (App Review 1.4.1 / SaMD line — see AGENTS.md
    /// invariant #5). Matched case-insensitively at word starts, so
    /// "diagnose/diagnosis", "treat/treatment", "prevent/prevention" all
    /// trip, while e.g. "secure" does not trip "cure".
    static let bannedWordPrefixes = [
        "diagnos", "treat", "cure", "prevent", "contracept", "conceiv",
        "fertility-aware", "clinically", "guarantee", "accura", "proven",
        "fda", "medical-grade", "effectiv", "birth control", "pregnan",
    ]

    @Test(
        "no banned medical-claim language in any shipped paywall string",
        arguments: bannedWordPrefixes
    )
    func bannedLanguageScan(prefix: String) throws {
        let pattern = try NSRegularExpression(
            pattern: "\\b\(NSRegularExpression.escapedPattern(for: prefix))",
            options: [.caseInsensitive]
        )
        for copy in PaywallCopy.allShippedStrings {
            let hits = pattern.numberOfMatches(
                in: copy, range: NSRange(copy.startIndex..., in: copy)
            )
            #expect(hits == 0, "banned term '\(prefix)' in shipped copy: \"\(copy)\"")
        }
    }

    @Test("offer copy states the real prices")
    func pricesStated() {
        #expect(PaywallCopy.annualOfferLine(price: PaywallCopy.fallbackAnnualPrice)
            .contains("$39.99"))
        #expect(PaywallCopy.lifetimeOfferLine(price: PaywallCopy.fallbackLifetimePrice)
            .contains("$89.99"))
    }

    @Test("trial terms are explicit: free length, renewal price, how to cancel")
    func trialTermsExplicit() {
        let terms = PaywallCopy.trialTerms(price: PaywallCopy.fallbackAnnualPrice)
        #expect(terms.contains("7-day"))
        #expect(terms.contains("free"))
        #expect(terms.contains("$39.99"))
        #expect(terms.lowercased().contains("cancel"))
    }

    @Test("the privacy promise names the one thing that touches the network")
    func privacyPromiseHonest() {
        #expect(PaywallCopy.privacyPromise.contains("never leaves this device"))
        #expect(PaywallCopy.privacyPromise.contains("App Store"))
        #expect(PaywallCopy.privacyPromise.contains("No account"))
    }

    @Test("the paywall itself restates that logging stays free (invariant #7)")
    func freeForeverRestated() {
        #expect(PaywallCopy.freeForeverNote.contains("free forever"))
        #expect(PaywallCopy.freeForeverNote.lowercased().contains("export"))
    }

    @Test("the honesty note disclaims interpretation in plain words")
    func honestyNotePresent() {
        #expect(PaywallCopy.honestyNote.contains("never tells you what a symptom means"))
        #expect(PaywallCopy.honestyNote.contains("cited library"))
    }
}
