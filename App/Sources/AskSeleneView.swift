import InsightKit
import SeleneCore
import SeleneUI
import SwiftUI

/// The unlocked insight surface: ask flow plus the grounded answer with its
/// citation chips. Rendered ONLY behind the feature gate (see InsightSection).
struct AskSeleneView: View {
    @Bindable var model: AskSeleneModel
    let theme: SeleneTheme

    var body: some View {
        // NOTE: no .accessibilityIdentifier on this container — SwiftUI
        // propagates a container identifier onto child elements (unless a
        // boundary like ScrollView intervenes), clobbering ask-input et al.
        VStack(alignment: .leading, spacing: SeleneSpacing.element) {
            suggestionRow
            inputRow
            if let answer = model.answer {
                answerCard(answer)
            }
        }
        .sheet(item: $model.selectedChip) { chip in
            CitationDetailView(chip: chip, theme: theme)
        }
    }

    // MARK: - Input

    private var suggestionRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SeleneSpacing.tight) {
                ForEach(Array(AskSeleneModel.suggestions.enumerated()), id: \.offset) { index, suggestion in
                    Button {
                        Task { await model.ask(suggestion) }
                    } label: {
                        Text(suggestion)
                            .font(.footnote)
                            .padding(.horizontal, SeleneSpacing.element)
                            .padding(.vertical, SeleneSpacing.tight)
                            .background(Capsule().fill(theme.surfaceRaised.color))
                            .foregroundStyle(theme.text.color)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("ask-suggestion-\(index)")
                }
            }
        }
    }

    private var inputRow: some View {
        HStack(spacing: SeleneSpacing.tight) {
            TextField("Ask about your cycle…", text: $model.question)
                .textFieldStyle(.plain)
                .padding(SeleneSpacing.element)
                .background(RoundedRectangle(cornerRadius: 10).fill(theme.surfaceRaised.color))
                .foregroundStyle(theme.text.color)
                .submitLabel(.send)
                .onSubmit { Task { await model.ask(model.question) } }
                .accessibilityIdentifier("ask-input")
            Button {
                Task { await model.ask(model.question) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(theme.accentToday.color)
            }
            .buttonStyle(.plain)
            .disabled(model.isAnswering)
            .accessibilityLabel("Ask Selene")
            .accessibilityIdentifier("ask-submit")
        }
    }

    // MARK: - Answer

    private func answerCard(_ answer: Insight) -> some View {
        VStack(alignment: .leading, spacing: SeleneSpacing.element) {
            Text(answer.text)
                .font(.system(.callout, design: .serif))
                .foregroundStyle(theme.text.color)
                .accessibilityIdentifier("ask-answer")
            FlowLayout(spacing: SeleneSpacing.tight) {
                ForEach(Array(model.chips.enumerated()), id: \.element.id) { index, chip in
                    chipButton(chip, index: index)
                }
            }
        }
        .padding(SeleneSpacing.element)
        .background(RoundedRectangle(cornerRadius: 12).fill(theme.surfaceRaised.color))
    }

    private func chipButton(_ chip: CitationChip, index: Int) -> some View {
        Button {
            model.selectedChip = chip
        } label: {
            HStack(spacing: SeleneSpacing.hairline) {
                Image(systemName: "text.book.closed")
                    .font(.caption2)
                Text(chip.label)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, SeleneSpacing.element)
            .padding(.vertical, SeleneSpacing.tight)
            .background(Capsule().strokeBorder(theme.accentToday.color.opacity(0.6)))
            .foregroundStyle(theme.accentToday.color)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("ask-citation-chip-\(index)")
    }
}

/// A tapped citation chip, resolved to the exact pack section that grounds
/// the claim — source badge, heading, passage, pack version.
struct CitationDetailView: View {
    let chip: CitationChip
    let theme: SeleneTheme

    var body: some View {
        // The screen identifier lives on the title element, not the ZStack:
        // a container identifier would propagate over the child identifiers.
        ZStack {
            theme.surface.color.ignoresSafeArea()
            VStack(alignment: .leading, spacing: SeleneSpacing.element) {
                Text(chip.sourceLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.accentToday.color)
                    .accessibilityIdentifier("citation-detail-source")
                Text(chip.label)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(theme.text.color)
                    .accessibilityIdentifier("citation-detail")
                Text(chip.heading)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.textSecondary.color)
                Text(chip.body)
                    .font(.callout)
                    .foregroundStyle(theme.text.color)
                    .accessibilityIdentifier("citation-detail-body")
                Spacer()
                Text("Content pack \(chip.packVersion) — compiled into the app, never fetched.")
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary.color)
            }
            .padding(SeleneSpacing.block)
        }
        .presentationDetents([.medium])
    }
}
