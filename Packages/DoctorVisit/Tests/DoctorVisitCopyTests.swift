import ContentPack
@testable import DoctorVisit
import Foundation
import SeleneCore
import Testing

@Suite("Doctor-visit copy & citations")
struct DoctorVisitCopyTests {
    /// Same 1.4.1 / SaMD bar as paywall copy: this artifact is shared with a
    /// clinician, so it must carry no diagnosis/treatment/accuracy claims.
    static let bannedWordPrefixes = [
        "diagnos", "treat", "cure", "prevent", "contracept", "conceiv",
        "clinically", "guarantee", "accura", "proven", "fda",
        "medical-grade", "effectiv", "birth control",
    ]

    @Test(
        "no banned medical-claim language in any shipped summary string",
        arguments: bannedWordPrefixes
    )
    func bannedLanguageScan(prefix: String) throws {
        let pattern = try NSRegularExpression(
            pattern: "\\b\(NSRegularExpression.escapedPattern(for: prefix))",
            options: [.caseInsensitive]
        )
        for copy in DoctorVisitCopy.allShippedStrings {
            let hits = pattern.numberOfMatches(
                in: copy, range: NSRange(copy.startIndex..., in: copy)
            )
            #expect(hits == 0, "banned term '\(prefix)' in summary copy: \"\(copy)\"")
        }
    }

    @Test("the disclaimer disclaims interpretation and points to a clinician")
    func disclaimerHonest() {
        #expect(DoctorVisitCopy.disclaimer.contains("does not interpret"))
        #expect(DoctorVisitCopy.disclaimer.contains("clinician"))
    }

    @Test("the forecast note frames forecasts as ranges, not single dates")
    func forecastNoteHonest() {
        #expect(DoctorVisitCopy.forecastNote.lowercased().contains("range"))
    }

    @Test("every standing citation resolves into the content pack (invariant #4)")
    func standingCitationsResolve() {
        let pack = ContentPackStore()
        for citation in DoctorVisitCopy.standingCitations {
            #expect(
                pack.resolve(citation) != nil,
                "unresolvable standing citation: \(citation)"
            )
        }
    }
}
