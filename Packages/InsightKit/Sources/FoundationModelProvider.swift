#if canImport(FoundationModels)
    import FoundationModels
    import SeleneCore

    /// FoundationModels-backed `LanguageModelProviding`.
    ///
    /// Availability-guarded so `swift test` on macOS (no Apple Intelligence) never
    /// references it; the deterministic `MockLanguageModel` remains the test and
    /// default provider. Guardrail declines and unavailability map onto the
    /// existing typed error so every caller's template fallback still fires
    /// (invariant #4 — refusals degrade, never error).
    @available(iOS 26.0, macOS 26.0, *)
    public struct FoundationModelProvider: LanguageModelProviding {
        public var isAvailable: Bool {
            SystemLanguageModel.default.availability == .available
        }

        public init() {}

        public func respond(to prompt: String) async throws(LanguageModelError) -> String {
            guard isAvailable else {
                throw .unavailable
            }
            do {
                let session = LanguageModelSession()
                let response = try await session.respond(to: prompt)
                return response.content
            } catch {
                // Any model-side failure (guardrail decline, context overflow, …)
                // collapses to `.refused`: the product answer is the deterministic
                // template, never an error surface.
                throw .refused
            }
        }
    }
#endif
