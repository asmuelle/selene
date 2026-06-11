import SeleneCore
@testable import SeleneUI
import Testing

@Suite("Cycle wheel geometry")
struct CycleWheelGeometryTests {
    @Test("day zero sits at the top of the wheel")
    func anchorAtTop() {
        // Arrange
        let geometry = CycleWheelGeometry(ringDays: 28, anchorDay: DayNumber(20500))

        // Act & Assert: top of the ring is -π/2 in screen coordinates.
        #expect(abs(geometry.angle(for: DayNumber(20500)) - (-Double.pi / 2)) < 1e-12)
    }

    @Test("a quarter of the cycle advances a quarter turn clockwise")
    func quarterTurn() {
        // Arrange
        let geometry = CycleWheelGeometry(ringDays: 28, anchorDay: DayNumber(0))

        // Act
        let angle = geometry.angle(forDayOffset: 7)

        // Assert: -π/2 + π/2 = 0 (3 o'clock).
        #expect(abs(angle) < 1e-12)
    }

    @Test("a full ring is one revolution")
    func fullRevolution() {
        let geometry = CycleWheelGeometry(ringDays: 28, anchorDay: DayNumber(0))
        let delta = geometry.angle(forDayOffset: 28) - geometry.angle(forDayOffset: 0)
        #expect(abs(delta - 2 * .pi) < 1e-12)
    }

    @Test("arc sweep is proportional to credible-interval width")
    func arcSweepMatchesIntervalWidth() {
        // Arrange
        let geometry = CycleWheelGeometry(ringDays: 28, anchorDay: DayNumber(20500))
        let window = ForecastWindow(medianDay: 20528, intervals: [
            CredibleInterval(level: 0.5, lowerDay: 20526, upperDay: 20530),
            CredibleInterval(level: 0.95, lowerDay: 20521, upperDay: 20535),
        ])

        // Act
        let arcs = geometry.arcs(for: window)

        // Assert: widest level renders first; sweep ∝ width (4 vs 14 days).
        #expect(arcs.map(\.level) == [0.95, 0.5])
        let narrowSweep = arcs[1].sweep
        let wideSweep = arcs[0].sweep
        #expect(abs(narrowSweep - 4.0 / 28.0 * 2 * .pi) < 1e-12)
        #expect(abs(wideSweep - 14.0 / 28.0 * 2 * .pi) < 1e-12)
    }

    @Test("ring days are clamped to a sane floor")
    func ringFloorClamp() {
        let geometry = CycleWheelGeometry(ringDays: 1, anchorDay: DayNumber(0))
        #expect(geometry.ringDays == 10)
    }

    @Test("progress clamps to the 0...1 ring range")
    func progressClamping() {
        let geometry = CycleWheelGeometry(ringDays: 28, anchorDay: DayNumber(100))
        #expect(geometry.progress(to: DayNumber(86)) == 0)
        #expect(abs(geometry.progress(to: DayNumber(114)) - 0.5) < 1e-12)
        #expect(geometry.progress(to: DayNumber(200)) == 1)
    }
}

@Suite("Design tokens")
struct DesignTokenTests {
    @Test("all palette components are valid sRGB values")
    func paletteComponentsInRange() {
        for token in SelenePalette.all {
            for component in [token.red, token.green, token.blue, token.opacity] {
                #expect((0.0 ... 1.0).contains(component), "\(token.name) out of range")
            }
        }
    }

    @Test("palette token names are unique")
    func uniqueTokenNames() {
        let names = SelenePalette.all.map(\.name)
        #expect(Set(names).count == names.count)
    }

    @Test("night and daylight themes are distinct and share the single gold accent")
    func themesAreIntentional() {
        // Both themes are first-class: different surfaces, same reserved accent.
        #expect(SeleneTheme.night.surface != SeleneTheme.daylight.surface)
        #expect(SeleneTheme.night.text != SeleneTheme.daylight.text)
        #expect(SeleneTheme.night.accentToday == SeleneTheme.daylight.accentToday)
        // Semantic colors stay semantic across themes.
        #expect(SeleneTheme.night.flow == SeleneTheme.daylight.flow)
        #expect(SeleneTheme.night.fertileBand == SeleneTheme.daylight.fertileBand)
    }

    @Test("night surface is dark and night text is light (contrast sanity)")
    func nightContrast() {
        let surface = SeleneTheme.night.surface
        let text = SeleneTheme.night.text
        let surfaceLuma = (surface.red + surface.green + surface.blue) / 3
        let textLuma = (text.red + text.green + text.blue) / 3
        #expect(surfaceLuma < 0.25)
        #expect(textLuma > 0.8)
    }
}
