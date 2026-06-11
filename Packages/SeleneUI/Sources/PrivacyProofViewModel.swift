import SeleneCore

/// What data exists and where it lives — the inputs to the privacy-proof
/// screen. Built by the composition root from the real store; pure values so
/// the screen's claims are unit-testable on macOS.
public struct DataInventory: Hashable, Sendable {
    public enum StorageLocation: Hashable, Sendable {
        /// The production store: encrypted SQLite, file-protected, excluded
        /// from iCloud/device backups by default.
        case onDeviceEncrypted
        /// In-memory store (UI tests / one-session fallback) — nothing on disk.
        case inMemoryEphemeral
    }

    public let dailyLogCount: Int
    public let symptomEventCount: Int
    public let hasForecast: Bool
    public let storage: StorageLocation

    public init(
        dailyLogCount: Int,
        symptomEventCount: Int,
        hasForecast: Bool,
        storage: StorageLocation
    ) {
        self.dailyLogCount = dailyLogCount
        self.symptomEventCount = symptomEventCount
        self.hasForecast = hasForecast
        self.storage = storage
    }
}

/// View model for the airplane-mode privacy-proof screen.
///
/// Three user-facing sections, all deterministic copy (no model involved):
/// zero-egress status, a complete inventory of what data exists, and where it
/// lives — plus the verification steps a skeptical user can run themselves.
/// The proof is the brand (DESIGN.md); the claims here are backed by tests:
/// the repo-guard source scan and the URLProtocol egress harness.
public struct PrivacyProofViewModel: Hashable, Sendable {
    public struct DataRow: Hashable, Sendable, Identifiable {
        public let id: String
        public let label: String
        public let detail: String
    }

    public let inventory: DataInventory

    public init(inventory: DataInventory) {
        self.inventory = inventory
    }

    /// The headline status. True by construction for the core app — there is
    /// no networking code outside the paywall module, enforced by tests.
    public var egressStatusLine: String {
        "0 network calls. Selene's tracking, forecasting, and insight code contains "
            + "no networking — verified by an automated egress harness on every test run."
    }

    public var airplaneModeLine: String {
        "Turn on Airplane Mode and keep using every feature. Nothing changes, "
            + "because nothing ever leaves this device."
    }

    /// Complete inventory of what exists. No accounts, no identifiers — so the
    /// list is short and finite, and that is the point.
    public var dataRows: [DataRow] {
        [
            DataRow(
                id: "daily-logs",
                label: "Daily logs",
                detail: countDetail(inventory.dailyLogCount, singular: "entry", plural: "entries")
            ),
            DataRow(
                id: "symptoms",
                label: "Symptom records",
                detail: countDetail(inventory.symptomEventCount, singular: "entry", plural: "entries")
            ),
            DataRow(
                id: "forecast",
                label: "Cycle forecast",
                detail: inventory.hasForecast
                    ? "computed on this device by Selene's own math"
                    : "none yet — appears after your first logged period day"
            ),
            DataRow(
                id: "identity",
                label: "Account, name, or email",
                detail: "none — Selene has no accounts"
            ),
        ]
    }

    public var locationSummary: String {
        switch inventory.storage {
        case .onDeviceEncrypted:
            "Everything above lives in one encrypted database file on this device, "
                + "locked with full file protection and excluded from iCloud and "
                + "device backups by default. Export and delete are yours, in Settings."
        case .inMemoryEphemeral:
            "This session is running on a temporary in-memory store. Nothing is "
                + "written to disk; closing the app discards it."
        }
    }

    /// The verification steps a skeptical user (or reviewer) can reproduce.
    public var proofPoints: [String] {
        [
            "Airplane-mode demo: enable Airplane Mode, then log, forecast, and read insights.",
            "iOS App Privacy Report (Settings → Privacy & Security) shows zero network "
                + "activity for Selene's tracking features.",
            "Open source of truth: the test suite fails if any networking code appears "
                + "outside the purchase module, or if any network request is attempted.",
            "One third-party component total (a local database library) — no analytics, "
                + "no ads, no tracking SDKs. Ever.",
        ]
    }

    private func countDetail(_ count: Int, singular: String, plural: String) -> String {
        switch count {
        case 0: "none yet"
        case 1: "1 \(singular), on this device only"
        default: "\(count) \(plural), on this device only"
        }
    }
}
