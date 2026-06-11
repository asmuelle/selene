import Paywall
import SeleneUI
import SwiftUI

/// The gated insight surface: the single switch point between the unlocked
/// ask flow and the paywall teaser. The decision is exactly one call into
/// `FeatureGate` via the entitlement store — there is no second code path
/// that could render Q&A without entitlement.
struct InsightSection: View {
    let entitlements: EntitlementStore
    @Bindable var ask: AskSeleneModel
    let theme: SeleneTheme
    @State private var isShowingPaywall = false

    var body: some View {
        VStack(alignment: .leading, spacing: SeleneSpacing.element) {
            Text(PaywallCopy.lockedCardTitle)
                .font(.system(.headline, design: .serif))
                .foregroundStyle(theme.text.color)
            if entitlements.isUnlocked(.groundedQA) {
                AskSeleneView(model: ask, theme: theme)
            } else {
                lockedCard
            }
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallScreenView(entitlements: entitlements, theme: theme)
        }
    }

    /// The card identifier sits on the body text, not the container: a
    /// container identifier would propagate onto the unlock button and
    /// clobber its own identifier.
    private var lockedCard: some View {
        VStack(alignment: .leading, spacing: SeleneSpacing.element) {
            Text(PaywallCopy.lockedCardBody)
                .font(.callout)
                .foregroundStyle(theme.textSecondary.color)
                .accessibilityIdentifier("insight-locked-card")
            Button {
                isShowingPaywall = true
            } label: {
                Text(PaywallCopy.lockedCardAction)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, SeleneSpacing.block)
                    .padding(.vertical, SeleneSpacing.tight)
                    .background(Capsule().fill(theme.accentToday.color))
                    .foregroundStyle(theme.surface.color)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("insight-unlock-button")
        }
        .padding(SeleneSpacing.element)
        .background(RoundedRectangle(cornerRadius: 12).fill(theme.surfaceRaised.color))
    }
}
