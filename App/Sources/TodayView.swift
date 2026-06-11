import Paywall
import SeleneCore
import SeleneUI
import SwiftUI

/// The main surface: lunar-almanac wheel above, tap-logging below, and the
/// gated insight layer (M3) at the end. Calm, precise, no pink-petal idiom —
/// deep ink indigo, moonlight ivory, one lunar-gold accent.
struct TodayView: View {
    let model: AppModel
    let entitlements: EntitlementStore
    let ask: AskSeleneModel
    @State private var isShowingPrivacyProof = false
    private let theme = SeleneTheme.night

    var body: some View {
        ZStack {
            theme.surface.color.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: SeleneSpacing.section) {
                    header
                    wheelSection
                    intervalSection
                    if let message = model.errorMessage {
                        errorBanner(message)
                    }
                    flowSection
                    symptomSection
                    InsightSection(entitlements: entitlements, ask: ask, theme: theme)
                }
                .padding(SeleneSpacing.block)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await entitlements.refresh()
            entitlements.startObservingUpdates()
        }
        .sheet(isPresented: $isShowingPrivacyProof) {
            PrivacyProofView(viewModel: PrivacyProofViewModel(inventory: model.dataInventory), theme: theme)
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: SeleneSpacing.tight) {
                Text("Selene")
                    .font(.system(.largeTitle, design: .serif, weight: .semibold))
                    .foregroundStyle(theme.text.color)
                Text("Everything stays on this device — works in airplane mode.")
                    .font(.footnote)
                    .foregroundStyle(theme.textSecondary.color)
                    .accessibilityIdentifier("privacy-proof-line")
            }
            Spacer(minLength: SeleneSpacing.element)
            Button {
                isShowingPrivacyProof = true
            } label: {
                Image(systemName: "airplane.circle")
                    .font(.title2)
                    .foregroundStyle(theme.accentToday.color)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Privacy proof")
            .accessibilityIdentifier("privacy-proof-button")
        }
    }

    /// The engine's credible intervals, rendered verbatim (invariant #3): the
    /// presentation layer passes every bound through bit-exact.
    @ViewBuilder private var intervalSection: some View {
        if let presentation = model.intervalPresentation {
            VStack(alignment: .leading, spacing: SeleneSpacing.tight) {
                sectionTitle("Forecast confidence")
                ForEach(presentation.rows) { row in
                    HStack(spacing: SeleneSpacing.element) {
                        Text(row.levelLabel)
                            .font(.footnote.monospacedDigit().weight(.semibold))
                            .foregroundStyle(theme.accentToday.color)
                            .frame(width: 44, alignment: .leading)
                        Text(row.text)
                            .font(.footnote)
                            .foregroundStyle(theme.textSecondary.color)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("interval-row-\(Int((row.level * 100).rounded()))")
                }
            }
        }
    }

    @ViewBuilder private var wheelSection: some View {
        if let forecast = model.forecast, let anchor = model.anchorDay {
            VStack(alignment: .center, spacing: SeleneSpacing.block) {
                CycleWheelView(
                    forecast: forecast, anchorDay: anchor, today: model.today, theme: theme
                )
                .frame(height: 280)
                .accessibilityIdentifier("cycle-wheel")
                if let narration = model.narration {
                    Text(narration)
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(theme.text.color)
                        .accessibilityIdentifier("forecast-narration")
                }
            }
            .frame(maxWidth: .infinity)
        } else {
            Text("Log your first period day and Selene starts charting your orbit.")
                .font(.system(.callout, design: .serif))
                .foregroundStyle(theme.textSecondary.color)
                .accessibilityIdentifier("empty-state")
        }
    }

    private var flowSection: some View {
        VStack(alignment: .leading, spacing: SeleneSpacing.element) {
            sectionTitle("Today's flow")
            HStack(spacing: SeleneSpacing.tight) {
                ForEach(FlowLevel.allCases, id: \.rawValue) { level in
                    chip(
                        label: level.label,
                        isOn: model.todayLog?.flow == level,
                        tint: theme.flow
                    ) {
                        model.logFlow(model.todayLog?.flow == level ? nil : level)
                    }
                    .accessibilityIdentifier("log-flow-\(level.rawValue)")
                }
            }
        }
    }

    private var symptomSection: some View {
        VStack(alignment: .leading, spacing: SeleneSpacing.element) {
            sectionTitle("Symptoms")
            FlowLayout(spacing: SeleneSpacing.tight) {
                ForEach(SymptomCode.allCases, id: \.rawValue) { code in
                    chip(
                        label: code.label,
                        isOn: model.isSymptomLogged(code),
                        tint: theme.accentToday
                    ) {
                        model.toggleSymptom(code)
                    }
                    .accessibilityIdentifier("symptom-\(code.rawValue)")
                }
            }
        }
    }

    // MARK: - Pieces

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(.headline, design: .serif))
            .foregroundStyle(theme.text.color)
    }

    private func chip(
        label: String, isOn: Bool, tint: ColorToken, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, SeleneSpacing.element)
                .padding(.vertical, SeleneSpacing.tight)
                .background(
                    Capsule().fill(isOn ? tint.color.opacity(0.85) : theme.surfaceRaised.color)
                )
                .foregroundStyle(isOn ? theme.surface.color : theme.text.color)
        }
        .buttonStyle(.plain)
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(theme.surface.color)
            .padding(SeleneSpacing.element)
            .background(RoundedRectangle(cornerRadius: 8).fill(theme.flow.color))
            .accessibilityIdentifier("error-banner")
    }
}

/// Minimal wrapping layout for symptom chips (no third-party layout libs — invariant #2).
struct FlowLayout: Layout {
    let spacing: Double

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()
    ) {
        let offsets = arrange(proposal: proposal, subviews: subviews).offsets
        for (subview, offset) in zip(subviews, offsets) {
            subview.place(
                at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(
        proposal: ProposedViewSize, subviews: Subviews
    ) -> (size: CGSize, offsets: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var cursor = CGPoint.zero
        var rowHeight = 0.0
        var totalWidth = 0.0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if cursor.x > 0, cursor.x + size.width > maxWidth {
                cursor.x = 0
                cursor.y += rowHeight + spacing
                rowHeight = 0
            }
            offsets.append(cursor)
            cursor.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            totalWidth = max(totalWidth, cursor.x - spacing)
        }
        return (CGSize(width: totalWidth, height: cursor.y + rowHeight), offsets)
    }
}
