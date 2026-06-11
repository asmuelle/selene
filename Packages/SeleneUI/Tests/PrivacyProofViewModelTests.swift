import SeleneCore
@testable import SeleneUI
import Testing

@Suite("Privacy proof view model")
struct PrivacyProofViewModelTests {
    private func makeModel(
        logs: Int = 12,
        symptoms: Int = 5,
        hasForecast: Bool = true,
        storage: DataInventory.StorageLocation = .onDeviceEncrypted
    ) -> PrivacyProofViewModel {
        PrivacyProofViewModel(inventory: DataInventory(
            dailyLogCount: logs,
            symptomEventCount: symptoms,
            hasForecast: hasForecast,
            storage: storage
        ))
    }

    @Test("headline states zero network calls and that the claim is test-enforced")
    func egressStatus() {
        let model = makeModel()
        #expect(model.egressStatusLine.contains("0 network calls"))
        #expect(model.egressStatusLine.contains("egress harness"))
        #expect(model.airplaneModeLine.contains("Airplane Mode"))
    }

    @Test("data inventory reflects the exact counts from the store")
    func dataInventoryCounts() {
        // Arrange / Act
        let rows = makeModel(logs: 12, symptoms: 5).dataRows
        let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })

        // Assert
        #expect(byID["daily-logs"]?.detail.contains("12 entries") == true)
        #expect(byID["symptoms"]?.detail.contains("5 entries") == true)
        #expect(byID["forecast"]?.detail.contains("computed on this device") == true)
        #expect(byID["identity"]?.detail.contains("no accounts") == true)
    }

    @Test("empty store is honest: none yet, no forecast")
    func emptyStore() {
        let rows = makeModel(logs: 0, symptoms: 0, hasForecast: false).dataRows
        let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        #expect(byID["daily-logs"]?.detail == "none yet")
        #expect(byID["symptoms"]?.detail == "none yet")
        #expect(byID["forecast"]?.detail.contains("none yet") == true)
    }

    @Test("single entries use singular wording")
    func singularCounts() {
        let rows = makeModel(logs: 1, symptoms: 1).dataRows
        let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        #expect(byID["daily-logs"]?.detail.contains("1 entry") == true)
        #expect(byID["symptoms"]?.detail.contains("1 entry") == true)
    }

    @Test("on-device storage describes encryption and backup exclusion")
    func onDeviceLocation() {
        let summary = makeModel(storage: .onDeviceEncrypted).locationSummary
        #expect(summary.contains("encrypted"))
        #expect(summary.contains("excluded from iCloud"))
        #expect(summary.contains("Export and delete"))
    }

    @Test("ephemeral storage is described honestly, never claimed encrypted-on-disk")
    func ephemeralLocation() {
        let summary = makeModel(storage: .inMemoryEphemeral).locationSummary
        #expect(summary.contains("in-memory"))
        #expect(summary.contains("Nothing is written to disk"))
        #expect(!summary.contains("encrypted database file"))
    }

    @Test("proof points include the reproducible verifications")
    func proofPoints() {
        let points = makeModel().proofPoints
        #expect(points.count == 4)
        #expect(points.contains { $0.contains("Airplane-mode demo") })
        #expect(points.contains { $0.contains("App Privacy Report") })
        #expect(points.contains { $0.contains("test suite fails") })
        #expect(points.contains { $0.contains("no analytics") })
    }

    @Test("copy is deterministic and makes no diagnosis claims")
    func deterministicAndSafe() {
        let first = makeModel()
        let second = makeModel()
        #expect(first == second)
        let allCopy = (
            [first.egressStatusLine, first.airplaneModeLine, first.locationSummary]
                + first.proofPoints + first.dataRows.map { $0.label + " " + $0.detail }
        ).joined(separator: " ").lowercased()
        for banned in ["diagnos", "contracepti", "prevent pregnancy"] {
            #expect(!allCopy.contains(banned), "banned term '\(banned)' in privacy copy")
        }
    }
}
