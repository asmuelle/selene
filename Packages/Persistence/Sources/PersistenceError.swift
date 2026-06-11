import Foundation

/// Typed failures at the storage boundary. Messages never contain health data —
/// only structural context (table names, operation kinds).
public enum PersistenceError: Error, Sendable {
    case directorySetupFailed(underlying: String)
    case openFailed(underlying: String)
    case migrationFailed(underlying: String)
    case writeFailed(entity: String, underlying: String)
    case readFailed(entity: String, underlying: String)
    case corruptRow(entity: String, detail: String)
    case backupExclusionFailed(underlying: String)
}
