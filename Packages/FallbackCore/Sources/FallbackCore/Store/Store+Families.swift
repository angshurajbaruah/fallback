import Foundation
import GRDB

/// A document family as By document lists it.
public struct FamilySummary: Sendable, Identifiable, Hashable, Decodable, FetchableRecord {
    public var id: Int64
    public var name: String
    public var memberCount: Int
    public var versionCount: Int
    public var variantCount: Int
    public var sendCount: Int
    public var placeCount: Int
    /// Newest version in the family's main format.
    public var newestVersion: Int?
    public var mainFormat: String?
    public var confidence: String?
    public var signals: String?
    public var extensions: String?
    public var lastActivity: Date?
}

/// One file in a family, for the version timeline (S3).
public struct FamilyMember: Sendable, Identifiable, Hashable, Decodable, FetchableRecord {
    public var id: Int64
    public var name: String
    public var path: String?
    public var sizeBytes: Int64?
    public var sha256: String?
    public var modifiedAt: Date?
    public var docModifiedAt: Date?
    public var whereFrom: String?
    public var docTitle: String?
    public var versionNumber: Int?
    public var isVariant: Bool
    /// Set on an exported PDF: the file it was made from (an export pair, not a newer version).
    public var exportOfID: Int64?
    public var familyID: Int64?

    public var editedAt: Date? { docModifiedAt ?? modifiedAt }
    public var versionLabel: String? { versionNumber.map { "v\($0)" } }
}

/// A warning row for the Ledger's Warnings view (screen 06). Warnings are created in M4.
public struct WarningRow: Sendable, Identifiable, Hashable, Decodable, FetchableRecord {
    public var id: Int64
    public var rule: String
    public var shownAsCard: Bool
    public var outcome: String?
    public var createdAt: Date
    public var fileName: String
    public var destinationLabel: String
    public var appName: String
    public var detail: String?
}

extension Store {
    // MARK: Indexing (FR-15 to FR-17)

    @discardableResult
    public func upsert(_ file: IndexedFile, inWatchedFolder: Bool) throws -> Int64 {
        try db.write { try upsert(file, inWatchedFolder: inWatchedFolder, at: Date(), $0) }
    }

    /// The size and date the index last saw at a path, to skip re-reading unchanged files.
    public func stamp(path: String) throws -> (size: Int64?, modified: Date?)? {
        try db.read { db in
            try Row.fetchOne(db, sql: "SELECT size_bytes, modified_at FROM files WHERE path = ?", arguments: [path])
                .map { ($0[0], $0[1]) }
        }
    }

    /// The file (or everything inside a folder) is gone or moved out of view. History is kept; the path is cleared.
    public func markMissing(path: String) throws {
        try db.write { db in
            try db.execute(sql: "UPDATE files SET path = NULL WHERE path = ? OR path LIKE ? ESCAPE '\\'",
                           arguments: [path, Self.likePrefix(path)])
        }
    }

    /// Indexed paths under a folder, to notice files deleted while Fallback wasn't running.
    public func indexedPaths(under folder: String) throws -> [String] {
        try db.read { try String.fetchAll($0, sql: "SELECT path FROM files WHERE path LIKE ? ESCAPE '\\'", arguments: [Self.likePrefix(folder)]) }
    }

    static func likePrefix(_ folder: String) -> String {
        let escaped = folder.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        return (escaped.hasSuffix("/") ? escaped : escaped + "/") + "%"
    }

    public func watchedFolders() throws -> [String] {
        try db.read { try String.fetchAll($0, sql: "SELECT path FROM watched_folders ORDER BY id") }
    }

    public func addWatchedFolder(_ path: String) throws {
        try db.write { try $0.execute(sql: "INSERT OR IGNORE INTO watched_folders (path) VALUES (?)", arguments: [path]) }
    }

    public func removeWatchedFolder(_ path: String) throws {
        try db.write { try $0.execute(sql: "DELETE FROM watched_folders WHERE path = ?", arguments: [path]) }
    }

    // MARK: Families (PRD 8.3)

