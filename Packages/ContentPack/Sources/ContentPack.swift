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

    public init(id: String, source: Source, title: String, passage: String, packVersion: String) {
        self.id = id
        self.source = source
        self.title = title
        self.passage = passage
        self.packVersion = packVersion
    }
}

/// In-memory pack store with citation resolution. The M1 seed pack is tiny and
/// editorial-reviewed; the full ACOG/NICE-derived pack plus embeddings is M2.
public struct ContentPackStore: Sendable {
    public static let version = "pack-2026.06-seed"

    public let chunks: [ContentChunk]

    public init(chunks: [ContentChunk] = ContentPackStore.seedChunks) {
        self.chunks = chunks
    }

    /// Resolves a citation id; generated text citing an unresolvable id is a
    /// blocking defect upstream.
    public func chunk(citationID: String) -> ContentChunk? {
        chunks.first { $0.id == citationID }
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
