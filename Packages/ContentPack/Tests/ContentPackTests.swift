@testable import ContentPack
import Testing

@Suite("ContentPack")
struct ContentPackTests {
    @Test("seed pack citation ids are unique")
    func uniqueCitationIDs() {
        let store = ContentPackStore()
        #expect(store.hasUniqueIDs)
        #expect(!store.chunks.isEmpty)
    }

    @Test("every seed chunk resolves by its citation id")
    func everyChunkResolves() {
        // Arrange
        let store = ContentPackStore()

        // Act & Assert
        for chunk in store.chunks {
            #expect(store.chunk(citationID: chunk.id) == chunk)
        }
    }

    @Test("unknown citation ids resolve to nil, never to a wrong chunk")
    func unknownCitationID() {
        let store = ContentPackStore()
        #expect(store.chunk(citationID: "acog-nonexistent-999") == nil)
    }

    @Test("seed chunks carry the pack version and non-empty passages")
    func chunkHygiene() {
        for chunk in ContentPackStore.seedChunks {
            #expect(chunk.packVersion == ContentPackStore.version)
            #expect(!chunk.passage.isEmpty)
            #expect(!chunk.title.isEmpty)
        }
    }

    @Test("no diagnosis language in the seed pack (App Review 1.4.1 posture)")
    func noDiagnosisLanguage() {
        // Invariant #5: no diagnosis or contraception-efficacy claims anywhere.
        let banned = ["diagnos", "contracepti", "prevent pregnancy", "birth control"]
        for chunk in ContentPackStore.seedChunks {
            let text = (chunk.title + " " + chunk.passage).lowercased()
            for term in banned where text.contains(term) && !text.contains("not a diagnosis") {
                Issue.record("banned term '\(term)' in chunk \(chunk.id)")
            }
        }
    }
}
