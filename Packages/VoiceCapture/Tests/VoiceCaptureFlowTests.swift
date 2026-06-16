import InsightKit
import SeleneCore
import Testing
@testable import VoiceCapture

@Suite("Voice capture flow")
struct VoiceCaptureFlowTests {
    private let recording = VoiceRecording(localID: "rec-1", durationSeconds: 3.2)

    private func flow(
        transcripts: [String: String],
        available: Bool = true
    ) -> VoiceCaptureFlow {
        VoiceCaptureFlow(
            voice: MockVoiceLogger(isAvailable: available, transcripts: transcripts),
            extractor: KeywordSymptomExtractor()
        )
    }

    @Test("a successful transcription yields candidate entries to confirm")
    func transcribeToCandidates() async {
        let outcome = await flow(transcripts: ["rec-1": "hot flashes and night sweats"])
            .capture(recording, isEntitled: true)
        guard case let .transcribed(transcript, candidates) = outcome else {
            Issue.record("expected .transcribed, got \(outcome)")
            return
        }
        #expect(transcript == "hot flashes and night sweats")
        #expect(candidates.codes == [.hotFlashes, .nightSweats])
    }

    @Test("the feature is gated: no transcription without the entitlement")
    func gateEnforced() async {
        let outcome = await flow(transcripts: ["rec-1": "cramps"])
            .capture(recording, isEntitled: false)
        #expect(outcome == .notEntitled)
    }

    @Test("an unavailable transcriber falls through, never errors")
    func unavailableFallsThrough() async {
        let outcome = await flow(transcripts: [:], available: false)
            .capture(recording, isEntitled: true)
        #expect(outcome == .unavailable)
    }

    @Test("no usable speech yields a retry-able outcome, not a crash")
    func noSpeech() async {
        let outcome = await flow(transcripts: ["rec-1": ""])
            .capture(recording, isEntitled: true)
        #expect(outcome == .noSpeechDetected)
    }

    @Test("candidates are suggestive: nothing is committed by the flow")
    func candidatesAreSuggestive() async {
        // The flow returns candidates; it has no store and persists nothing.
        let outcome = await flow(transcripts: ["rec-1": "bad cramps"])
            .capture(recording, isEntitled: true)
        if case let .transcribed(_, candidates) = outcome {
            #expect(candidates.symptoms.allSatisfy { $0.confidence > 0 })
        } else {
            Issue.record("expected candidates")
        }
    }
}

@Suite("Voice logging mocks")
struct VoiceLoggingMockTests {
    @Test("the unavailable logger always throws unavailable")
    func unavailableLogger() async {
        let logger = UnavailableVoiceLogger()
        #expect(!logger.isAvailable)
        do {
            _ = try await logger.transcribe(VoiceRecording(localID: "x", durationSeconds: 1))
            Issue.record("expected unavailable to throw")
        } catch {
            #expect(error == .unavailable)
        }
    }

    @Test("the mock logger returns its scripted transcript")
    func mockLogger() async throws {
        let logger = MockVoiceLogger(transcripts: ["a": "night sweats"])
        let text = try await logger.transcribe(VoiceRecording(localID: "a", durationSeconds: 1))
        #expect(text == "night sweats")
    }
}
