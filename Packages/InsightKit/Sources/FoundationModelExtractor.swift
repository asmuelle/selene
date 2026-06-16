#if canImport(FoundationModels)
    import FoundationModels
    import SeleneCore

    /// `@Generable` schema the model fills in. Constrained to the fixed taxonomy
    /// via the `@Guide` enumeration so the model can only ever emit valid codes —
    /// the taxonomy is the contract between capture, store, and engine.
    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct GenerableExtraction {
        @Guide(description: "Symptoms clearly mentioned in the text.")
        var symptoms: [GenerableSymptom]
    }

    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct GenerableSymptom {
        @Guide(description: "One symptom from the fixed list.")
        var code: GenerableSymptomCode
        @Guide(description: "Severity 1 (mild) to 4 (severe).", .range(1 ... 4))
        var severity: Int
    }

    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    enum GenerableSymptomCode: String, CaseIterable {
        case cramps, headache, bloating, breastTenderness, fatigue, nausea
        case backPain, acne, spotting, moodSwings, anxiety, lowMood, irritability
        case hotFlashes, nightSweats, brainFog, insomnia, cycleIrregularity
        case palpitations, jointAches

        var domain: SymptomCode? {
            SymptomCode(rawValue: rawValue)
        }
    }

    /// FoundationModels-backed `SymptomExtracting` using guided generation.
    ///
    /// Availability-guarded; `swift test` never references it. On any model-side
    /// failure it returns `.empty`, which the capture flow treats as "fall through
    /// to manual logging" (key flow #1). Output is still SUGGESTIVE — the user's
    /// confirm tap remains the commit; nothing here auto-persists.
    @available(iOS 26.0, macOS 26.0, *)
    public struct FoundationModelExtractor: SymptomExtracting {
        public var isAvailable: Bool {
            SystemLanguageModel.default.availability == .available
        }

        public init() {}

        public func extract(from phrase: String) async -> ExtractionResult {
            guard isAvailable else {
                return .empty
            }
            do {
                let session = LanguageModelSession()
                let prompt = """
                Extract any symptoms explicitly described in this note. Only use \
                the listed symptom codes. If none are described, return an empty list.

                Note: \(phrase)
                """
                let reply = try await session.respond(
                    to: prompt, generating: GenerableExtraction.self
                )
                return Self.mapped(reply.content, phrase: phrase)
            } catch {
                return .empty
            }
        }

        static func mapped(_ extraction: GenerableExtraction, phrase: String) -> ExtractionResult {
            let symptoms = extraction.symptoms.compactMap { generated -> ExtractedSymptom? in
                guard
                    let code = generated.code.domain,
                    let severity = Severity(generated.severity)
                else {
                    return nil
                }
                return ExtractedSymptom(code: code, severity: severity, confidence: 0.8)
            }
            // Flow detection stays deterministic — the model is not asked to infer it.
            return ExtractionResult(
                symptoms: symptoms,
                flow: KeywordSymptomExtractor.flow(in: phrase.lowercased())
            )
        }
    }
#endif
