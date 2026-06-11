#if canImport(SwiftUI)
    import SeleneCore
    import SwiftUI

    /// The airplane-mode privacy-proof screen — proof rendered as UI chrome.
    /// Lunar-almanac styling: ink indigo, ivory text, the single gold accent
    /// reserved for the verified status.
    public struct PrivacyProofView: View {
        private let viewModel: PrivacyProofViewModel
        private let theme: SeleneTheme

        public init(viewModel: PrivacyProofViewModel, theme: SeleneTheme = .night) {
            self.viewModel = viewModel
            self.theme = theme
        }

        public var body: some View {
            ZStack {
                theme.surface.color.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: SeleneSpacing.section) {
                        statusSection
                        dataSection
                        locationSection
                        proofSection
                    }
                    .padding(SeleneSpacing.block)
                }
            }
            .accessibilityIdentifier("privacy-proof-screen")
        }

        private var statusSection: some View {
            VStack(alignment: .leading, spacing: SeleneSpacing.element) {
                Label {
                    Text("Zero egress")
                        .font(.system(.title2, design: .serif, weight: .semibold))
                } icon: {
                    Image(systemName: "airplane.circle.fill")
                }
                .foregroundStyle(theme.accentToday.color)
                Text(viewModel.egressStatusLine)
                    .font(.callout)
                    .foregroundStyle(theme.text.color)
                    .accessibilityIdentifier("privacy-egress-status")
                Text(viewModel.airplaneModeLine)
                    .font(.callout)
                    .foregroundStyle(theme.textSecondary.color)
                    .accessibilityIdentifier("privacy-airplane-line")
            }
        }

        private var dataSection: some View {
            VStack(alignment: .leading, spacing: SeleneSpacing.element) {
                sectionTitle("What exists")
                VStack(alignment: .leading, spacing: SeleneSpacing.tight) {
                    ForEach(viewModel.dataRows) { row in
                        HStack(alignment: .firstTextBaseline) {
                            Text(row.label)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(theme.text.color)
                            Spacer(minLength: SeleneSpacing.element)
                            Text(row.detail)
                                .font(.footnote)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(theme.textSecondary.color)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("privacy-data-\(row.id)")
                    }
                }
                .padding(SeleneSpacing.element)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(theme.surfaceRaised.color)
                )
            }
        }

        private var locationSection: some View {
            VStack(alignment: .leading, spacing: SeleneSpacing.element) {
                sectionTitle("Where it lives")
                Text(viewModel.locationSummary)
                    .font(.callout)
                    .foregroundStyle(theme.text.color)
                    .accessibilityIdentifier("privacy-location")
            }
        }

        private var proofSection: some View {
            VStack(alignment: .leading, spacing: SeleneSpacing.element) {
                sectionTitle("Verify it yourself")
                ForEach(Array(viewModel.proofPoints.enumerated()), id: \.offset) { index, point in
                    HStack(alignment: .firstTextBaseline, spacing: SeleneSpacing.tight) {
                        Text("\(index + 1).")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(theme.accentToday.color)
                        Text(point)
                            .font(.footnote)
                            .foregroundStyle(theme.textSecondary.color)
                    }
                }
                .accessibilityIdentifier("privacy-proof-points")
            }
        }

        private func sectionTitle(_ title: String) -> some View {
            Text(title)
                .font(.system(.headline, design: .serif))
                .foregroundStyle(theme.text.color)
        }
    }
#endif
