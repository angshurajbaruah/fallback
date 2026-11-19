import Foundation
import GRDB

/// Settings, Stats and Privacy (FR-29 to FR-36).
extension Store {
    // MARK: Stats (S7, FR-36)

    public struct Stats: Sendable, Equatable {
        public var sends: Int
        public var since: Date?
        /// Saves: the file was changed after a warning (FR-27).
        public var caught: Int
        /// Sends in each of the last 12 weeks, oldest first.
        public var perWeek: [Int]
        /// Saves by rule, most first: ("W1", 4).
        public var caughtBy: [(rule: String, count: Int)]
        /// Sends by app, most first.
        public var busiest: [(app: String, count: Int)]
        public var cardsShown: Int

        public static func == (a: Self, b: Self) -> Bool {
            a.sends == b.sends && a.caught == b.caught && a.perWeek == b.perWeek && a.since == b.since
        }
    }

    public func stats(now: Date = Date(), calendar: Calendar = .current) throws -> Stats {
        try db.read { db in
            let sends = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sends WHERE is_hidden = 0") ?? 0
            let since = try Date.fetchOne(db, sql: "SELECT MIN(sent_at) FROM sends WHERE is_hidden = 0")
            let caught = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM warnings WHERE outcome = 'fixed'") ?? 0
            let cards = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM warnings WHERE shown_as_card = 1") ?? 0
            let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let start = calendar.date(byAdding: .weekOfYear, value: -11, to: thisWeek) ?? thisWeek
            var weeks = [Int](repeating: 0, count: 12)
            for date in try Date.fetchAll(db, sql: "SELECT sent_at FROM sends WHERE is_hidden = 0 AND sent_at >= ?", arguments: [start]) {
                let index = calendar.dateComponents([.weekOfYear], from: start, to: date).weekOfYear ?? 0
                if (0..<12).contains(index) { weeks[index] += 1 }
            }
            let byRule = try Row.fetchAll(db, sql: """
                SELECT rule, COUNT(*) FROM warnings WHERE outcome = 'fixed' GROUP BY rule ORDER BY COUNT(*) DESC
                """).map { (rule: $0[0] as String, count: $0[1] as Int) }
            let byApp = try Row.fetchAll(db, sql: """
                SELECT app_name, COUNT(*) FROM sends WHERE is_hidden = 0 GROUP BY app_name ORDER BY COUNT(*) DESC LIMIT 3
                """).map { (app: $0[0] as String, count: $0[1] as Int) }
            return Stats(sends: sends, since: since, caught: caught, perWeek: weeks, caughtBy: byRule, busiest: byApp, cardsShown: cards)
        }
    }

    // MARK: Folders (screen 17)

    /// Indexed files and their total size under a folder.
    public func folderSummary(_ folder: String) throws -> (files: Int, bytes: Int64) {
        try db.read { db in
            let row = try Row.fetchOne(db, sql: "SELECT COUNT(*), COALESCE(SUM(size_bytes), 0) FROM files WHERE path LIKE ? ESCAPE '\\'",
                                       arguments: [Self.likePrefix(folder)])
            return (row?[0] ?? 0, row?[1] ?? 0)
        }
    }

    public func fingerprintCount() throws -> Int {
        try db.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM files WHERE sha256 IS NOT NULL") ?? 0 }
    }

    public func lastIndexed() throws -> Date? {
        try db.read { try Date.fetchOne($0, sql: "SELECT MAX(last_seen_at) FROM files WHERE in_watched_folder = 1") }
    }

    // MARK: Apps (screen 18, FR-3)

    /// Apps switched off in Settings › Apps. Everything else in the default list is watched.
    public func disabledApps() throws -> Set<String> {
        try db.read { Set(try String.fetchAll($0, sql: "SELECT bundle_id FROM watched_apps WHERE enabled = 0")) }
    }

    public func setApp(_ bundleID: String, enabled: Bool) throws {
        try db.write {
            try $0.execute(sql: """
                INSERT INTO watched_apps (bundle_id, enabled) VALUES (?, ?)
                ON CONFLICT(bundle_id) DO UPDATE SET enabled = excluded.enabled
                """, arguments: [bundleID, enabled])
        }
    }

