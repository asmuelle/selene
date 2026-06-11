@testable import InsightKit
import SeleneCore
import Testing

@Suite("TemplateNarrator")
struct TemplateNarratorTests {
    private func makeForecast(
        medianDay: Double,
        cycleCount: Int = 5,
        intervals: [CredibleInterval]? = nil
    ) -> Forecast {
        let window = ForecastWindow(
            medianDay: medianDay,
            intervals: intervals ?? [
                CredibleInterval(level: 0.8, lowerDay: medianDay - 2, upperDay: medianDay + 2),
            ]
        )
        return Forecast(
            generatedAtDay: DayNumber(20600),
            engineVersion: "test",
            mode: .cycle,
            nextPeriod: window,
            ovulation: window,
            posterior: PosteriorSnapshot(mu: 28, kappa: 5, alpha: 4, beta: 30),
            inputRange: nil,
            cycleCount: cycleCount,
            seed: 0
        )
    }

    @Test("narration states days until the predicted period and the 80% window")
    func futurePeriodNarration() {
        // Arrange
        let narrator = TemplateNarrator()
        let forecast = makeForecast(medianDay: 20606)

        // Act
        let text = narrator.narrate(forecast, today: DayNumber(20600))

        // Assert
        #expect(text.contains("most likely in 6 days"))
        #expect(text.contains("80% window"))
        #expect(text.contains("Based on 5 logged cycles."))
    }

    @Test("today and overdue phrasing are handled")
    func todayAndOverdue() {
        let narrator = TemplateNarrator()
        let todayText = narrator.narrate(makeForecast(medianDay: 20600), today: DayNumber(20600))
        let overdueText = narrator.narrate(makeForecast(medianDay: 20598), today: DayNumber(20600))
        #expect(todayText.contains("Today is the most likely start"))
        #expect(overdueText.contains("past its most likely start"))
    }

    @Test("sparse histories get an honest confidence note")
    func sparseHistoryNote() {
        let narrator = TemplateNarrator()
        let firstEstimate = narrator.narrate(
            makeForecast(medianDay: 20606, cycleCount: 0), today: DayNumber(20600)
        )
        #expect(firstEstimate.contains("first estimate"))
    }

    @Test("narration is deterministic")
    func deterministicNarration() {
        let narrator = TemplateNarrator()
        let forecast = makeForecast(medianDay: 20610)
        let first = narrator.narrate(forecast, today: DayNumber(20600))
        let second = narrator.narrate(forecast, today: DayNumber(20600))
        #expect(first == second)
    }
}

@Suite("Language model boundary")
struct LanguageModelTests {
    @Test("mock model is deterministic across calls")
    func mockDeterminism() async throws {
        // Arrange
        let model = MockLanguageModel()

        // Act
        let first = try await model.respond(to: "summarize my cycle")
        let second = try await model.respond(to: "summarize my cycle")

        // Assert
        #expect(first == second)
        #expect(model.isAvailable)
    }

    @Test("mock model simulates guardrail refusals")
    func mockRefusal() async {
        // Arrange
        let model = MockLanguageModel()

        // Act & Assert
        await #expect(throws: LanguageModelError.refused) {
            _ = try await model.respond(to: "[refuse] sensitive prompt")
        }
    }

    @Test("unavailable model always throws unavailable, enabling fallback paths")
    func unavailableModel() async {
        // Arrange
        let model = UnavailableLanguageModel()

        // Act & Assert
        #expect(!model.isAvailable)
        await #expect(throws: LanguageModelError.unavailable) {
            _ = try await model.respond(to: "anything")
        }
    }

    @Test("refusal degrades to the deterministic template, never an error")
    func refusalFallsBackToTemplate() async throws {
        // Arrange: the M2 wiring pattern, proven here against the mock.
        let model = MockLanguageModel()
        let narrator = TemplateNarrator()
        let forecast = Forecast(
            generatedAtDay: DayNumber(20600),
            engineVersion: "test",
            mode: .cycle,
            nextPeriod: ForecastWindow(medianDay: 20606, intervals: []),
            ovulation: ForecastWindow(medianDay: 20592, intervals: []),
            posterior: PosteriorSnapshot(mu: 28, kappa: 5, alpha: 4, beta: 30),
            inputRange: nil,
            cycleCount: 4,
            seed: 0
        )

        // Act
        let text: String
        do {
            text = try await model.respond(to: "[refuse] narrate")
        } catch {
            text = narrator.narrate(forecast, today: DayNumber(20600))
        }

        // Assert
        #expect(text.contains("most likely in 6 days"))
    }
}
