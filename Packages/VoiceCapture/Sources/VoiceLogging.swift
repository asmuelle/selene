import SeleneCore

/// Why a voice transcription could not be produced.
public enum VoiceLoggingError: Error, Equatable, Sendable {
    /// On-device speech transcription is not available (no model, permission
    /// denied, unsupported hardware). The capture flow falls through to typing.
    case unavailable
    /// The audio yielded no usable transcript.
    case noSpeechDetected
}

/// The on-device voice-capture boundary.
///
/// Implementations transcribe spoken audio to text ON DEVICE only — never a
/// network ASR (invariant #1). The deterministic `MockVoiceLogger` carries the
/// tests; the `SpeechTranscriber`-backed implementation is availability-guarded.
/// The transcript then feeds `SymptomExtracting` exactly like typed text, so the
/// whole voice path is zero-egress and reuses the confirm-before-commit flow.
public protocol VoiceLogging: Sendable {
    var isAvailable: Bool { get }
    /// Transcribes a finished on-device recording into text. Throws on
    /// unavailability so the caller can fall through to manual typing.
    func transcribe(_ audio: VoiceRecording) async throws(VoiceLoggingError) -> String
}

/// An opaque handle to captured on-device audio. The bytes never leave the
/// device; this type only carries a local reference plus duration for the UI.
public struct VoiceRecording: Hashable, Sendable {
    /// Local-only identifier for the in-memory/scratch audio. Never a URL to a
    /// remote resource.
    public let localID: String
    public let durationSeconds: Double

    public init(localID: String, durationSeconds: Double) {
        self.localID = localID
        self.durationSeconds = durationSeconds
    }
}

/// Deterministic mock: returns a scripted transcript per recording id. No audio,
/// no model, no permission prompt — carries every test of the voice path.
public struct MockVoiceLogger: VoiceLogging {
    public let isAvailable: Bool
    private let transcripts: [String: String]

    public init(isAvailable: Bool = true, transcripts: [String: String]) {
        self.isAvailable = isAvailable
        self.transcripts = transcripts
    }

    public func transcribe(_ audio: VoiceRecording) async throws(VoiceLoggingError) -> String {
        guard isAvailable else {
            throw .unavailable
        }
        guard let text = transcripts[audio.localID], !text.isEmpty else {
            throw .noSpeechDetected
        }
        return text
    }
}

/// Stand-in for hosts with no speech stack (macOS test host, simulators without
/// the model). Always unavailable so the fall-through-to-typing path stays
/// exercised.
public struct UnavailableVoiceLogger: VoiceLogging {
    public let isAvailable = false

    public init() {}

    public func transcribe(_: VoiceRecording) async throws(VoiceLoggingError) -> String {
        throw .unavailable
    }
}
