import Foundation
@testable import Persistence
import SeleneCore
import Testing

/// Privacy proofs as tests (AGENTS.md testing priority #2): the on-disk store
/// must be backup-excluded by default, survive reopening (migration safety),
/// and carry file-protection on platforms that support it.
@Suite("Database protection & migration")
struct DatabaseProtectionTests {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("selene-tests-\(UUID().uuidString)")
    }

    @Test("database directory is excluded from backups by default")
    func backupExclusionApplied() throws {
        // Arrange
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        // Act
        _ = try SeleneDatabase(directory: directory)

        // Assert
        let values = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }

    @Test("file protection attribute is set on iOS")
    func fileProtectionOnIOS() throws {
        // Arrange
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        // Act
        _ = try SeleneDatabase(directory: directory)

        // Assert: complete protection on iOS; the attribute does not exist on macOS,
        // where at-rest encryption comes from FileVault instead.
        #if os(iOS)
            let attributes = try FileManager.default.attributesOfItem(atPath: directory.path)
            #expect(attributes[.protectionKey] as? FileProtectionType == .complete)
        #else
            #expect(Bool(true), "protectionKey is an iOS-family attribute; nothing to assert on macOS")
        #endif
    }

    @Test("database file lives inside the protected directory")
    func databaseFileLocation() throws {
        // Arrange
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        // Act
        _ = try SeleneDatabase(directory: directory)

        // Assert
        let databasePath = directory.appendingPathComponent("selene.sqlite").path
        #expect(FileManager.default.fileExists(atPath: databasePath))
    }

    @Test("reopening the store preserves data (migration round-trip)")
    func reopenPreservesData() throws {
        // Arrange
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let log = DailyLog(day: DayNumber(20614), flow: .heavy, note: "persisted")

        // Act: write with one instance, read with a fresh one.
        do {
            let first = try SeleneDatabase(directory: directory)
            try first.saveDailyLog(log)
        }
        let reopened = try SeleneDatabase(directory: directory)

        // Assert
        #expect(try reopened.dailyLogs() == [log])
    }

    @Test("migrations are registered and apply cleanly to an empty database")
    func migrationsApply() throws {
        let store = try SeleneDatabase(inMemory: ())
        // Schema exists: all entity reads succeed on the fresh store.
        #expect(try store.dailyLogs().isEmpty)
        #expect(try store.symptomEvents().isEmpty)
        #expect(try store.loadProfile() == nil)
        #expect(try store.latestForecast() == nil)
    }
}
