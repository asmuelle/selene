import Paywall
import SeleneCore
import SeleneUI
import SwiftUI

/// The hard paywall, in the Lunar Almanac voice: price, trial terms, and the
/// privacy promise stated plainly — no medical-claim language (the copy is
/// scan-tested in `PaywallCopyTests`), and what stays free is restated on the
/// purchase screen itself.
struct PaywallScreenView: View {
    let entitlements: EntitlementStore
    let theme: SeleneTheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            theme.surface.color.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: SeleneSpacing.block) {
                    header
                    offerCards
                    Text(PaywallCopy.trialTerms(price: annualPrice))
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary.color)
                        .accessibilityIdentifier("paywall-trial-terms")
                    promises
                    if case let .failed(message) = entitlements.activity {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(theme.flow.color)
                            .accessibilityIdentifier("paywall-error")
                    }
                    restoreButton
                }
                .padding(SeleneSpacing.block)
            }
        }
        .accessibilityIdentifier("paywall-screen")
        .onChange(of: entitlements.state) {
            if entitlements.isUnlocked(.groundedQA) {
                dismiss()
            }
        }
    }

    // MARK: - Pricing (provider-localized, honest fallbacks)

    private var annualPrice: String {
        entitlements.products.first { $0.id == .annual }?.displayPrice
            ?? PaywallCopy.fallbackAnnualPrice
    }

    private var lifetimePrice: String {
        entitlements.products.first { $0.id == .lifetime }?.displayPrice
            ?? PaywallCopy.fallbackLifetimePrice
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: SeleneSpacing.tight) {
            Image(systemName: "moon.stars")
                .font(.title)
                .foregroundStyle(theme.accentToday.color)
            Text(PaywallCopy.headline)
                .font(.system(.largeTitle, design: .serif, weight: .semibold))
                .foregroundStyle(theme.text.color)
            Text(PaywallCopy.subheadline)
                .font(.callout)
                .foregroundStyle(theme.textSecondary.color)
        }
    }

    private var offerCards: some View {
        VStack(spacing: SeleneSpacing.element) {
            offerCard(
                title: entitlements.isTrialAvailable
                    ? PaywallCopy.annualActionTitle
                    : PaywallCopy.annualResubscribeTitle,
                detail: PaywallCopy.annualOfferLine(price: annualPrice),
                isPrimary: true,
                identifier: "paywall-annual-button"
            ) {
                Task { await entitlements.purchase(.annual) }
            }
            offerCard(
                title: PaywallCopy.lifetimeActionTitle,
                detail: PaywallCopy.lifetimeOfferLine(price: lifetimePrice),
                isPrimary: false,
                identifier: "paywall-lifetime-button"
            ) {
                Task { await entitlements.purchase(.lifetime) }
            }
        }
    }

    private var promises: some View {
        VStack(alignment: .leading, spacing: SeleneSpacing.element) {
            promiseRow(icon: "airplane", text: PaywallCopy.privacyPromise)
                .accessibilityIdentifier("paywall-privacy-promise")
            promiseRow(icon: "lock.open", text: PaywallCopy.freeForeverNote)
                .accessibilityIdentifier("paywall-free-note")
            promiseRow(icon: "text.book.closed", text: PaywallCopy.honestyNote)
        }
    }

    private var restoreButton: some View {
        Button(PaywallCopy.restoreActionTitle) {
            Task { await entitlements.restore() }
        }
        .font(.footnote)
        .foregroundStyle(theme.textSecondary.color)
        .accessibilityIdentifier("paywall-restore-button")
    }

    // MARK: - Pieces

    private func offerCard(
        title: String, detail: String, isPrimary: Bool, identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: SeleneSpacing.tight) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.footnote)
                    .opacity(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SeleneSpacing.element)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isPrimary ? theme.accentToday.color : theme.surfaceRaised.color)
            )
            .foregroundStyle(isPrimary ? theme.surface.color : theme.text.color)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func promiseRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: SeleneSpacing.element) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(theme.accentToday.color)
                .frame(width: 18)
            Text(text)
                .font(.footnote)
                .foregroundStyle(theme.textSecondary.color)
        }
        .accessibilityElement(children: .combine)
    }
}
