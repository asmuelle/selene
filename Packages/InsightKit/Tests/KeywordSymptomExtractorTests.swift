@testable import InsightKit
import SeleneCore
import Testing

@Suite("Keyword symptom extractor")
struct KeywordSymptomExtractorTests {
    private let extractor = KeywordSymptomExtractor()

    @Test("extracts a single perimenopause symptom")
    func singleSymptom() async {
        let result = await extractor.extract(from: "woke up in night sweats")
        #expect(result.codes == [.nightSweats])
    }

    @Test("extracts multiple symptoms from one phrase, in taxonomy order")
    func multipleSymptoms() async {
        let result = await extractor.extract(from: "hot flashes and couldn't sleep")
        #expect(result.codes == [.hotFlashes, .insomnia])
        // Taxonomy order: hotFlashes precedes insomnia.
        #expect(result.symptoms.map(\.code) == [.hotFlashes, .insomnia])
    }

    @Test("severity cue words map to the fixed scale")
    func severityMapping() async {
        let severe = await extractor.extract(from: "unbearable cramps")
        #expect(severe.symptoms.first?.severity == .severe)
        let mild = await extractor.extract(from: "mild headache")
        #expect(mild.symptoms.first?.severity == .mild)
        let defaultModerate = await extractor.extract(from: "some cramps")
        #expect(defaultModerate.symptoms.first?.severity == .moderate)
    }

    @Test("detects flow level alongside symptoms")
    func flowDetection() async {
        let result = await extractor.extract(from: "heavy flow and bad cramps")
        #expect(result.flow == .heavy)
        #expect(result.codes.contains(.cramps))
    }

    @Test("a phrase with no symptom markers extracts nothing")
    func noMatch() async {
        let result = await extractor.extract(from: "went for a nice walk today")
        #expect(result.symptoms.isEmpty)
        #expect(result.flow == nil)
    }

    @Test("extraction is deterministic")
    func deterministic() async {
        let a = await extractor.extract(from: "brain fog and joint aches")
        let b = await extractor.extract(from: "brain fog and joint aches")
        #expect(a == b)
    }

    @Test("the mock is always reported available (no model, no network)")
    func availability() {
        #expect(extractor.isAvailable)
    }
}