    // MARK: Muting (screen 19)

    public struct Muted: Sendable, Identifiable, Hashable {
        public enum Kind: String, Sendable { case document, destination }
        public var id: String { "\(kind.rawValue)-\(itemID)" }
        public var kind: Kind
        public var itemID: Int64
        public var name: String
        public var mutedAt: Date?
    }

    public func muted() throws -> [Muted] {
        try db.read { db in
            let documents = try Row.fetchAll(db, sql: """
                SELECT f.id, f.display_name, (SELECT MAX(created_at) FROM warnings w WHERE w.family_id = f.id AND w.outcome = 'muted')
                FROM families f WHERE f.muted = 1
                """).map { Muted(kind: .document, itemID: $0[0], name: $0[1], mutedAt: $0[2]) }
            let destinations = try Row.fetchAll(db, sql: "SELECT id, label FROM destinations WHERE muted = 1")
                .map { Muted(kind: .destination, itemID: $0[0], name: $0[1], mutedAt: nil) }
            return documents + destinations
        }
    }

    public func unmute(_ item: Muted) throws {
        switch item.kind {
        case .document: try muteFamily(item.itemID, false)
        case .destination: try muteDestination(item.itemID, false)
        }
    }

    // MARK: Privacy (screen 20, FR-14, FR-33)

    /// Every send, all columns, UTF-8 with a byte-order mark so Excel opens it cleanly (FR-14).
    public func exportCSV() throws -> String {
        let rows = try sends(newestFirst: false)
        let header = ["Sent (UTC)", "File", "Path", "Fingerprint", "Size (bytes)", "Destination", "App", "Page", "Page title",
                      "Confidence", "Version", "Document"]
        let iso = ISO8601DateFormatter()
        let lines = rows.map { row in
            [iso.string(from: row.sentAt), row.fileName, row.path ?? "", row.sha256 ?? "", row.sizeBytes.map(String.init) ?? "",
             row.destinationLabel, row.appName, row.url ?? "", row.pageTitle ?? "", row.confidence.rawValue,
             row.versionLabel ?? "", row.familyName ?? ""].map(Self.csvField).joined(separator: ",")
        }
        return "\u{FEFF}" + ([header.map(Self.csvField).joined(separator: ",")] + lines).joined(separator: "\r\n") + "\r\n"
    }

    static func csvField(_ value: String) -> String {
        // Quote everything; also defuse spreadsheet formulas in file names and titles.
        let safe = ["=", "+", "-", "@"].contains(where: value.hasPrefix) ? "'" + value : value
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// FR-33: removes everything Fallback recorded, settings included, and compacts the file.
    public func deleteEverything() throws {
        try db.write { db in
            for table in ["warnings", "sends", "family_links", "files", "families", "destinations", "label_rules",
                          "watched_folders", "watched_apps", "settings"] {
                try db.execute(sql: "DELETE FROM \(table)")
            }
            try db.execute(sql: "DELETE FROM sends_fts")
        }
        try db.vacuum()
        _ = try? db.writeWithoutTransaction { try $0.checkpoint(.truncate) }
    }

    /// The database file's size on disk, for "Stored on this Mac".
    public var fileSize: Int64 {
        guard let path = db.path as String? else { return 0 }
        return ["", "-wal", "-shm"].reduce(0) { total, suffix in
            total + ((try? FileManager.default.attributesOfItem(atPath: path + suffix)[.size] as? NSNumber)?.int64Value ?? 0)
        }
    }
}

/// The permission's name as this Mac's own macOS shows it: "Accessibility" on older versions,
/// "Device Control and Data Access" on newer ones. Read from System Settings' own strings.
public enum SystemNames {
    public static var accessibility: String {
        let path = "/System/Library/ExtensionKit/Extensions/SecurityPrivacyExtension.appex/Contents/Resources/Localizable.loctable"
        guard let data = FileManager.default.contents(atPath: path),
              let table = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let english = table["en"] as? [String: Any], // some entries are plural rules, not plain text
              let name = english["ACCESSIBILITY"] as? String, !name.isEmpty else { return "Accessibility" }
        return name
    }
}
