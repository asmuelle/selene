import ContentPack
import Foundation
import InsightKit
import Observation
import SeleneCore

/// View model for the gated ask flow (key flow #4): question in, grounded
/// `Insight` plus resolving citation chips out.
///
/// The language-model seam is composed with `UnavailableLanguageModel` until
/// the FoundationModels provider clears its extraction eval (M2 note in
/// DESIGN.md) — so today every answer takes the deterministic curated path:
/// retrieval-pinned passages, citation chips that resolve, no error screens
/// (invariant #4). When the AFM provider lands it slots in here, behind the
/// same protocol, with the identical fallback behavior already tested.
@MainActor
@Observable
final class AskSeleneModel {
    static let suggestions = [
        "Is a 24-day cycle normal at 44?",
        "Why is my forecast a window, not one date?",
        "What changes in perimenopause?",
    ]

    private(set) var answer: Insight?
    private(set) var chips: [CitationChip] = []
    private(set) var isAnswering = false
    var question = ""
    var selectedChip: CitationChip?

    private let pack: ContentPackStore
    private let service: GroundedAnswerService
    private let todayProvider: @Sendable () -> DayNumber

    init(
        model: any LanguageModelProviding = UnavailableLanguageModel(),
        pack: ContentPackStore = ContentPackStore(),
        todayProvider: @escaping @Sendable () -> DayNumber = { DayNumber(date: Date()) }
    ) {
        self.pack = pack
        service = GroundedAnswerService(
            model: model,
            retriever: KeywordRetriever(store: pack),
            pack: pack
        )
        self.todayProvider = todayProvider
    }

    func ask(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isAnswering else {
            return
        }
        isAnswering = true
        question = trimmed
        let insight = await service.answer(question: trimmed, today: todayProvider())
        answer = insight
        chips = CitationPresenter.chips(for: insight, pack: pack)
        isAnswering = false
    }
}