    /// Everything the FamilyEngine needs, for every known file.
    public func evidence() throws -> [FileEvidence] {
        try db.read { db in
            var sends: [Int64: [SentTo]] = [:]
            for row in try Row.fetchAll(db, sql: """
                SELECT s.file_id, d.key, s.sent_at FROM sends s JOIN destinations d ON d.id = s.destination_id
                WHERE s.file_id IS NOT NULL AND s.is_hidden = 0
                """) {
                sends[row[0], default: []].append(SentTo(destinationKey: row[1], at: row[2]))
            }
            return try Row.fetchAll(db, sql: """
                SELECT id, name, sha256, modified_at, created_at, doc_modified_at, where_from, downloaded_at,
                       doc_title, doc_author, doc_created_at, doc_internal_id, text_signature, image_signature
                FROM files
                """).map { row in
                let image: Data? = row[13]
                return FileEvidence(id: row[0], name: row[1], sha256: row[2], modifiedAt: row[3], createdAt: row[4],
                                    docModifiedAt: row[5], whereFrom: row[6], downloadedAt: row[7], docTitle: row[8],
                                    docAuthor: row[9], docCreatedAt: row[10], docInternalID: row[11],
                                    textSignature: (row[12] as Data?).flatMap(TextSignature.from),
                                    imageHash: image.flatMap { $0.count >= 8 ? $0.withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) } : nil },
                                    imageColor: image.flatMap { $0.count == 12 ? $0.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 8, as: UInt32.self) } : nil },
                                    sends: sends[row[0]] ?? [])
            }
        }
    }

    public func userDecisions() throws -> [UserDecision] {
        try db.read { db in
            try Row.fetchAll(db, sql: "SELECT file_a_id, file_b_id, relation FROM family_links WHERE decided_by = 'user'").compactMap { row in
                let a: Int64 = row[0], b: Int64 = row[1]
                switch row[2] as String {
                case "same": return .same(a, b)
                case "separate": return .separate(a, b)
                case "dismissed": return .dismissed(a, b)
                default: return nil
                }
            }
        }
    }

    /// Saves the user's merge, split or "Not now" (FR-20). They always win over automatic evidence.
    public func addDecisions(_ decisions: [UserDecision]) throws {
        try db.write { db in
            for decision in decisions {
                let (a, b, relation): (Int64, Int64, String) = switch decision {
                case .same(let a, let b): (a, b, "same")
                case .separate(let a, let b): (a, b, "separate")
                case .dismissed(let a, let b): (a, b, "dismissed")
                }
                let (low, high) = (min(a, b), max(a, b))
                // A newer decision about the same pair replaces the older one.
                try db.execute(sql: "DELETE FROM family_links WHERE decided_by = 'user' AND file_a_id = ? AND file_b_id = ?",
                               arguments: [low, high])
                try db.execute(sql: """
                    INSERT INTO family_links (file_a_id, file_b_id, signal, confidence, relation, decided_by)
                    VALUES (?, ?, 'user', 'high', ?, 'user')
                    """, arguments: [low, high, relation])
            }
        }
    }

    /// Writes the FamilyEngine's result: families keep their id (and any name the user gave them) when
    /// most of their files stay together.
    public func apply(_ result: FamilyResult) throws {
        try db.write { db in
            let current = Dictionary(uniqueKeysWithValues: try Row.fetchAll(db, sql: "SELECT id, family_id FROM files")
                .map { ($0[0] as Int64, $0[1] as Int64?) })
            let stems = Dictionary(uniqueKeysWithValues: try Row.fetchAll(db, sql: "SELECT id, stem FROM files")
                .map { ($0[0] as Int64, $0[1] as String?) })
            var claimed = Set<Int64>()
            try db.execute(sql: "UPDATE files SET family_id = NULL, version_number = NULL, is_variant = 0, export_of_id = NULL")
            // Bigger groups first, so they keep their family ids.
            for group in result.groups.sorted(by: { $0.members.count > $1.members.count }) {
                // A lone file with a too-generic name has no family (PRD 10).
                if group.members.count == 1, stems[group.members[0]] ?? nil == nil { continue }
                let previous = group.members.compactMap { current[$0] ?? nil }.filter { !claimed.contains($0) }
                let counts = Dictionary(previous.map { ($0, 1) }, uniquingKeysWith: +)
                let signals = group.signals.map(\.rawValue).sorted().joined(separator: ",")
                let familyID: Int64
                if let reuse = counts.max(by: { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value })?.key {
                    familyID = reuse
                    try db.execute(sql: """
                        UPDATE families SET stem = ?, confidence = ?, signals = ?, main_format = ?,
                            display_name = CASE name_source WHEN 'user' THEN display_name ELSE ? END
                        WHERE id = ?
                        """, arguments: [group.name.lowercased(), group.confidence.name, signals, group.mainFormat, group.name, familyID])
                } else {
                    try db.execute(sql: "INSERT INTO families (stem, display_name, confidence, signals, main_format) VALUES (?, ?, ?, ?, ?)",
                                   arguments: [group.name.lowercased(), group.name, group.confidence.name, signals, group.mainFormat])
                    familyID = db.lastInsertedRowID
                }
                claimed.insert(familyID)
                for id in group.members {
                    try db.execute(sql: "UPDATE files SET family_id = ?, version_number = ?, is_variant = ?, export_of_id = ? WHERE id = ?",
                                   arguments: [familyID, group.versions[id], group.variants.contains(id), group.exportOf[id], id])
                }
            }
            try db.execute(sql: "DELETE FROM families WHERE id NOT IN (SELECT family_id FROM files WHERE family_id IS NOT NULL)")
            try db.execute(sql: "DELETE FROM family_links WHERE decided_by = 'auto'")
            for link in result.links where link.confidence >= .medium {
                try db.execute(sql: """
                    INSERT INTO family_links (file_a_id, file_b_id, signal, confidence, similarity, relation, decided_by, reasons)
                    VALUES (?, ?, ?, ?, ?, ?, 'auto', ?)
                    """, arguments: [link.a, link.b, link.signals.map(\.rawValue).joined(separator: ","), link.confidence.name,
                                     link.similarity, link.relation.rawValue, link.reasons.joined(separator: "|")])
            }
        }
    }

    public func renameFamily(_ id: Int64, to name: String) throws {
        try db.write {
            try $0.execute(sql: "UPDATE families SET display_name = ?, name_source = 'user' WHERE id = ?", arguments: [name, id])
        }
    }

    // MARK: Reading families

    public func families() throws -> [FamilySummary] {
        try db.read { db in
            try FamilySummary.fetchAll(db, sql: """
                SELECT fam.id AS id, fam.display_name AS name,
                       COUNT(DISTINCT f.id) AS memberCount,
                       COUNT(DISTINCT CASE WHEN f.version_number IS NOT NULL AND f.ext IS fam.main_format THEN f.id END) AS versionCount,
                       COUNT(DISTINCT CASE WHEN f.is_variant THEN f.id END) AS variantCount,
                       COUNT(DISTINCT s.id) AS sendCount, COUNT(DISTINCT s.destination_id) AS placeCount,
                       MAX(CASE WHEN f.ext IS fam.main_format THEN f.version_number END) AS newestVersion,
                       fam.confidence AS confidence, fam.signals AS signals, fam.main_format AS mainFormat,
                       GROUP_CONCAT(DISTINCT f.ext) AS extensions,
                       MAX(COALESCE(s.sent_at, f.doc_modified_at, f.modified_at)) AS lastActivity
                FROM families fam
                JOIN files f ON f.family_id = fam.id
                LEFT JOIN sends s ON s.file_id = f.id AND s.is_hidden = 0
                GROUP BY fam.id
                ORDER BY lastActivity DESC
                """)
        }
    }

    public func members(ofFamily id: Int64) throws -> [FamilyMember] {
        try db.read { try FamilyMember.fetchAll($0, sql: Self.selectMembers + " WHERE family_id = ?", arguments: [id]) }
    }

    public func files(ids: [Int64]) throws -> [FamilyMember] {
        guard !ids.isEmpty else { return [] }
        return try db.read { db in
            try FamilyMember.fetchAll(db, sql: Self.selectMembers + " WHERE id IN (\(ids.map { _ in "?" }.joined(separator: ",")))",
                                      arguments: StatementArguments(ids))
        }
    }

    private static let selectMembers = """
        SELECT id, name, path, size_bytes AS sizeBytes, sha256, modified_at AS modifiedAt,
               doc_modified_at AS docModifiedAt, where_from AS whereFrom, doc_title AS docTitle, version_number AS versionNumber,
               is_variant AS isVariant, export_of_id AS exportOfID, family_id AS familyID
        FROM files
        """

    /// Sends of every file in a family, keyed by file.
    public func sendsByFile(inFamily id: Int64) throws -> [Int64: [SendRow]] {
        let rows = try db.read { db in
            try SendRow.fetchAll(db, sql: "SELECT * FROM (\(Self.selectSendsSQL)) WHERE familyID = ? ORDER BY sentAt DESC", arguments: [id])
        }
        return Dictionary(grouping: rows) { $0.fileID ?? -1 }
    }

    /// Evidence labels between files, for the "Group into one document" dialog.
    public func linkReasons(among ids: [Int64]) throws -> [Int64: [String]] {
        guard ids.count > 1 else { return [:] }
        let marks = ids.map { _ in "?" }.joined(separator: ",")
        return try db.read { db in
            var out: [Int64: [String]] = [:]
            for row in try Row.fetchAll(db, sql: """
                SELECT file_a_id, file_b_id, reasons FROM family_links
                WHERE decided_by = 'auto' AND file_a_id IN (\(marks)) AND file_b_id IN (\(marks))
                """, arguments: StatementArguments(ids + ids)) {
                let reasons = (row[2] as String? ?? "").split(separator: "|").map(String.init)
                for id in [row[0] as Int64, row[1] as Int64] { out[id, default: []].append(contentsOf: reasons) }
            }
            return out.mapValues { Array(NSOrderedSet(array: $0)) as? [String] ?? $0 }
        }
    }

    /// Indexed files whose name matches but which were never sent, for "Also matching" in the popover.
    public func unsentFiles(matching text: String, limit: Int = 3) throws -> [FamilyMember] {
        let words = text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
        guard !words.isEmpty else { return [] }
        let conditions = words.map { _ in "LOWER(name) LIKE ? ESCAPE '\\'" }.joined(separator: " AND ")
        let arguments = words.map { "%" + $0.replacingOccurrences(of: "%", with: "\\%").replacingOccurrences(of: "_", with: "\\_") + "%" }
        return try db.read { db in
            try FamilyMember.fetchAll(db, sql: Self.selectMembers + """
                 WHERE path IS NOT NULL AND \(conditions) AND id NOT IN (SELECT file_id FROM sends WHERE file_id IS NOT NULL)
                 ORDER BY modified_at DESC LIMIT \(limit)
                """, arguments: StatementArguments(arguments))
        }
    }

    // MARK: Warnings (rows come from M4)

    public func warnings(outcome: String? = nil) throws -> [WarningRow] {
        try db.read { db in
            var sql = """
                SELECT w.id AS id, w.rule AS rule, w.shown_as_card AS shownAsCard, w.outcome AS outcome,
                       w.created_at AS createdAt, s.file_name_at_send AS fileName, d.label AS destinationLabel, s.app_name AS appName,
                       w.detail AS detail
                FROM warnings w JOIN sends s ON s.id = w.send_id JOIN destinations d ON d.id = s.destination_id
                """
            var arguments: StatementArguments = []
            if let outcome { sql += " WHERE w.outcome = ?"; arguments += [outcome] }
            sql += " ORDER BY w.created_at DESC"
            return try WarningRow.fetchAll(db, sql: sql, arguments: arguments)
        }
    }
}
