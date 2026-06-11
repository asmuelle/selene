import ContentPack
@testable import InsightKit
import SeleneCore
import Testing

/// Citation chips are the paywalled surface's proof-of-grounding UI: every
/// chip must resolve into the pack down to the section, and unresolvable
/// citations must never produce a chip.
@Suite("Citation chips")
struct CitationPresenterTests {
    let pack = ContentPackStore()
    let today = DayNumber(20614)

    @Test("every chip carries the resolved title, section, passage, and pack version")
    func chipsCarryResolvedContent() async {
        // Arrange: a real grounded answer from the service.
        let service = GroundedAnswerService(
            model: MockLanguageModel(),
            retriever: KeywordRetriever(store: pack),
            pack: pack
        )
        let insight = await service.answer(
            question: "are irregular cycles normal in perimenopause", today: today
        )

        // Act
        let chips = CitationPresenter.chips(for: insight, pack: pack)

        // Assert: one chip per citation, all fully resolved.
        #expect(chips.count == insight.citations.count)
        #expect(!chips.isEmpty)
        for chip in chips {
            let resolved = pack.resolve(chip.citation)
            #expect(resolved != nil)
            #expect(chip.label == resolved?.chunk.title)
            #expect(chip.heading == resolved?.section.heading)
            #expect(chip.body == resolved?.section.text)
            #expect(chip.packVersion == resolved?.chunk.packVersion)
            #expect(chip.id == "\(chip.citation.sourceID)#\(chip.citation.sectionAnchor)")
        }
    }

    @Test("an unresolvable citation yields no chip — never an unpinned chip")
    func unresolvableCitationDropped() {
        let insight = Insight(
            kind: .qaAnswer,
            generatedAtDay: today,
            text: "claim",
            citations: [
                Citation(sourceID: "editorial-clinician-001", sectionAnchor: "overview"),
                Citation(sourceID: "acog-made-up-999", sectionAnchor: "overview"),
                Citation(sourceID: "editorial-clinician-001", sectionAnchor: "no-such-anchor"),
            ],
            modelID: "test",
            isGuardrailFallback: false
        )

        let chips = CitationPresenter.chips(for: insight, pack: pack)

        #expect(chips.count == 1)
        #expect(chips[0].citation.sourceID == "editorial-clinician-001")
    }

    @Test("provenance badges name the source honestly")
    func sourceLabels() {
        #expect(CitationPresenter.sourceLabel(for: .acog) == "ACOG-derived guidance")
        #expect(CitationPresenter.sourceLabel(for: .nice) == "NICE-derived guidance")
        #expect(CitationPresenter.sourceLabel(for: .editorial) == "Selene editorial")
    }
}
