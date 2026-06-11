import XCTest

/// M3 acceptance on the simulator: the hard paywall gates the insight
/// surface, the mock purchase unlocks it end-to-end, and the unlocked ask
/// flow renders grounded answers whose citation chips resolve into the pack.
/// Commerce runs on the deterministic mock provider (the default — StoreKit
/// is config-gated off), so nothing here touches the network.
final class PaywallGateUITests: XCTestCase {
    private func launchApp(entitlement: String?) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-uitest-inmemory", "-uitest-seed-history"]
        if let entitlement {
            arguments += ["-uitest-entitlement", entitlement]
        }
        app.launchArguments = arguments
        app.launch()
        return app
    }

    private func element(in app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func scrollTo(
        _ target: XCUIElement, in app: XCUIApplication, attempts: Int = 6
    ) {
        for _ in 0 ..< attempts where !(target.exists && target.isHittable) {
            app.swipeUp()
        }
    }

    func testFreeUserSeesPaywallNotInsightAndMockTrialPurchaseUnlocks() {
        let app = launchApp(entitlement: nil)

        // Gate enforcement: the locked card renders; the ask flow does not.
        let lockedCard = element(in: app, identifier: "insight-locked-card")
        scrollTo(lockedCard, in: app)
        XCTAssertTrue(lockedCard.waitForExistence(timeout: 15))
        XCTAssertFalse(element(in: app, identifier: "ask-input").exists)
        XCTAssertFalse(element(in: app, identifier: "ask-answer").exists)

        // The designed paywall: price, trial terms, privacy promise.
        element(in: app, identifier: "insight-unlock-button").tap()
        XCTAssertTrue(element(in: app, identifier: "paywall-screen").waitForExistence(timeout: 15))
        let annualButton = element(in: app, identifier: "paywall-annual-button")
        XCTAssertTrue(annualButton.exists)
        XCTAssertTrue(annualButton.label.contains("$39.99"))
        XCTAssertTrue(annualButton.label.contains("7 days free"))
        XCTAssertTrue(element(in: app, identifier: "paywall-lifetime-button").label.contains("$89.99"))
        XCTAssertTrue(element(in: app, identifier: "paywall-trial-terms").exists)
        XCTAssertTrue(element(in: app, identifier: "paywall-privacy-promise").exists)
        XCTAssertTrue(element(in: app, identifier: "paywall-free-note").exists)
        XCTAssertTrue(element(in: app, identifier: "paywall-restore-button").exists)

        // Mock trial purchase → paywall dismisses → the ask flow is unlocked.
        annualButton.tap()
        XCTAssertTrue(element(in: app, identifier: "ask-input").waitForExistence(timeout: 15))
        XCTAssertFalse(element(in: app, identifier: "insight-locked-card").exists)
    }

    func testEntitledUserAsksAndCitationChipResolvesToPackSection() {
        let app = launchApp(entitlement: "lifetime")

        // No paywall for the lifetime owner; the ask surface renders.
        let askInput = element(in: app, identifier: "ask-input")
        scrollTo(askInput, in: app)
        XCTAssertTrue(askInput.waitForExistence(timeout: 15))
        XCTAssertFalse(element(in: app, identifier: "insight-locked-card").exists)

        // Ask via a suggestion chip; the grounded answer card appears.
        element(in: app, identifier: "ask-suggestion-0").tap()
        let answer = element(in: app, identifier: "ask-answer")
        XCTAssertTrue(answer.waitForExistence(timeout: 15))

        // Its citation chip opens the resolved pack section.
        let chip = element(in: app, identifier: "ask-citation-chip-0")
        scrollTo(chip, in: app, attempts: 2)
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        chip.tap()
        XCTAssertTrue(element(in: app, identifier: "citation-detail").waitForExistence(timeout: 15))
        XCTAssertTrue(element(in: app, identifier: "citation-detail-source").exists)
        XCTAssertTrue(element(in: app, identifier: "citation-detail-body").exists)
    }

    func testExpiredUserIsGatedAgainAndFreeTierStaysFullyUsable() {
        let app = launchApp(entitlement: "expired")

        // Free tier untouched (invariant #7): logging still works…
        XCTAssertTrue(app.buttons["log-flow-medium"].firstMatch.waitForExistence(timeout: 15))
        app.buttons["log-flow-medium"].firstMatch.tap()
        XCTAssertTrue(app.otherElements["cycle-wheel"].waitForExistence(timeout: 15))

        // …while the insight surface is locked again after expiry.
        let lockedCard = element(in: app, identifier: "insight-locked-card")
        scrollTo(lockedCard, in: app)
        XCTAssertTrue(lockedCard.waitForExistence(timeout: 15))
        XCTAssertFalse(element(in: app, identifier: "ask-input").exists)
    }
}
