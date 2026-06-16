import InsightKit
import SeleneCore

/// The outcome of a voice-capture attempt: either a transcript with candidate
/// entries to confirm, or a graceful fall-through reason. Never an error screen.
public enum VoiceCaptureOutcome: Hashable, Sendable {
    /// Transcribed successfully; `candidates` are SUGGESTIVE and await the user's
    /// confirm tap before anything persists (key flow #1).
    case transcribed(transcript: String, candidates: ExtractionResult)
    /// The feature is gated off — the caller should not have offered it.
    case notEntitled
    /// Speech transcription was unavailable — fall through to manual typing.
    case unavailable
    /// Audio produced no usable speech — prompt a retry or typing.
    case noSpeechDetected
}

/// Wires the voice-logging path: gate check → on-device transcription → on-device
/// extraction → candidate entries for confirmation.
///
/// Every step is on-device (invariant #1); the same `SymptomExtracting` used for
/// typed text is reused, so the voice path inherits the deterministic-before-LLM
/// and confirm-before-commit guarantees. Nothing here persists or networks.
public struct VoiceCaptureFlow: Sendable {
    private let voice: any VoiceLogging
    private let extractor: any SymptomExtracting

    public init(voice: any VoiceLogging, extractor: any SymptomExtracting) {
        self.voice = voice
        self.extractor = extractor
    }

    /// Runs the capture, gated by `isEntitled` (the `.voiceLogging` decision).
    public func capture(
        _ recording: VoiceRecording,
        isEntitled: Bool
    ) async -> VoiceCaptureOutcome {
        guard isEntitled else {
            return .notEntitled
        }
        let transcript: String
        do {
            transcript = try await voice.transcribe(recording)
        } catch let error as VoiceLoggingError {
            switch error {
            case .unavailable: return .unavailable
            case .noSpeechDetected: return .noSpeechDetected
            }
        }
        let candidates = await extractor.extract(from: transcript)
        return .transcribed(transcript: transcript, candidates: candidates)
    }
}
