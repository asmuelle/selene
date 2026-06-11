import Foundation
import SeleneCore

/// One validated claim: rendered text plus the citation that pins it.
struct CitedSegment: Hashable {
    let text: String
    let citation: Citation
}

/// Parser for the model-output citation markup.
///
/// The model is prompted to end every sentence with `[cite:<sourceID>#<anchor>]`.
/// A segment is the text since the previous marker, pinned by the marker that
/// closes it. Text with no closing marker — including everything after the last
/// marker — is *uncited* and is never rendered (invariant #4).
enum CitationMarkup {
    struct ParseResult: Hashable {
        let segments: [CitedSegment]
        /// True when the raw output contained non-empty text with no citation.
        let hadUncitedText: Bool
    }

    static func parse(_ raw: String) -> ParseResult {
        // Local literal: `Regex` is not Sendable, so it cannot be a static let
        // under strict concurrency.
        let markerPattern = /\[cite:([A-Za-z0-9\-]+)#([A-Za-z0-9\-]+)\]/
        var segments: [CitedSegment] = []
        var hadUncitedText = false
        var cursor = raw.startIndex

        for match in raw.matches(of: markerPattern) {
            let claim = String(raw[cursor ..< match.range.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if claim.isEmpty {
                // A marker with no preceding claim pins nothing — skip it.
            } else {
                segments.append(CitedSegment(
                    text: claim,
                    citation: Citation(
                        sourceID: String(match.output.1),
                        sectionAnchor: String(match.output.2)
                    )
                ))
            }
            cursor = match.range.upperBound
        }

        let trailing = String(raw[cursor...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !trailing.isEmpty {
            hadUncitedText = true
        }
        return ParseResult(segments: segments, hadUncitedText: hadUncitedText)
    }
}
