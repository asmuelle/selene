import Foundation

/// A pinned reference into the curated content pack: the stable source id of a
/// pack article plus the section anchor the claim came from.
///
/// Invariant #4 (grounded or silent): every medical claim in generated text
/// carries one of these, and it must resolve into `ContentPack` before the text
/// is ever rendered. A citation that fails to resolve is a corrupted citation;
/// the claim it pins is dropped, never shown unpinned.
public struct Citation: Hashable, Codable, Sendable {
    /// Stable pack article id, e.g. `acog-perimenopause-bleeding-001`.
    public let sourceID: String
    /// Section anchor within the article, e.g. `irregular-cycles`.
    public let sectionAnchor: String

    public init(sourceID: String, sectionAnchor: String) {
        self.sourceID = sourceID
        self.sectionAnchor = sectionAnchor
    }
}

/// What kind of generated surface an insight is.
public enum InsightKind: String, Codable, Sendable {
    case cycleNarrative
    case qaAnswer
}

/// A piece of generated, user-facing text.
///
/// Written only by `InsightKit` after citation validation: every sentence in
/// `text` is backed by an entry in `citations`, and every citation resolves
/// into the content pack. `isGuardrailFallback` marks deterministic template
/// output used when the model refused or was unavailable (invariant #4 —
/// refusals degrade to templates, never to error screens).
public struct Insight: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let kind: InsightKind
    public let generatedAtDay: DayNumber
    public let text: String
    public let citations: [Citation]
    public let modelID: String
    public let isGuardrailFallback: Bool

    public init(
        id: UUID = UUID(),
        kind: InsightKind,
        generatedAtDay: DayNumber,
        text: String,
        citations: [Citation],
        modelID: String,
        isGuardrailFallback: Bool
    ) {
        self.id = id
        self.kind = kind
        self.generatedAtDay = generatedAtDay
        self.text = text
        self.citations = citations
        self.modelID = modelID
        self.isGuardrailFallback = isGuardrailFallback
    }
}
