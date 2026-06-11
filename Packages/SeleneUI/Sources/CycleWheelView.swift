#if canImport(SwiftUI)
    import Foundation
    import SeleneCore
    import SwiftUI

    /// The signature element: the cycle as a moon-phase ring.
    ///
    /// Forecast windows render as soft luminous arcs whose width *is* the credible
    /// interval; today is the single lunar-gold glow. Pure presentation — every
    /// number comes from `CycleWheelGeometry` over `CycleEngine` output.
    public struct CycleWheelView: View {
        private let geometry: CycleWheelGeometry
        private let forecast: Forecast
        private let today: DayNumber
        private let theme: SeleneTheme

        private static let ringWidth = 14.0
        private static let bandWidth = 26.0

        public init(
            forecast: Forecast,
            anchorDay: DayNumber,
            today: DayNumber,
            theme: SeleneTheme = .night
        ) {
            geometry = CycleWheelGeometry(forecast: forecast, anchorDay: anchorDay)
            self.forecast = forecast
            self.today = today
            self.theme = theme
        }

        public var body: some View {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - Self.bandWidth
                drawBaseRing(context: context, center: center, radius: radius)
                drawWindowArcs(
                    context: context, center: center, radius: radius,
                    window: forecast.ovulation, tint: theme.fertileBand
                )
                drawWindowArcs(
                    context: context, center: center, radius: radius,
                    window: forecast.nextPeriod, tint: theme.flow
                )
                drawTodayMarker(context: context, center: center, radius: radius)
            }
            .accessibilityLabel(accessibilitySummary)
        }

        // MARK: - Layers

        private func drawBaseRing(context: GraphicsContext, center: CGPoint, radius: Double) {
            let ring = Path { path in
                path.addArc(
                    center: center, radius: radius,
                    startAngle: .radians(0), endAngle: .radians(2 * .pi), clockwise: false
                )
            }
            context.stroke(
                ring,
                with: .color(theme.surfaceRaised.color),
                style: StrokeStyle(lineWidth: Self.ringWidth, lineCap: .round)
            )
        }

        private func drawWindowArcs(
            context: GraphicsContext,
            center: CGPoint,
            radius: Double,
            window: ForecastWindow,
            tint: ColorToken
        ) {
            for arc in geometry.arcs(for: window) {
                let path = Path { path in
                    path.addArc(
                        center: center, radius: radius,
                        startAngle: .radians(arc.startAngle),
                        endAngle: .radians(arc.endAngle),
                        clockwise: false
                    )
                }
                // Narrower (more certain) bands are more opaque: uncertainty is visible.
                let opacity = 0.18 + 0.32 * arc.level
                context.stroke(
                    path,
                    with: .color(tint.color.opacity(opacity)),
                    style: StrokeStyle(lineWidth: Self.bandWidth, lineCap: .round)
                )
            }
        }

        private func drawTodayMarker(context: GraphicsContext, center: CGPoint, radius: Double) {
            let angle = geometry.todayAngle(today: today)
            let position = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            let glow = Path(ellipseIn: CGRect(
                x: position.x - 11, y: position.y - 11, width: 22, height: 22
            ))
            context.fill(glow, with: .color(theme.accentToday.color.opacity(0.35)))
            let dot = Path(ellipseIn: CGRect(
                x: position.x - 6, y: position.y - 6, width: 12, height: 12
            ))
            context.fill(dot, with: .color(theme.accentToday.color))
        }

        private var accessibilitySummary: String {
            let daysToPeriod = forecast.nextPeriod.medianDayNumber.value - today.value
            return daysToPeriod >= 0
                ? "Cycle wheel. Next period most likely in \(daysToPeriod) days."
                : "Cycle wheel. Period past its most likely start."
        }
    }
#endif
