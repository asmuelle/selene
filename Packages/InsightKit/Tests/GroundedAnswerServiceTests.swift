import ContentPack
@testable import InsightKit
import SeleneCore
import Testing

/// The citation-pinning contract (invariant #4): uncited content is never
/// rendered, corrupted citations are dropped, and every surfaced insight
/// carries source id + section anchor citations that resolve into the pack.
@Suite("Grounded answers — citation pinning")
struct GroundedAnswerServiceTests {
    let pack = ContentPackStore()
    let today = DayNumber(20600)

    private func service(model: any LanguageModelProviding) -> GroundedAnswerService {
        GroundedAnswerService(
            model: model,
            retriever: KeywordRetriever(store: pack),
            pack: pack
        )
    }

    /// Citations the retriever returns for this question — the allowed context.
    private func retrievedCitations(for question: String) -> [Citation] {
        KeywordRetriever(store: pack).retrieve(query: question, limit: 3).map(\.citation)
    }

    @Test("validly cited claims render with their pinned source id + section anchor")
    func happyPath() async throws {
        // Arrange: model cites two passages that retrieval actually returned.
        let question = "hot flashes and night sweats in perimenopause"
        let allowed = retrievedCitations(for: question)
        try #require(allowed.count >= 2)
        let scripted = ScriptedLanguageModel(
            output: "Hot flashes and night sweats are common in the transition. "
                + "[cite:\(allowed[0].sourceID)#\(allowed[0].sectionAnchor)] "
                + "Patterns differ between people. "
                + "[cite:\(allowed[1].sourceID)#\(allowed[1].sectionAnchor)]"
        )

        // Act
        let insight = await service(model: scripted).answer(question: question, today: today)

        // Assert
        #expect(!insight.isGuardrailFallback)
        #expect(insight.text.contains("Hot flashes and night sweats are common"))
        #expect(insight.text.contains("Patterns differ between people."))
        #expect(!insight.text.contains("[cite:"))
        #expect(insight.citations == [allowed[0], allowed[1]])
        for citation in insight.citations {
            #expect(pack.resolve(citation) != nil)
            #expect(!citation.sectionAnchor.isEmpty)
        }
    }

    @Test("uncited trailing content is never rendered")
    func uncitedTrailingDropped() async {
        let question = "hot flashes and night sweats in perimenopause"
        let allowed = retrievedCitations(for: question)
        let scripted = ScriptedLanguageModel(
            output: "Night sweats are commonly reported. "
                + "[cite:\(allowed[0].sourceID)#\(allowed[0].sectionAnchor)] "
                + "Also, unrelated invented advice with no citation."
        )

        let insight = await service(model: scripted).answer(question: question, today: today)

        #expect(insight.text.contains("Night sweats are commonly reported."))
        #expect(!insight.text.contains("invented advice"))
        #expect(insight.citations == [allowed[0]])
    }

    @Test("entirely uncited output renders the curated fallback card, not the output")
    func entirelyUncitedFallsBack() async {
        let question = "hot flashes and night sweats in perimenopause"
        let scripted = ScriptedLanguageModel(
            output: "Confident, fluent, completely uncited model prose."
        )

        let insight = await service(model: scripted).answer(question: question, today: today)

        #expect(insight.isGuardrailFallback)
        #expect(!insight.text.contains("uncited model prose"))
        #expect(insight.citations.count == 1)
        #expect(pack.resolve(insight.citations[0]) != nil)
    }

