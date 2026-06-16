import CycleEngine
import DoctorVisit
import Foundation
import InsightKit
import Paywall
import SeleneCore
import VoiceCapture

/// App-shell composition for the M4 data plane. Thin wiring only — every piece of
/// logic lives in the SPM core (DoctorVisit / InsightKit / VoiceCapture), which is
/// where the tests are. These helpers exist so the app shell links and drives the
/// M4 modules behind the existing feature gates; the heavy SwiftUI surfaces are
/// deferred (device-blocked verification), but the plumbing is real and gated.
enum M4Composition {
    /// Builds a doctor-visit document + rendered bytes for a range, gated by the
    /// `.doctorVisitSummary` entitlement. Returns nil when the gate is closed —
    /// the caller shows the paywall preview instead.
    @MainActor
    static func doctorVisitExport(
        store: any SeleneStoring,
        entitlements: EntitlementStore,
        range: ClosedRange<DayNumber>,
        today: DayNumber,
        renderer: any DoctorVisitRendering = PlainTextDoctorVisitRenderer()
    ) -> Data? {
        guard entitlements.isUnlocked(.doctorVisitSummary) else {
            return nil
        }
        guard let document = try? DoctorVisitAssembler(store: store).makeDocument(
            range: range, generatedAtDay: today, isEntitled: true
        ) else {
            return nil
        }
        return try? renderer.render(document)
    }

    /// The default on-device extractor for typed/voice text. Uses the
    /// deterministic keyword extractor unless a FoundationModels extractor is
    /// available and supported; the real one is availability-guarded inside
    /// InsightKit so this resolves to the mock on hosts without the model.
    static func defaultExtractor() -> any SymptomExtracting {
        #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                let fm = FoundationModelExtractor()
                if fm.isAvailable {
                    return fm
                }
            }
        #endif
        return KeywordSymptomExtractor()
    }

    /// The default on-device voice logger. SpeechTranscriber-backed when the
    /// platform supports it, else the unavailable stand-in (capture falls through
    /// to manual typing — never errors).
    static func defaultVoiceLogger() -> any VoiceLogging {
        #if canImport(Speech)
            if #available(iOS 26.0, *) {
                return SpeechVoiceLogger()
            }
        #endif
        return UnavailableVoiceLogger()
    }

    /// The voice-capture flow wired behind the `.voiceLogging` gate.
    static func voiceCaptureFlow() -> VoiceCaptureFlow {
        VoiceCaptureFlow(voice: defaultVoiceLogger(), extractor: defaultExtractor())
    }

    /// Ordered Today surfaces for the current profile — the perimenopause funnel's
    /// insight-ordering behaviour, computed by the tested `InsightOrdering`.
    static func todaySurfaces(
        for profile: UserProfile,
        recentClusters: [SymptomClusterRow]
    ) -> [TodaySurface] {
        InsightOrdering.surfaces(for: profile, recentClusters: recentClusters)
    }
}
