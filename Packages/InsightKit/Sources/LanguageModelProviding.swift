/// The on-device language-model boundary.
///
/// M1 ships no LLM (DESIGN.md). This protocol exists so that when the
/// FoundationModels-backed provider lands (M2), it slots in behind an interface
/// the rest of the codebase already uses — and so every test runs against the
/// deterministic mock with zero model downloads, zero API calls, zero network.
public protocol LanguageModelProviding: Sendable {
    var isAvailable: Bool { get }
    /// Responds to a prompt. Throws `LanguageModelError` on refusal/unavailability;
    /// callers must degrade to a deterministic template (invariant #4).
    func respond(to prompt: String) async throws(LanguageModelError) -> String
}

public enum LanguageModelError: Error, Equatable, Sendable {
    /// The on-device model is not present / not supported on this hardware.
    case unavailable
    /// Guardrails declined the prompt — expected on some reproductive-health
    /// phrasings; the product answer is the template fallback, never an error UI.
    case refused
}

/// Deterministic mock: same prompt in, same string out. No randomness, no state.
public struct MockLanguageModel: LanguageModelProviding {
    public let isAvailable = true
    /// Prompts containing any of these markers simulate a guardrail refusal.
    public let refusalMarkers: [String]

    public init(refusalMarkers: [String] = ["[refuse]"]) {
        self.refusalMarkers = refusalMarkers
    }

    public func respond(to prompt: String) async throws(LanguageModelError) -> String {
        if refusalMarkers.contains(where: { prompt.contains($0) }) {
            throw .refused
        }
        return "[mock-narration] \(prompt.prefix(120))"
    }
}

/// Stand-in used when no on-device model exists (e.g. macOS test hosts, old
/// hardware). Always throws `.unavailable` so fallback paths stay exercised.
public struct UnavailableLanguageModel: LanguageModelProviding {
    public let isAvailable = false

    public init() {}

    public func respond(to _: String) async throws(LanguageModelError) -> String {
        throw .unavailable
    }
}
