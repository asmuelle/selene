import Foundation
import GRDB
import SeleneCore

/// The encrypted-at-rest local store.
///
/// Privacy posture (invariants #1, #6):
/// - `NSFileProtectionComplete` on the database directory (iOS).
/// - The directory is excluded from iCloud/device backups *by default*.
/// - No networking. No accounts. Export/delete are explicit local actions.
public final class SeleneDatabase: Sendable {
    let queue: DatabaseQueue

    /// Opens (or creates) the store inside `directory`, applying migrations and
    /// file protections. The directory is created if needed.
    public init(directory: URL) throws(PersistenceError) {
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true
            )
        } catch {
            throw .directorySetupFailed(underlying: String(describing: error))
        }

        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        let databaseURL = directory.appendingPathComponent("selene.sqlite")
        do {
            queue = try DatabaseQueue(path: databaseURL.path, configuration: configuration)
        } catch {
            throw .openFailed(underlying: String(describing: error))
        }

        do {
            try Self.migrator.migrate(queue)
        } catch {
            throw .migrationFailed(underlying: String(describing: error))
        }

        try Self.applyProtections(toDirectory: directory)
    }

    /// In-memory store for fast unit tests. Same schema, no files.
    public init(inMemory _: Void = ()) throws(PersistenceError) {
        do {
            queue = try DatabaseQueue()
            try Self.migrator.migrate(queue)
        } catch {
            throw .openFailed(underlying: String(describing: error))
        }
    }

    // MARK: - Schema

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1-initial-schema") { db in
            try db.create(table: DailyLogRecord.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("day", .integer).notNull().indexed()
                t.column("flow", .text)
                t.column("basalTemperatureCelsius", .double)
                t.column("sleepQuality", .integer)
                t.column("mood", .integer)
                t.column("note", .text)
                t.column("source", .text).notNull()
            }
            try db.create(table: SymptomEventRecord.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("day", .integer).notNull().indexed()
                t.column("code", .text).notNull()
                t.column("severity", .integer).notNull()
                t.column("extractionConfidence", .double)
                t.column("userConfirmed", .boolean).notNull()
            }
            try db.create(table: ForecastRecord.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("generatedAtDay", .integer).notNull().indexed()
                t.column("payload", .blob).notNull()
            }
            try db.create(table: ProfileRecord.databaseTableName) { t in
                t.primaryKey("id", .integer).check { $0 == ProfileRecord.singletonID }
                t.column("payload", .blob).notNull()
            }
        }
        return migrator
    }

    // MARK: - File protection & backup exclusion

    /// Applies `NSFileProtectionComplete` (iOS) and backup exclusion to the
    /// database directory. Exclusion-by-default is invariant #6: reproductive
    /// data must not silently land in cloud backups.
    static func applyProtections(toDirectory directory: URL) throws(PersistenceError) {
        #if os(iOS)
            do {
                try FileManager.default.setAttributes(
                    [.protectionKey: FileProtectionType.complete],
                    ofItemAtPath: directory.path
                )
            } catch {
                throw .directorySetupFailed(underlying: String(describing: error))
            }
        #endif
        var mutableURL = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        do {
            try mutableURL.setResourceValues(values)
        } catch {
            throw .backupExclusionFailed(underlying: String(describing: error))
        }
    }
}
