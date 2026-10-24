import Foundation
import SQLite3

final class PersistentStore {
    static let shared = PersistentStore()

    private let lock = NSRecursiveLock()
    private var database: OpaquePointer?
    private let migrationKey = "storage-v2000"

    private init() {
        do {
            let directory = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("NicoFlick", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("userdata.sqlite")
            guard sqlite3_open(url.path, &database) == SQLITE_OK else { return }
            try execute("PRAGMA journal_mode=WAL")
            try execute("PRAGMA synchronous=NORMAL")
            try execute("CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value INTEGER NOT NULL)")
            try execute("CREATE TABLE IF NOT EXISTS scores (level_id INTEGER PRIMARY KEY, score INTEGER NOT NULL, rank INTEGER NOT NULL, sent INTEGER NOT NULL, level INTEGER NOT NULL)")
            try execute("CREATE TABLE IF NOT EXISTS pending_scores (level_id INTEGER PRIMARY KEY, score INTEGER NOT NULL, rank INTEGER NOT NULL, sent INTEGER NOT NULL, level INTEGER NOT NULL)")
            try execute("CREATE TABLE IF NOT EXISTS play_history (level_id INTEGER PRIMARY KEY, play_count INTEGER NOT NULL, last_played_at REAL NOT NULL)")
            try execute("CREATE TABLE IF NOT EXISTS play_counts (level_id INTEGER PRIMARY KEY, count INTEGER NOT NULL)")
        } catch {
            close()
        }
    }

    deinit { close() }

    var isMigrated: Bool {
        lock.withLock {
            guard database != nil else { return false }
            return (try? scalarInt("SELECT value FROM metadata WHERE key = ?", text: migrationKey)) == 1
        }
    }

    func migrate(
        scores: [Int: [Int]],
        scoreLevels: [Int: Int],
        pendingScores: [Int: [Int]],
        pendingScoreLevels: [Int: Int],
        histories: [Int: LevelPlayHistory],
        playCounts: [Int: Int]
    ) -> Bool {
        lock.withLock {
            guard database != nil else { return false }
            if isMigrated { return true }
            do {
                try execute("BEGIN IMMEDIATE TRANSACTION")
                for (id, value) in scores where value.count >= 3 {
                    try upsertScore(table: "scores", id: id, values: value, level: scoreLevels[id] ?? 0)
                }
                for (id, value) in pendingScores where value.count >= 3 {
                    try upsertScore(table: "pending_scores", id: id, values: value, level: pendingScoreLevels[id] ?? 0)
                }
                for (id, history) in histories {
                    try execute(
                        "INSERT OR REPLACE INTO play_history(level_id, play_count, last_played_at) VALUES (?, ?, ?)",
                        integers: [id, history.playCount],
                        double: history.lastPlayedAt
                    )
                }
                for (id, count) in playCounts {
                    try execute("INSERT OR REPLACE INTO play_counts(level_id, count) VALUES (?, ?)", integers: [id, count])
                }
                try execute("INSERT OR REPLACE INTO metadata(key, value) VALUES ('storage-v2000', 1)")
                try execute("COMMIT")
                return true
            } catch {
                try? execute("ROLLBACK")
                return false
            }
        }
    }

    func scores(pending: Bool) -> ([Int: [Int]], [Int: Int]) {
        lock.withLock {
            let table = pending ? "pending_scores" : "scores"
            var values: [Int: [Int]] = [:]
            var levels: [Int: Int] = [:]
            query("SELECT level_id, score, rank, sent, level FROM \(table)") { statement in
                let id = Int(sqlite3_column_int64(statement, 0))
                values[id] = [
                    Int(sqlite3_column_int64(statement, 1)),
                    Int(sqlite3_column_int64(statement, 2)),
                    Int(sqlite3_column_int64(statement, 3))
                ]
                levels[id] = Int(sqlite3_column_int64(statement, 4))
            }
            return (values, levels)
        }
    }

    func replaceScores(_ scores: [Int: [Int]], levels: [Int: Int], pending: Bool) {
        lock.withLock {
            let table = pending ? "pending_scores" : "scores"
            do {
                try execute("BEGIN IMMEDIATE TRANSACTION")
                try execute("DELETE FROM \(table)")
                for (id, value) in scores where value.count >= 3 {
                    try upsertScore(table: table, id: id, values: value, level: levels[id] ?? 0)
                }
                try execute("COMMIT")
            } catch {
                try? execute("ROLLBACK")
            }
        }
    }

    func histories() -> [Int: LevelPlayHistory] {
        lock.withLock {
            var result: [Int: LevelPlayHistory] = [:]
            query("SELECT level_id, play_count, last_played_at FROM play_history") { statement in
                result[Int(sqlite3_column_int64(statement, 0))] = LevelPlayHistory(
                    playCount: Int(sqlite3_column_int64(statement, 1)),
                    lastPlayedAt: sqlite3_column_double(statement, 2)
                )
            }
            return result
        }
    }

    func replaceHistories(_ histories: [Int: LevelPlayHistory]) {
        lock.withLock {
            do {
                try execute("BEGIN IMMEDIATE TRANSACTION")
                try execute("DELETE FROM play_history")
                for (id, history) in histories {
                    try execute(
                        "INSERT INTO play_history(level_id, play_count, last_played_at) VALUES (?, ?, ?)",
                        integers: [id, history.playCount],
                        double: history.lastPlayedAt
                    )
                }
                try execute("COMMIT")
            } catch {
                try? execute("ROLLBACK")
            }
        }
    }

    func recordPlay(levelID: Int, at date: Date) {
        lock.withLock {
            try? execute(
                """
                INSERT INTO play_history(level_id, play_count, last_played_at) VALUES (?, 1, ?)
                ON CONFLICT(level_id) DO UPDATE SET
                    play_count = play_count + 1,
                    last_played_at = excluded.last_played_at
                """,
                integers: [levelID],
                double: date.timeIntervalSince1970
            )
        }
    }

    func playCounts() -> [Int: Int] {
        lock.withLock {
            var result: [Int: Int] = [:]
            query("SELECT level_id, count FROM play_counts") {
                result[Int(sqlite3_column_int64($0, 0))] = Int(sqlite3_column_int64($0, 1))
            }
            return result
        }
    }

    func replacePlayCounts(_ counts: [Int: Int]) {
        lock.withLock {
            do {
                try execute("BEGIN IMMEDIATE TRANSACTION")
                try execute("DELETE FROM play_counts")
                for (id, count) in counts {
                    try execute("INSERT INTO play_counts(level_id, count) VALUES (?, ?)", integers: [id, count])
                }
                try execute("COMMIT")
            } catch {
                try? execute("ROLLBACK")
            }
        }
    }

    private func upsertScore(table: String, id: Int, values: [Int], level: Int) throws {
        try execute(
            "INSERT OR REPLACE INTO \(table)(level_id, score, rank, sent, level) VALUES (?, ?, ?, ?, ?)",
            integers: [id, values[0], values[1], values[2], level]
        )
    }

    private func query(_ sql: String, row: (OpaquePointer) -> Void) {
        guard let database else { return }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else { return }
        defer { sqlite3_finalize(statement) }
        while sqlite3_step(statement) == SQLITE_ROW { row(statement) }
    }

    private func scalarInt(_ sql: String, text: String) throws -> Int? {
        guard let database else { throw StoreError.unavailable }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else { throw StoreError.sqlite }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, text, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        return sqlite3_step(statement) == SQLITE_ROW ? Int(sqlite3_column_int64(statement, 0)) : nil
    }

    private func execute(_ sql: String, integers: [Int] = [], double: Double? = nil) throws {
        guard let database else { throw StoreError.unavailable }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else { throw StoreError.sqlite }
        defer { sqlite3_finalize(statement) }
        for (index, value) in integers.enumerated() {
            sqlite3_bind_int64(statement, Int32(index + 1), sqlite3_int64(value))
        }
        if let double {
            sqlite3_bind_double(statement, Int32(integers.count + 1), double)
        }
        guard sqlite3_step(statement) == SQLITE_DONE || sqlite3_column_count(statement) > 0 else {
            throw StoreError.sqlite
        }
    }

    private func close() {
        if let database {
            sqlite3_close(database)
            self.database = nil
        }
    }

    private enum StoreError: Error {
        case unavailable
        case sqlite
    }
}

private extension NSRecursiveLock {
    func withLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}

enum LargeValueStore {
    private static func url(for key: String) throws -> URL {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("NicoFlick", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("\(key).json")
    }

    static func read(_ key: String) -> String? {
        guard let url = try? url(for: key),
              let data = try? Data(contentsOf: url) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func write(_ value: String, key: String) -> Bool {
        guard let url = try? url(for: key),
              let data = value.data(using: .utf8) else { return false }
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch {
            return false
        }
    }
}
