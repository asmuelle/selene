import ContentPack
import SeleneCore

/// Grounded Q&A over the citation-pinned content pack (key flow #4).
///
/// The contract this type enforces, in order (invariant #4 — grounded or silent):
/// 1. Retrieval first: the model only ever sees passages the RAG seam returned.
/// 2. Citation pinning: a claim is rendered only when it carries a citation
///    that (a) was part of the retrieved context and (b) resolves into the pack
///    down to the section anchor. Uncited claims and corrupted citations are
///    dropped before rendering, silently.
/// 3. Fallback, never error: retrieval miss, model refusal/unavailability, or
///    zero surviving claims all degrade to a deterministic curated card whose
///    own citation resolves. No error screens, no ungrounded answers.
public struct GroundedAnswerService: Sendable {
    public static let fallbackModelID = "template/qa-fallback-1.0"

    private let model: any LanguageModelProviding
    private let retriever: any ContentRetrieving
    private let pack: ContentPackStore
    private let modelID: String
    private let retrievalLimit: Int

    public init(
        model: any LanguageModelProviding,
        retriever: any ContentRetrieving,
        pack: ContentPackStore = ContentPackStore(),
        modelID: String = "afm-mock/1.0",
        retrievalLimit: Int = 3
    ) {
        self.model = model
        self.retriever = retriever
        self.pack = pack
        self.modelID = modelID
        self.retrievalLimit = retrievalLimit
    }

    /// Answers a question. Always returns a renderable `Insight`; never throws.
    public func answer(question: String, today: DayNumber) async -> Insight {
        let passages = retriever.retrieve(query: question, limit: retrievalLimit)
        guard !passages.isEmpty else {
            return retrievalMissCard(today: today)
        }

        let raw: String
        do {
            raw = try await model.respond(to: prompt(question: question, passages: passages))
        } catch {
            return fallbackCard(topPassage: passages[0], today: today)
        }

        let allowed = Set(passages.map(\.citation))
        let surviving = CitationMarkup.parse(raw).segments.filter { segment in
            allowed.contains(segment.citation) && pack.resolve(segment.citation) != nil
        }
        guard !surviving.isEmpty else {
            return fallbackCard(topPassage: passages[0], today: today)
        }

        return Insight(
            kind: .qaAnswer,
            generatedAtDay: today,
            text: surviving.map(\.text).joined(separator: " "),
            citations: orderedUniqueCitations(of: surviving),
            modelID: modelID,
            isGuardrailFallback: false
        )
    }

    // MARK: - Prompt assembly

    /// The grounding prompt: question plus retrieved passages, each labelled
    /// with the only citation markers the model is allowed to emit.
    func prompt(question: String, passages: [RetrievedPassage]) -> String {
        let context = passages
            .map { passage in
                "[cite:\(passage.citation.sourceID)#\(passage.citation.sectionAnchor)] "
                    + "\(passage.heading): \(passage.text)"
            }
            .joined(separator: "\n")
        return """
        Answer using ONLY the passages below. End every sentence with the \
        [cite:source#anchor] marker of the passage it came from. If the passages \
        do not answer the question, reply with nothing.

        \(context)

        Question: \(question)
        """
    }

    // MARK: - Deterministic fallbacks

    /// Curated card when retrieval found nothing: honest "can't answer this",
    /// pinned to the editorial clinician-handoff chunk.
    private func retrievalMissCard(today: DayNumber) -> Insight {
        let citation = Citation(sourceID: "editorial-clinician-001", sectionAnchor: "overview")
        let body = pack.resolve(citation)?.section.text
            ?? "Selene describes patterns in your own data and is not a diagnosis."
        return Insight(
            kind: .qaAnswer,
            generatedAtDay: today,
            text: "Selene can't answer this from its curated library. " + body,
            citations: [citation],
            modelID: Self.fallbackModelID,
            isGuardrailFallback: true
        )
    }

    /// Curated card when the model refused, was unavailable, or produced no
    /// validly cited claim: surface the top retrieved passage verbatim, pinned.
    private func fallbackCard(topPassage: RetrievedPassage, today: DayNumber) -> Insight {
        Insight(
            kind: .qaAnswer,
            generatedAtDay: today,
            text: "From Selene's curated library — \(topPassage.heading): \(topPassage.text)",
            citations: [topPassage.citation],
            modelID: Self.fallbackModelID,
            isGuardrailFallback: true
        )
    }

    private func orderedUniqueCitations(of segments: [CitedSegment]) -> [Citation] {
        var seen = Set<Citation>()
        return segments.compactMap { segment in
            seen.insert(segment.citation).inserted ? segment.citation : nil
        }
    }
}
