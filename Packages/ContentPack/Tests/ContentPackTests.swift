@testable import ContentPack
import SeleneCore
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

    @Test("no diagnosis language anywhere in the pack (App Review 1.4.1 posture)")
    func noDiagnosisLanguage() {
        // Invariant #5: no diagnosis or contraception-efficacy claims anywhere.
        let banned = ["diagnos", "contracepti", "prevent pregnancy", "birth control"]
        for chunk in ContentPackStore().chunks {
            let sectionText = chunk.sections.map { $0.heading + " " + $0.text }.joined(separator: " ")
            let text = (chunk.title + " " + chunk.passage + " " + sectionText).lowercased()
            for term in banned where text.contains(term) && !text.contains("not a diagnosis") {
                Issue.record("banned term '\(term)' in chunk \(chunk.id)")
            }
        }
    }
}

@Suite("Citation pinning")
struct CitationPinningTests {
    let store = ContentPackStore()

    @Test("every section of every chunk resolves as a pinned citation")
    func everySectionResolves() {
        for chunk in store.chunks {
            #expect(!chunk.sections.isEmpty, "chunk \(chunk.id) has no addressable sections")
            for section in chunk.sections {
                // Arrange
                let citation = Citation(sourceID: chunk.id, sectionAnchor: section.anchor)

                // Act
                let resolved = store.resolve(citation)

                // Assert
                #expect(resolved?.chunk.id == chunk.id)
                #expect(resolved?.section == section)
            }
        }
    }

    @Test("a citation with an unknown source id does not resolve")
    func unknownSourceID() {
        let citation = Citation(sourceID: "acog-made-up-999", sectionAnchor: "overview")
        #expect(store.resolve(citation) == nil)
    }

    @Test("a citation with a corrupted section anchor does not resolve")
    func corruptedAnchor() {
        // A real article id with an anchor it never declared — must be nil,
        // never a fallback to some other section.
        let citation = Citation(
            sourceID: "acog-perimenopause-overview-001", sectionAnchor: "what-it-was"
        )
        #expect(store.resolve(citation) == nil)
    }

    @Test("section anchors are unique within each chunk")
    func uniqueAnchorsPerChunk() {
        for chunk in store.chunks {
            let anchors = chunk.sections.map(\.anchor)
            #expect(Set(anchors).count == anchors.count, "duplicate anchor in \(chunk.id)")
        }
    }

    @Test("v1 articles carry the pack version and ACOG/NICE sources")
    func articleHygiene() {
        let articles = PackArticles.v1
        #expect(articles.count >= 5)
        for article in articles {
            #expect(article.packVersion == ContentPackStore.version)
            #expect(article.source == .acog || article.source == .nice)
            #expect(article.sections.count >= 3)
        }
    }
}

@Suite("Keyword retriever (RAG seam v1)")
struct KeywordRetrieverTests {
    let retriever = KeywordRetriever(store: ContentPackStore())
    let store = ContentPackStore()

    @Test("retrieval is deterministic for identical queries")
    func deterministicRetrieval() {
        let first = retriever.retrieve(query: "night sweats and hot flashes", limit: 3)
        let second = retriever.retrieve(query: "night sweats and hot flashes", limit: 3)
        #expect(first == second)
        #expect(!first.isEmpty)
    }

    @Test("a perimenopause query surfaces perimenopause-weighted content first")
    func perimenopauseQuery() {
        // Act
        let results = retriever.retrieve(query: "hot flashes night sweats perimenopause", limit: 3)

        // Assert
        #expect(!results.isEmpty)
        let topIDs = results.map(\.citation.sourceID)
        #expect(
            topIDs.contains("acog-perimenopause-overview-001")
                || topIDs.contains("nice-menopause-ng23-001")
        )
    }

    @Test("every retrieved passage carries a citation that resolves into the pack")
    func retrievedCitationsResolve() {
        let queries = [
            "is a short cycle normal in my forties",
            "heavy bleeding what should I track",
            "when do I ovulate",
            "trouble sleeping and low mood",
        ]
        for query in queries {
            for passage in retriever.retrieve(query: query, limit: 5) {
                #expect(store.resolve(passage.citation) != nil, "unresolvable citation for '\(query)'")
            }
        }
    }

    @Test("a query with no lexical overlap returns empty, never a wrong match")
    func noMatchReturnsEmpty() {
        let results = retriever.retrieve(query: "zzz qqq xyzzy", limit: 3)
        #expect(results.isEmpty)
    }

    @Test("limit is respected and results are ranked by score descending")
    func limitAndRanking() {
        let results = retriever.retrieve(query: "cycle length variation period days", limit: 2)
        #expect(results.count <= 2)
        let scores = results.map(\.score)
        #expect(scores == scores.sorted(by: >))
    }
}