    @Test("corrupted citations are dropped: unknown id, bad anchor, out-of-context")
    func corruptedCitationsDropped() async throws {
        let question = "hot flashes and night sweats in perimenopause"
        let allowed = retrievedCitations(for: question)
        // A real pack section that retrieval did NOT return for this question.
        let outOfContext = Citation(
            sourceID: "nice-heavy-bleeding-ng88-001", sectionAnchor: "what-counts-as-heavy"
        )
        try #require(pack.resolve(outOfContext) != nil)
        try #require(!allowed.contains(outOfContext))
        let scripted = ScriptedLanguageModel(
            output: "A validly pinned claim. "
                + "[cite:\(allowed[0].sourceID)#\(allowed[0].sectionAnchor)] "
                + "Claim pinned to a nonexistent source. [cite:acog-made-up-999#overview] "
                + "Claim pinned to a corrupted anchor. [cite:\(allowed[0].sourceID)#no-such-anchor] "
                + "Claim citing pack content outside the retrieved context. "
                + "[cite:\(outOfContext.sourceID)#\(outOfContext.sectionAnchor)]"
        )

        let insight = await service(model: scripted).answer(question: question, today: today)

        #expect(insight.text == "A validly pinned claim.")
        #expect(insight.citations == [allowed[0]])
    }

    @Test("guardrail refusal degrades to a pinned curated card, never an error")
    func refusalFallsBack() async {
        // MockLanguageModel refuses any prompt containing its marker; the
        // question text flows into the prompt, forcing the refusal path.
        let question = "[refuse] hot flashes and night sweats in perimenopause"
        let insight = await service(model: MockLanguageModel())
            .answer(question: question, today: today)

        #expect(insight.isGuardrailFallback)
        #expect(!insight.text.isEmpty)
        #expect(insight.citations.count == 1)
        #expect(pack.resolve(insight.citations[0]) != nil)
        #expect(insight.modelID == GroundedAnswerService.fallbackModelID)
    }

    @Test("model unavailability degrades to a pinned curated card")
    func unavailableFallsBack() async {
        let question = "hot flashes and night sweats in perimenopause"
        let insight = await service(model: UnavailableLanguageModel())
            .answer(question: question, today: today)

        #expect(insight.isGuardrailFallback)
        #expect(insight.citations.count == 1)
        #expect(pack.resolve(insight.citations[0]) != nil)
    }

    @Test("retrieval miss renders the honest can't-answer card with a resolvable citation")
    func retrievalMissFallsBack() async {
        let insight = await service(model: ScriptedLanguageModel(output: "anything"))
            .answer(question: "zzz qqq xyzzy", today: today)

        #expect(insight.isGuardrailFallback)
        #expect(insight.text.contains("can't answer this"))
        #expect(insight.citations.count == 1)
        #expect(pack.resolve(insight.citations[0]) != nil)
    }

    @Test("every surfaced insight resolves all of its citations", arguments: [
        "is a 24 day cycle normal at 44",
        "heavy bleeding what should I track",
        "when do I ovulate in my cycle",
        "zzz qqq xyzzy",
        "[refuse] night sweats",
    ])
    func allCitationsAlwaysResolve(question: String) async {
        let insight = await service(model: MockLanguageModel())
            .answer(question: question, today: today)

        #expect(!insight.citations.isEmpty, "an insight without citations must never surface")
        for citation in insight.citations {
            #expect(pack.resolve(citation) != nil, "unresolvable citation for '\(question)'")
        }
    }
}

@Suite("Citation markup parser")
struct CitationMarkupTests {
    @Test("parses claims with their markers and flags trailing uncited text")
    func parseBasics() {
        let result = CitationMarkup.parse(
            "First claim. [cite:a-1#s-1] Second claim. [cite:b-2#s-2] Trailing uncited."
        )
        #expect(result.segments.count == 2)
        #expect(result.segments[0] == CitedSegment(
            text: "First claim.", citation: Citation(sourceID: "a-1", sectionAnchor: "s-1")
        ))
        #expect(result.hadUncitedText)
    }

    @Test("output with no markers yields no segments and flags uncited text")
    func noMarkers() {
        let result = CitationMarkup.parse("Just prose, no citations at all.")
        #expect(result.segments.isEmpty)
        #expect(result.hadUncitedText)
    }

    @Test("a marker with no preceding claim pins nothing")
    func emptyClaim() {
        let result = CitationMarkup.parse("[cite:a-1#s-1]")
        #expect(result.segments.isEmpty)
        #expect(!result.hadUncitedText)
    }
}
