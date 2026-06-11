import ContentPack
import CycleEngine
import EgressGuardKit
import InsightKit
import Paywall
import Persistence
import SeleneCore
import SeleneUI
import Testing

/// The runtime egress proof (invariant #1): the complete core flow — capture →
/// store → engine → narration → grounded Q&A → UI presentation — runs with the
/// URLProtocol interceptor installed, and the run fails if ANY network request
/// was attempted. This is the in-process substitute for a mitmproxy capture.
///
/// The positive control proving the harness actually catches attempts lives in
/// `PaywallTests/EgressBoundaryTests` — Paywall is the only module allowed to
/// touch networking APIs, which is exactly the boundary under test.
@Suite("No-egress proof — full core flow")
struct NoEgressFlowTests {
    /// URL marker used by the Paywall positive control; its recorded attempts
    /// are expected and excluded here (suites run in parallel).
    static let positiveControlMarker = "egress-positive-control"

    private static func coreFlowAttempts() -> [RecordedEgressAttempt] {
        EgressRecorder.attempts.filter { !$0.url.contains(positiveControlMarker) }
    }

    @Test("log → store → forecast → narration → Q&A → presentation attempts zero requests")
    func fullCoreFlowIsEgressFree() async throws {
        // Arrange: tripwire armed before any product code runs.
        EgressGuard.install()
        let store = try SeleneDatabase(inMemory: ())
        let today = DayNumber(20454)

        // Capture: three 28-day cycles of tap-logged flow plus symptoms.
        for cycleIndex in 0 ..< 3 {
            let start = DayNumber(20340 + 28 * cycleIndex)
            for offset in 0 ..< 4 {
                try store.saveDailyLog(DailyLog(
                    day: start.advanced(by: offset),
                    flow: offset == 0 ? .heavy : .medium,
                    source: .tap
                ))
            }
            try store.saveSymptomEvent(SymptomEvent(
                day: start.advanced(by: 1), code: .nightSweats, severity: .moderate
            ))
        }

        // Engine: deterministic forecast from the logged history.
        let logs = try store.dailyLogs()
        let cycles = CycleDetector.detectCycles(from: logs)
        let forecast = try BayesianForecaster.forecast(
            cycles: cycles, profile: UserProfile(), today: today
        )
        try store.saveForecast(forecast)

        // Narration + grounded Q&A over the citation-pinned pack.
        let narration = TemplateNarrator().narrate(forecast, today: today)
        let pack = ContentPackStore()
        let qa = GroundedAnswerService(
            model: MockLanguageModel(),
            retriever: KeywordRetriever(store: pack),
            pack: pack
        )
        let insight = await qa.answer(
            question: "are irregular cycles normal in perimenopause", today: today
        )

        // UI layer: wheel geometry, interval presentation, privacy proof,
        // and the paywall gate decision (pure logic — the boundary's free side).
        let geometry = CycleWheelGeometry(
            forecast: forecast, anchorDay: cycles.map(\.startDay).max() ?? today
        )
        let intervals = ForecastIntervalPresentation(window: forecast.nextPeriod, today: today)
        let privacy = try PrivacyProofViewModel(inventory: DataInventory(
            dailyLogCount: logs.count,
            symptomEventCount: store.symptomEvents().count,
            hasForecast: true,
            storage: .inMemoryEphemeral
        ))
        let gateOpen = FeatureGate().isUnlocked(
            .manualLogging, entitlement: .free, today: today
        )

        // Sanity: the flow actually produced its surfaces.
        #expect(!narration.isEmpty)
        #expect(!insight.citations.isEmpty)
        #expect(!geometry.arcs(for: forecast.nextPeriod).isEmpty)
        #expect(intervals.rows.count == 3)
        #expect(privacy.dataRows.count == 4)
        #expect(gateOpen)

        // Assert: not one network request was attempted by any of it.
        let attempts = Self.coreFlowAttempts()
        #expect(
            attempts.isEmpty,
            "core flow attempted network requests: \(attempts.map(\.url))"
        )
    }

    @Test("the M3 monetization flow on the mock provider is egress-free")
    @MainActor
    func paywallMockCommerceFlowIsEgressFree() async {
        // Arrange: tripwire armed, then the entire entitlement lifecycle on
        // the deterministic provider — the configuration every test and every
        // non-StoreKit run of the app uses. (The StoreKit adapter is config-
        // gated behind PaywallConfiguration and never constructed here.)
        EgressGuard.install()
        let clock = FixedDayClock(today: DayNumber(20454))
        let store = EntitlementStore(
            provider: MockPurchaseProvider(clock: clock), clock: clock
        )

        // Free state: AI layer locked, free tier open.
        await store.refresh()
        #expect(store.state == .free)
        #expect(!store.isUnlocked(.groundedQA))
        #expect(store.isUnlocked(.manualLogging))

        // Trial purchase unlocks the gated insight surface…
        await store.purchase(.annual)
        #expect(store.state == .trial(endsOn: DayNumber(20460)))
        #expect(store.isUnlocked(.groundedQA))

        // …which renders grounded Q&A with resolving citation chips.
        let pack = ContentPackStore()
        let qa = GroundedAnswerService(
            model: MockLanguageModel(),
            retriever: KeywordRetriever(store: pack),
            pack: pack
        )
        let insight = await qa.answer(
            question: "is a 24 day cycle normal at 44", today: clock.today
        )
        let chips = CitationPresenter.chips(for: insight, pack: pack)
        #expect(!chips.isEmpty)
        #expect(chips.count == insight.citations.count)

        // Assert: the whole monetization + insight path attempted zero requests.
        #expect(Self.coreFlowAttempts().isEmpty)
    }

    @Test("an empty-store first-run flow is also egress-free")
    func firstRunFlowIsEgressFree() throws {
        // Arrange
        EgressGuard.install()
        let store = try SeleneDatabase(inMemory: ())

        // Act: first launch — refresh against an empty store, log one period day.
        let initialLogs = try store.dailyLogs()
        #expect(initialLogs.isEmpty)
        try store.saveDailyLog(DailyLog(day: DayNumber(20454), flow: .heavy, source: .tap))
        let cycles = try CycleDetector.detectCycles(from: store.dailyLogs())
        let forecast = try BayesianForecaster.forecast(
            cycles: cycles, profile: UserProfile(), today: DayNumber(20454)
        )

        // Assert
        #expect(forecast.cycleCount == 0)
        #expect(Self.coreFlowAttempts().isEmpty)
    }
}
