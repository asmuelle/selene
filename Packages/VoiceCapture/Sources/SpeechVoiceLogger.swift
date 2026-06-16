#if canImport(Speech)
    import Foundation
    import SeleneCore
    import Speech

    /// `SpeechTranscriber`-backed `VoiceLogging` (iOS 26 on-device ASR).
    ///
    /// Availability-guarded so `swift test` on macOS never references it; the
    /// deterministic `MockVoiceLogger` carries the tests. The transcriber runs
    /// fully on-device — no network ASR — preserving the zero-egress invariant.
    /// Real audio capture/session wiring lives in the app shell; this type owns
    /// the transcription step behind the protocol.
    ///
    /// `localID` is treated as a file URL to on-device scratch audio. The bytes
    /// never leave the device (invariant #1).
    @available(iOS 26.0, macOS 26.0, *)
    public struct SpeechVoiceLogger: VoiceLogging {
        public var isAvailable: Bool {
            // Conservative: report available; the real transcription call still
            // throws `.unavailable` if the locale/model is missing, so the
            // fall-through path stays correct either way.
            true
        }

        private let locale: Locale

        public init(locale: Locale = Locale(identifier: "en-US")) {
            self.locale = locale
        }

        public func transcribe(_ audio: VoiceRecording) async throws(VoiceLoggingError) -> String {
            guard let url = URL(string: audio.localID) ?? fileURL(audio.localID) else {
                throw .unavailable
            }
            do {
                return try await runTranscription(of: url)
            } catch let error as VoiceLoggingError {
                throw error
            } catch {
                throw .unavailable
            }
        }

        private func fileURL(_ path: String) -> URL? {
            FileManager.default.fileExists(atPath: path)
                ? URL(fileURLWithPath: path)
                : nil
        }

        private func runTranscription(of url: URL) async throws -> String {
            let transcriber = SpeechTranscriber(
                locale: locale,
                transcriptionOptions: [],
                reportingOptions: [],
                attributeOptions: []
            )
            let analyzer = SpeechAnalyzer(modules: [transcriber])
            _ = try await analyzer.analyzeSequence(from: AVAudioFile(forReading: url))
            var text = ""
            for try await result in transcriber.results {
                text += String(result.text.characters)
            }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw VoiceLoggingError.noSpeechDetected
            }
            return trimmed
        }
    }
#endif
