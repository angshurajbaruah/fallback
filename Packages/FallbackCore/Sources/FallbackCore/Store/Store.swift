import Foundation
import GRDB

/// The ledger database (PRD 10): one SQLite file in WAL mode, all times in UTC.
public final class Store: Sendable {
    let db: any DatabaseWriter

    /// Opens (or creates) the database file and runs any new migrations.
    public convenience init(path: String) throws {
        try FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent,
                                                withIntermediateDirectories: true)
        try self.init(writer: DatabasePool(path: path)) // DatabasePool uses WAL (FR-9: no data loss on crash)
    }

    /// For tests.
    public static func inMemory() throws -> Store { try Store(writer: DatabaseQueue()) }

    private init(writer: any DatabaseWriter) throws {
        db = writer
        var migrator = DatabaseMigrator()
        Migrations.register(in: &migrator)
        try migrator.migrate(db)
    }

    // MARK: Recording (FR-9)

    /// Records a send with only the file's basic facts (the file is analysed by the indexer separately).
    @discardableResult
    public func record(_ send: NewSend, destination: Destination, facts: FileFacts?) throws -> Int64 {
        let file = send.path.map { IndexedFile(path: $0, name: send.fileName, facts: facts ?? FileFacts()) }
        return try record(send, destination: destination, file: file)
    }

    /// Records a send. Files picked from outside watched folders are still fingerprinted and kept (FR-19).
    @discardableResult
    public func record(_ send: NewSend, destination: Destination, file: IndexedFile?, inWatchedFolder: Bool = false) throws -> Int64 {
        let facts = file?.facts
        return try db.write { db in
            let fileID = try file.map { try upsert($0, inWatchedFolder: inWatchedFolder, at: send.sentAt, db) }
            let destinationID = try destinationID(for: destination, db)
            let confidence = Confidence(fileKnown: send.path != nil, urlKnown: send.url != nil)
            try db.execute(sql: """
                INSERT INTO sends (file_id, sha256, file_name_at_send, destination_id, app_bundle_id, app_name,
                                   url, page_title, confidence, detection_method, sent_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [fileID, facts?.sha256, send.fileName, destinationID, send.appBundleID, send.appName,
                                 send.url, send.pageTitle, confidence, send.method.rawValue, send.sentAt])
            return db.lastInsertedRowID
        }
    }

    /// One row per file, followed across renames and moves by its identity (FR-17). When an app saves by
    /// replacing the file (new identity, same path), the row at that path is kept.
    func upsert(_ file: IndexedFile, inWatchedFolder: Bool, at date: Date, _ db: Database) throws -> Int64 {
        let ext = (file.name as NSString).pathExtension.lowercased()
        var existing: Int64?
        if let identity = file.facts.identity {
            existing = try Int64.fetchOne(db, sql: "SELECT id FROM files WHERE file_identity = ?", arguments: [identity])
        }
        if existing == nil {
            existing = try Int64.fetchOne(db, sql: "SELECT id FROM files WHERE path = ? ORDER BY id DESC LIMIT 1", arguments: [file.path])
        }
        let analysed = file.textSignature != nil || file.imageHash != nil || file.docTitle != nil || file.docInternalID != nil
        let values: [(String, (any DatabaseValueConvertible)?)] = [
            ("file_identity", file.facts.identity), ("path", file.path), ("name", file.name), ("ext", ext),
            ("stem", NameStem.stem(file.name)), ("sha256", file.facts.sha256), ("size_bytes", file.facts.sizeBytes),
            ("modified_at", file.facts.modifiedAt), ("created_at", file.createdAt), ("last_seen_at", date),
            ("where_from", file.whereFrom), ("downloaded_at", file.downloadedAt),
        ] + (analysed || existing == nil ? [
            ("doc_title", file.docTitle), ("doc_author", file.docAuthor), ("doc_created_at", file.docCreatedAt),
            ("doc_modified_at", file.docModifiedAt), ("doc_internal_id", file.docInternalID),
            ("text_signature", file.textSignature.map(TextSignature.data)),
            // 8 bytes of layout hash, then 4 bytes of average colour.
            ("image_signature", file.imageHash.map { hash in
                withUnsafeBytes(of: hash) { Data($0) } + withUnsafeBytes(of: file.imageColor ?? 0) { Data($0) }
            }),
        ] : [])
        if let existing {
            let sets = values.map { "\($0.0) = ?" }.joined(separator: ", ")
            var arguments = StatementArguments(values.map(\.1))
            arguments += [inWatchedFolder, existing]
            try db.execute(sql: "UPDATE files SET \(sets), in_watched_folder = MAX(in_watched_folder, ?) WHERE id = ?", arguments: arguments)
            return existing
        }
        let columns = values.map(\.0) + ["first_seen_at", "in_watched_folder"]
        var arguments = StatementArguments(values.map(\.1))
        arguments += [date, inWatchedFolder]
        try db.execute(sql: "INSERT INTO files (\(columns.joined(separator: ", "))) VALUES (\(Array(repeating: "?", count: columns.count).joined(separator: ", ")))",
                       arguments: arguments)
        return db.lastInsertedRowID
    }

    /// Same place, same row. A user label for this key wins over the rule's label (FR-13).
    private func destinationID(for destination: Destination, _ db: Database) throws -> Int64 {
        if let id = try Int64.fetchOne(db, sql: "SELECT id FROM destinations WHERE key = ?", arguments: [destination.key]) {
            return id
        }
        let userLabel = try String.fetchOne(db, sql: "SELECT label FROM label_rules WHERE key = ?", arguments: [destination.key])
        try db.execute(sql: "INSERT INTO destinations (key, label, label_source) VALUES (?, ?, ?)",
                       arguments: [destination.key, userLabel ?? destination.label,
                                   userLabel == nil ? destination.source.rawValue : Destination.Source.user.rawValue])
        return db.lastInsertedRowID
    }

    // MARK: Reading (FR-10, FR-11)

    static var selectSendsSQL: String { selectSends }

    private static let selectSends = """
        SELECT s.id AS id, s.file_name_at_send AS fileName, f.path AS path, s.sha256 AS sha256,
               f.size_bytes AS sizeBytes, d.id AS destinationID, d.key AS destinationKey,
               d.label AS destinationLabel, s.app_bundle_id AS appBundleID, s.app_name AS appName,
               s.url AS url, s.page_title AS pageTitle, s.confidence AS confidence, s.sent_at AS sentAt,
               s.file_id AS fileID, f.version_number AS versionNumber, f.is_variant AS isVariant,
               f.family_id AS familyID, fam.display_name AS familyName
        FROM sends s
        JOIN destinations d ON d.id = s.destination_id
        LEFT JOIN files f ON f.id = s.file_id
        LEFT JOIN families fam ON fam.id = f.family_id
        """

    /// Newest first by default; `since` limits to a period (Today, 7 days).
    public func sends(since: Date? = nil, destinationID: Int64? = nil, newestFirst: Bool = true, limit: Int? = nil) throws -> [SendRow] {
        try db.read { db in
            var sql = Self.selectSends + " WHERE s.is_hidden = 0"
            var arguments: StatementArguments = []
            if let since { sql += " AND s.sent_at >= ?"; arguments += [since] }
            if let destinationID { sql += " AND s.destination_id = ?"; arguments += [destinationID] }
            sql += " ORDER BY s.sent_at \(newestFirst ? "DESC" : "ASC"), s.id \(newestFirst ? "DESC" : "ASC")"
            if let limit { sql += " LIMIT \(limit)" }
            return try SendRow.fetchAll(db, sql: sql, arguments: arguments)
        }
    }

    public func send(id: Int64) throws -> SendRow? {
        try db.read { try SendRow.fetchOne($0, sql: Self.selectSends + " WHERE s.id = ?", arguments: [id]) }
    }

    /// Search as you type across file names, destinations, page titles and apps (FR-10).
    public func search(_ text: String, limit: Int = 200) throws -> [SendRow] {
        guard let match = Self.ftsQuery(text) else { return [] }
        return try db.read { db in
            try SendRow.fetchAll(db, sql: Self.selectSends + """
                 JOIN sends_fts ON sends_fts.rowid = s.id
                 WHERE sends_fts MATCH ? AND s.is_hidden = 0
                 ORDER BY s.sent_at DESC LIMIT ?
                """, arguments: [match, limit])
        }
    }

    /// Every word must match the start of a word somewhere: "razor glo" → "razor"* "glo"*.
    static func ftsQuery(_ text: String) -> String? {
        let words = text.lowercased().split { !$0.isLetter && !$0.isNumber }
        guard !words.isEmpty else { return nil }
        return words.map { "\"\($0)\"*" }.joined(separator: " ")
    }

    public func sendCount() throws -> Int {
        try db.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM sends WHERE is_hidden = 0") ?? 0 }
    }

    public func destinations() throws -> [DestinationSummary] {
        try db.read { db in
            try DestinationSummary.fetchAll(db, sql: """
                SELECT d.id AS id, d.key AS key, d.label AS label, d.label_source AS labelSource,
                       COUNT(s.id) AS sendCount, MAX(s.sent_at) AS lastSentAt
                FROM destinations d JOIN sends s ON s.destination_id = d.id AND s.is_hidden = 0
                GROUP BY d.id ORDER BY lastSentAt DESC
                """)
        }
    }

    /// For "Did you mean Globex? 3 sends." when a search finds nothing.
    public func closestDestination(to text: String) throws -> DestinationSummary? {
        let query = text.lowercased().trimmingCharacters(in: .whitespaces)
        guard query.count >= 3 else { return nil }
        return try destinations()
            .map { ($0, Fuzzy.distance(query, $0.label.lowercased())) }
            .filter { $0.1 <= (query.count >= 4 ? max(2, query.count / 3) : 1) } // "gmial" is 2 edits from "gmail"
            .min { $0.1 < $1.1 }?.0
    }

    // MARK: Editing (FR-13)

    /// Renames the destination of one send. With `includingOthers`, every send to that place
    /// (earlier and future) gets the label; otherwise only this send.
    public func renameDestination(ofSend sendID: Int64, to label: String, includingOthers: Bool) throws {
        try db.write { db in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT d.id, d.key FROM sends s JOIN destinations d ON d.id = s.destination_id WHERE s.id = ?
                """, arguments: [sendID]) else { return }
            let destinationID: Int64 = row[0], key: String = row[1]
            if includingOthers {
                try relabel(destinationID: destinationID, key: key, label: label, db)
            } else {
                try db.execute(sql: "INSERT INTO destinations (key, label, label_source) VALUES (?, ?, 'user')",
                               arguments: ["\(key)#send-\(sendID)", label])
                try db.execute(sql: "UPDATE sends SET destination_id = ? WHERE id = ?", arguments: [db.lastInsertedRowID, sendID])
            }
        }
    }

    /// Renames a whole destination, for its earlier and future sends.
    public func renameDestination(id: Int64, to label: String) throws {
        try db.write { db in
            guard let key = try String.fetchOne(db, sql: "SELECT key FROM destinations WHERE id = ?", arguments: [id]) else { return }
            try relabel(destinationID: id, key: key, label: label, db)
        }
    }

    private func relabel(destinationID: Int64, key: String, label: String, _ db: Database) throws {
        try db.execute(sql: "UPDATE destinations SET label = ?, label_source = 'user' WHERE id = ?", arguments: [label, destinationID])
        try db.execute(sql: "INSERT INTO label_rules (key, label) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET label = excluded.label",
                       arguments: [key, label])
    }

    /// Other visible sends to the same destination, for "Also renames 3 earlier sends."
    public func otherSendCount(sameDestinationAs sendID: Int64) throws -> Int {
        try db.read { db in
            try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM sends WHERE is_hidden = 0 AND id != ?
                AND destination_id = (SELECT destination_id FROM sends WHERE id = ?)
                """, arguments: [sendID, sendID]) ?? 0
        }
    }

    public func deleteSend(id: Int64) throws {
        try db.write { try $0.execute(sql: "DELETE FROM sends WHERE id = ?", arguments: [id]) }
    }

    /// "Not a send": hidden everywhere but kept, so the same pick isn't treated as new.
    public func markNotASend(id: Int64) throws {
        try db.write { try $0.execute(sql: "UPDATE sends SET is_hidden = 1 WHERE id = ?", arguments: [id]) }
    }

    // MARK: Settings

    public func setting(_ key: String) throws -> String? {
        try db.read { try String.fetchOne($0, sql: "SELECT value FROM settings WHERE key = ?", arguments: [key]) }
    }

    public func setSetting(_ key: String, _ value: String?) throws {
        try db.write { db in
            if let value {
                try db.execute(sql: "INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                               arguments: [key, value])
            } else {
                try db.execute(sql: "DELETE FROM settings WHERE key = ?", arguments: [key])
            }
        }
    }
}

enum Fuzzy {
    /// Levenshtein edit distance.
    static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            previous = current
        }
        return previous[b.count]
    }
}
