import ContentPack
import SeleneCore

/// A citation chip ready to render: the pinned claim's source, resolved down
/// to the exact pack section. Only constructible from citations that resolve
/// (invariant #4) — an unresolvable citation yields no chip, and upstream
/// `GroundedAnswerService` guarantees that case never ships anyway.
public struct CitationChip: Hashable, Sendable, Identifiable {
    /// Stable identity: `sourceID#sectionAnchor`.
    public let id: String
    /// Chip label — the pack article title.
    public let label: String
    /// Provenance badge, e.g. "ACOG-derived guidance".
    public let sourceLabel: String
    /// Section heading inside the article.
    public let heading: String
    /// The exact passage that grounds the claim.
    public let body: String
    public let packVersion: String
    public let citation: Citation
}

/// Maps a surfaced `Insight` to its citation chips by resolving every pinned
/// citation into the content pack.
public enum CitationPresenter {
    public static func chips(for insight: Insight, pack: ContentPackStore) -> [CitationChip] {
        insight.citations.compactMap { citation in
            guard let resolved = pack.resolve(citation) else {
                return nil
            }
            return CitationChip(
                id: "\(citation.sourceID)#\(citation.sectionAnchor)",
                label: resolved.chunk.title,
                sourceLabel: sourceLabel(for: resolved.chunk.source),
                heading: resolved.section.heading,
                body: resolved.section.text,
                packVersion: resolved.chunk.packVersion,
                citation: citation
            )
        }
    }

    static func sourceLabel(for source: ContentChunk.Source) -> String {
        switch source {
        case .acog: "ACOG-derived guidance"
        case .nice: "NICE-derived guidance"
        case .editorial: "Selene editorial"
        }
    }
}
