/// Every user-facing string on the paywall surface, in one place — so the
/// banned-language scan (App Review 1.4.1: no medical-claim language) runs
/// against exactly what ships, and the copy stays honest by test.
///
/// Tone: Lunar Almanac — quiet confidence. State the price, the trial terms,
/// and the privacy promise plainly; promise patterns and grounded answers,
/// never outcomes.
public enum PaywallCopy {
    // MARK: - Headline

    public static let headline = "Selene Plus"
    public static let subheadline = "Grounded answers, pattern narration, and "
        + "doctor-visit summaries — computed entirely on this device."

    // MARK: - Offers (prices come from the store at runtime; these are the

    // honest fallbacks when the store is unreachable)

    public static let fallbackAnnualPrice = "$39.99"
    public static let fallbackLifetimePrice = "$89.99"

    public static func annualOfferLine(price: String) -> String {
        "7 days free, then \(price) per year"
    }

    public static func lifetimeOfferLine(price: String) -> String {
        "\(price) once — yours for good"
    }

    public static let annualActionTitle = "Start 7-day free trial"
    public static let annualResubscribeTitle = "Subscribe for a year"
    public static let lifetimeActionTitle = "Buy lifetime"
    public static let restoreActionTitle = "Restore purchases"

    public static func trialTerms(price: String) -> String {
        "The 7-day trial is free. After it ends, the annual plan renews at "
            + "\(price) per year until you cancel — manage or cancel anytime "
            + "in your App Store settings."
    }

    // MARK: - Promises (the honest kind)

    public static let privacyPromise = "No account. No analytics. Your cycle data "
        + "never leaves this device — the only thing that touches the network "
        + "is the App Store purchase itself."

    public static let freeForeverNote = "Logging, your full history, and export "
        + "stay free forever. Selene Plus adds the insight layer on top."

    public static let honestyNote = "Selene describes patterns in your own data "
        + "and answers from a cited library. It never tells you what a symptom "
        + "means, and it never decides anything for your body."

    // MARK: - Locked insight surface (the teaser card)

    public static let lockedCardTitle = "Ask Selene"
    public static let lockedCardBody = "Questions about your cycle, fertility "
        + "signals, or perimenopause — answered on this device, with every "
        + "claim citing its source."
    public static let lockedCardAction = "See Selene Plus"

    /// Everything above, for the banned-language scan. Add new copy here —
    /// the test fails if a string ships outside the scan.
    public static var allShippedStrings: [String] {
        [
            headline,
            subheadline,
            annualOfferLine(price: fallbackAnnualPrice),
            lifetimeOfferLine(price: fallbackLifetimePrice),
            annualActionTitle,
            annualResubscribeTitle,
            lifetimeActionTitle,
            restoreActionTitle,
            trialTerms(price: fallbackAnnualPrice),
            privacyPromise,
            freeForeverNote,
            honestyNote,
            lockedCardTitle,
            lockedCardBody,
            lockedCardAction,
        ] + PurchaseError.allUserMessages
    }
}

extension PurchaseError {
    /// All user-facing failure copy — scanned alongside the paywall strings.
    static var allUserMessages: [String] {
        let cases: [PurchaseError] = [
            .productsUnavailable, .purchaseCancelled, .purchasePending,
            .purchaseFailed, .restoreFailed,
        ]
        return cases.map(\.userMessage)
    }
}
