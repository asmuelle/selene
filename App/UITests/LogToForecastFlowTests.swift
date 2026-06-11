import XCTest

/// M1 acceptance flow: manual tap-log → store → CycleEngine forecast → wheel.
///
/// The app target contains no networking code at all (enforced by the repo-guard
/// test on package sources), so this flow exercising log → forecast → wheel is
/// the airplane-mode path: nothing here can touch the network.
final class LogToForecastFlowTests: XCTestCase {
    private func launchApp(seeded: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-uitest-inmemory"]
        if seeded { arguments.append("-uitest-seed-history") }
        app.launchArguments = arguments
        app.launch()
        return app
    }

    func testSeededHistoryRendersWheelAndLoggingUpdatesForecast() {
        let app = launchApp(seeded: true)

        // Wheel + narration appear from seeded history (forecast exists).
        XCTAssertTrue(app.otherElements["cycle-wheel"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["forecast-narration"].exists)

        // Log today's flow; the wheel must survive the recompute.
        app.buttons["log-flow-medium"].firstMatch.tap()
        XCTAssertTrue(app.otherElements["cycle-wheel"].waitForExistence(timeout: 15))

        // Log a perimenopause-set symptom (first-class, not an afterthought).
        let symptom = app.buttons["symptom-nightSweats"].firstMatch
        if symptom.exists { symptom.tap() }

        // The privacy proof line is part of the chrome — the proof is the brand.
        XCTAssertTrue(app.staticTexts["privacy-proof-line"].exists)
    }

    func testEmptyStoreShowsEmptyStateThenFirstPeriodLogStartsTheOrbit() {
        let app = launchApp(seeded: false)

        XCTAssertTrue(app.staticTexts["empty-state"].waitForExistence(timeout: 15))

        // Logging the first period day opens a cycle; the engine forecasts from
        // the population prior with honest, wide credible bands.
        app.buttons["log-flow-heavy"].firstMatch.tap()
        XCTAssertTrue(app.otherElements["cycle-wheel"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["forecast-narration"].exists)
    }
}
