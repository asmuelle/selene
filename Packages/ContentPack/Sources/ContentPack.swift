import SeleneCore

/// One addressable section inside a pack article. The `anchor` is the second
/// half of a pinned `Citation` (sourceID + sectionAnchor): citations resolve to
/// a *section*, not just an article, so every rendered claim points at the
/// exact passage that grounds it.
public struct ContentSection: Hashable, Codable, Sendable {
    /// Stable section anchor, e.g. `cycle-changes`. Never reused or renamed.
    public let anchor: String
    public let heading: String
    public let text: String

    public init(anchor: String, heading: String, text: String) {
        self.anchor = anchor
        self.heading = heading
        self.text = text
    }
}

/// A citation-pinned passage from the curated content pack.
///
/// Chunks are compiled into the app at build time and never fetched at runtime
/// (invariant #1). Every generated medical claim must carry a citation id that
/// resolves here (invariant #4).
public struct ContentChunk: Hashable, Codable, Sendable, Identifiable {
    public enum Source: String, Codable, Sendable {
        case acog
        case nice
        case editorial
    }

    /// Stable citation id, e.g. `acog-perimenopause-001`. Never reused or renamed.
    public let id: String
    public let source: Source
    public let title: String
    public let passage: String
    public let packVersion: String
    /// Addressable sections; a citation must name one of these anchors to resolve.
    public let sections: [ContentSection]

    public init(
        id: String,
        source: Source,
        title: String,
        passage: String,
        packVersion: String,
        sections: [ContentSection]
    ) {
        self.id = id
        self.source = source
        self.title = title
        self.passage = passage
        self.packVersion = packVersion
        self.sections = sections
    }

    /// Convenience: a single-section chunk whose passage is its only section.
    public init(id: String, source: Source, title: String, passage: String, packVersion: String) {
        self.init(
            id: id,
            source: source,
            title: title,
            passage: passage,
            packVersion: packVersion,
            sections: [ContentSection(anchor: "overview", heading: title, text: passage)]
        )
    }

    public func section(anchor: String) -> ContentSection? {
        sections.first { $0.anchor == anchor }
    }
}

/// A fully resolved citation: the pack article plus the exact section the
/// pinned claim came from. Only constructible through `ContentPackStore.resolve`.
public struct ResolvedCitation: Hashable, Sendable {
    public let chunk: ContentChunk
    public let section: ContentSection
}

/// In-memory pack store with citation resolution. v1 ships the editorial seed
/// chunks plus the ACOG/NICE-derived fixture articles (perimenopause-weighted);
/// the embedding index slots in behind `ContentRetrieving` later without
/// changing this API.
public struct ContentPackStore: Sendable {
    public static let version = "pack-2026.06-v1"

    public let chunks: [ContentChunk]

    public init(chunks: [ContentChunk] = ContentPackStore.seedChunks + PackArticles.v1) {
        self.chunks = chunks
    }

    /// Resolves a citation id; generated text citing an unresolvable id is a
    /// blocking defect upstream.
    public func chunk(citationID: String) -> ContentChunk? {
        chunks.first { $0.id == citationID }
    }

    /// Resolves a pinned citation to its article *and* section. Returns nil when
    /// the source id is unknown or the anchor is not declared by that article —
    /// callers must treat nil as a corrupted citation and drop the claim it pins.
    public func resolve(_ citation: Citation) -> ResolvedCitation? {
        guard
            let chunk = chunk(citationID: citation.sourceID),
            let section = chunk.section(anchor: citation.sectionAnchor)
        else {
            return nil
        }
        return ResolvedCitation(chunk: chunk, section: section)
    }

    public var hasUniqueIDs: Bool {
        Set(chunks.map(\.id)).count == chunks.count
    }

    public static let seedChunks: [ContentChunk] = [
        ContentChunk(
            id: "editorial-cycle-variability-001",
            source: .editorial,
            title: "Cycle length varies",
            passage: "Cycle length commonly varies by several days from cycle to cycle. "
                + "A forecast is a range of likely days, not a promise of one date.",
            packVersion: version
        ),
        ContentChunk(
            id: "editorial-perimenopause-irregularity-001",
            source: .editorial,
            title: "Irregularity in perimenopause",
            passage: "During perimenopause, cycles often become less regular. Selene widens "
                + "its forecast windows to reflect that uncertainty honestly.",
            packVersion: version
        ),
        ContentChunk(
            id: "editorial-tracking-basics-001",
            source: .editorial,
            title: "What logging improves",
            passage: "Each logged period start teaches the forecast model about your own "
                + "rhythm. More history narrows the credible window.",
            packVersion: version
        ),
        ContentChunk(
            id: "editorial-clinician-001",
            source: .editorial,
            title: "When to talk to a clinician",
            passage: "Selene describes patterns in your own data and is not a diagnosis. "
                + "Bring questions about symptoms or changes to your clinician.",
            packVersion: version
        ),
    ]
}
