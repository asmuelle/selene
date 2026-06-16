import Foundation
import GRDB
@testable import Persistence
import SeleneCore
import Testing

/// Corrupt rows must surface as typed errors — never as silently wrong health data.
@Suite("Corrupt row handling")
struct CorruptRowTests {
    private func storeWithRawRow(sql: String, arguments: StatementArguments) throws -> SeleneDatabase {
        let store = try SeleneDatabase(inMemory: ())
        try store.queue.write { db in
            try db.execute(sql: sql, arguments: arguments)
        }
        return store
    }

    @Test("an unknown flow value throws corruptRow instead of guessing")
    func invalidFlowValue() throws {
        // Arrange
        let store = try storeWithRawRow(
            sql: """
            INSERT INTO daily_log (id, day, flow, source) VALUES (?, ?, ?, ?)
            """,
            arguments: [UUID().uuidString, 100, "torrential", "tap"]
        )

        // Act & Assert
        #expect(throws: Persistence.PersistenceError.self) {
            _ = try store.dailyLogs()
        }
    }

    @Test("an invalid uuid in a stored row throws corruptRow")
    func invalidUUID() throws {
        let store = try storeWithRawRow(
            sql: "INSERT INTO daily_log (id, day, source) VALUES (?, ?, ?)",
            arguments: ["not-a-uuid", 100, "tap"]
        )
        #expect(throws: Persistence.PersistenceError.self) {
            _ = try store.dailyLogs()
        }
    }

    @Test("an unknown symptom code throws corruptRow")
    func unknownSymptomCode() throws {
        let store = try storeWithRawRow(
            sql: """
            INSERT INTO symptom_event (id, day, code, severity, userConfirmed)
            VALUES (?, ?, ?, ?, ?)
            """,
            arguments: [UUID().uuidString, 100, "vaporware_symptom", 2, true]
        )
        #expect(throws: Persistence.PersistenceError.self) {
            _ = try store.symptomEvents()
        }
    }

    @Test("an out-of-range severity throws corruptRow")
    func severityOutOfRange() throws {
        let store = try storeWithRawRow(
            sql: """
            INSERT INTO symptom_event (id, day, code, severity, userConfirmed)
            VALUES (?, ?, ?, ?, ?)
            """,
            arguments: [UUID().uuidString, 100, "cramps", 9, true]
        )
        #expect(throws: Persistence.PersistenceError.self) {
            _ = try store.symptomEvents()
        }
    }

    @Test("a corrupt forecast payload throws corruptRow")
    func corruptForecastPayload() throws {
        let store = try storeWithRawRow(
            sql: "INSERT INTO forecast (id, generatedAtDay, payload) VALUES (?, ?, ?)",
            arguments: [UUID().uuidString, 100, #require("not json".data(using: .utf8))]
        )
        #expect(throws: Persistence.PersistenceError.self) {
            _ = try store.latestForecast()
        }
    }

    @Test("a non-JSON profile payload throws corruptRow")
    func corruptProfilePayload() throws {
        let store = try storeWithRawRow(
            sql: "INSERT INTO user_profile (id, payload) VALUES (?, ?)",
            arguments: [1, #require("not json".data(using: .utf8))]
        )
        #expect(throws: Persistence.PersistenceError.self) {
            _ = try store.loadProfile()
        }
    }

    @Test("an empty-object profile payload decodes with defaults (M4 backward-compat)")
    func emptyObjectProfileDecodesToDefault() throws {
        // M4 made UserProfile decoding tolerant of missing keys so pre-M4 rows
        // survive an upgrade. `{}` is therefore a valid (default) profile now,
        // not a corrupt row.
        let store = try storeWithRawRow(
            sql: "INSERT INTO user_profile (id, payload) VALUES (?, ?)",
            arguments: [1, #require("{}".data(using: .utf8))]
        )
        let profile = try store.loadProfile()
        #expect(profile == UserProfile())
    }
}
