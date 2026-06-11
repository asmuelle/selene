import Foundation
import SeleneCore

/// One retrieved, citation-pinned passage. Whatever produced it, the citation
/// always resolves back into the pack (it is built from the pack itself).
public struct RetrievedPassage: Hashable, Sendable {
    public let citation: Citation
    public let title: String
    public let heading: String
    public let text: String
    public let score: Double

    public init(citation: Citation, title: String, heading: String, text: String, score: Double) {
        self.citation = citation
        self.title = title
        self.heading = heading
        self.text = text
        self.score = score
    }
}

/// The RAG seam. v1 is deterministic keyword retrieval; the on-device embedding
/// index replaces the implementation behind this protocol without touching
/// callers (`InsightKit` Q&A) or the citation-pinning contract.
public protocol ContentRetrieving: Sendable {
    /// Returns the best-matching pack sections for a query, highest score
    /// first, deterministic for identical inputs. Empty when nothing matches —
    /// callers must fall back to a curated card, never answer ungrounded.
    func retrieve(query: String, limit: Int) -> [RetrievedPassage]
}

/// Deterministic lexical retriever over pack sections.
///
/// Scoring is plain token overlap (query tokens found in section heading/text/
/// article title), with a stable (sourceID, anchor) tie-break so identical
/// queries always return identical rankings — no randomness, no model, no IO.
public struct KeywordRetriever: ContentRetrieving {
    private let store: ContentPackStore

    public init(store: ContentPackStore) {
        self.store = store
    }

    public func retrieve(query: String, limit: Int) -> [RetrievedPassage] {
        let queryTokens = Self.tokens(in: query)
        guard !queryTokens.isEmpty, limit > 0 else {
            return []
        }
        return store.chunks
            .flatMap { chunk in
                chunk.sections.compactMap { section in
                    passage(for: section, of: chunk, queryTokens: queryTokens)
                }
            }
            .sorted(by: Self.ranking)
            .prefix(limit)
            .map(\.self)
    }

    private func passage(
        for section: ContentSection,
        of chunk: ContentChunk,
        queryTokens: Set<String>
    ) -> RetrievedPassage? {
        let sectionTokens = Self.tokens(in: "\(chunk.title) \(section.heading) \(section.text)")
        let overlap = queryTokens.intersection(sectionTokens).count
        guard overlap > 0 else {
            return nil
        }
        return RetrievedPassage(
            citation: Citation(sourceID: chunk.id, sectionAnchor: section.anchor),
            title: chunk.title,
            heading: section.heading,
            text: section.text,
            score: Double(overlap)
        )
    }

    private static func ranking(_ lhs: RetrievedPassage, _ rhs: RetrievedPassage) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }
        if lhs.citation.sourceID != rhs.citation.sourceID {
            return lhs.citation.sourceID < rhs.citation.sourceID
        }
        return lhs.citation.sectionAnchor < rhs.citation.sectionAnchor
    }

    /// Lowercased alphanumeric tokens, minus trivially short stop tokens.
    static func tokens(in text: String) -> Set<String> {
        let raw = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
        return Set(raw.filter { $0.count > 2 })
    }
}
