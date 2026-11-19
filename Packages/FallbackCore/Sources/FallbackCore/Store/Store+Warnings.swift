import Foundation
import GRDB

extension Store {
    /// Destinations that are a service, not a recipient: W4 can't know who the file is going to.
    static let serviceDestinations: Set<String> = ["gmail", "outlook", "whatsapp-web"]

    /// Everything the WarningEngine needs to judge one recorded send.
    public func warningInput(forSend sendID: Int64, now: Date = Date()) throws -> WarningInput? {
        try db.read { db in
            guard let send = try Row.fetchOne(db, sql: """
                SELECT s.id, s.file_id, s.file_name_at_send, s.sha256, s.url, s.page_title, s.confidence,
                       d.id, d.key, d.label, d.muted, d.label_source, d.label_asked,
                       f.doc_modified_at, f.modified_at, f.family_id, f.version_number, f.is_variant, f.export_of_id,
                       fam.muted
                FROM sends s JOIN destinations d ON d.id = s.destination_id
                LEFT JOIN files f ON f.id = s.file_id LEFT JOIN families fam ON fam.id = f.family_id
                WHERE s.id = ?
                """, arguments: [sendID]) else { return nil }
            let fileID: Int64? = send[1]
            let familyID: Int64? = send[15]
            let key: String = send[8]
            let url: String? = send[4]

            // The family, each file labelled with how it relates to the picked one.
            var family: [FamilyFile] = []
            if let familyID, let fileID {
                var relations: [Int64: Relation] = [:]
                for row in try Row.fetchAll(db, sql: """
                    SELECT file_a_id, file_b_id, relation FROM family_links
                    WHERE decided_by = 'auto' AND (file_a_id = ? OR file_b_id = ?)
                    """, arguments: [fileID, fileID]) {
                    let other: Int64 = row[0] == fileID ? row[1] : row[0]
                    relations[other] = Relation(rawValue: row[2])
                }
                family = try Row.fetchAll(db, sql: """
                    SELECT id, name, COALESCE(doc_modified_at, modified_at), version_number, is_variant, export_of_id
                    FROM files WHERE family_id = ? AND id != ? AND path IS NOT NULL
                    """, arguments: [familyID, fileID]).map { row in
                    // Grouped through a third file: no direct link, so the order is unclear.
                    FamilyFile(id: row[0], name: row[1], editedAt: row[2], versionNumber: row[3], isVariant: row[4],
                               exportOfID: row[5], relationToPicked: relations[row[0]] ?? .unclear)
                }
            }

            let pastSends = try Row.fetchAll(db, sql: """
                SELECT s.id, s.file_id, s.file_name_at_send, s.sha256, f.family_id, d.key, s.sent_at
                FROM sends s JOIN destinations d ON d.id = s.destination_id LEFT JOIN files f ON f.id = s.file_id
                WHERE s.is_hidden = 0 AND s.id != ?
                """, arguments: [sendID]).map {
                PastSend(sendID: $0[0], fileID: $0[1], fileName: $0[2], sha256: $0[3], familyID: $0[4], destinationKey: $0[5], sentAt: $0[6])
            }

            // PRD 8.4 step 1: every destination label, plus names the user added.
            var known: [String: Int64] = [:]
            for row in try Row.fetchAll(db, sql: "SELECT label, id FROM destinations") { known[row[0]] = row[1] }
            let extra = try String.fetchOne(db, sql: "SELECT value FROM settings WHERE key = 'known_organisations'") ?? ""
            for name in extra.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) where !name.isEmpty {
                known[name] = known[name] ?? 0
            }

            let recent = try Row.fetchAll(db, sql: """
                SELECT rule, family_id, created_at FROM warnings WHERE shown_as_card = 1 AND created_at >= ?
                """, arguments: [now.addingTimeInterval(-3600)]).compactMap { row -> ShownCard? in
                WarningRule(rawValue: row[0]).map { ShownCard(rule: $0, familyID: row[1], at: row[2]) }
            }
            let sensitivity = try String.fetchOne(db, sql: "SELECT value FROM settings WHERE key = 'sensitivity'")
                .flatMap(Sensitivity.init(rawValue:)) ?? .balanced
            let host = url.flatMap { URL(string: $0)?.host() } ?? ""
            let disabled = (try String.fetchOne(db, sql: "SELECT value FROM settings WHERE key = 'rules_off'") ?? "")
                .split(separator: ",").compactMap { WarningRule(rawValue: String($0)) }
            let identified = !Self.serviceDestinations.contains(key) && !key.hasPrefix("app:") && !DestinationResolver.isUnknown(key: key)
                && (send[6] as String) != Confidence.low.rawValue

            return WarningInput(sendID: sendID, fileID: fileID, fileName: send[2], sha256: send[3],
                                editedAt: send[13] ?? send[14], familyID: familyID, versionNumber: send[16],
                                isVariant: send[17] ?? false, exportOfID: send[18], family: family,
                                destinationID: send[7], destinationKey: key, destinationLabel: send[9],
                                destinationText: "\(host) \(send[5] as String? ?? "")", destinationIdentified: identified,
                                pastSends: pastSends, knownOrganisations: known, sensitivity: sensitivity,
                                familyMuted: send[19] ?? false, destinationMuted: send[10], recentCards: recent, now: now,
                                askForLabel: DestinationResolver.isUnknown(key: key) && (send[11] as String) != "user" && !(send[12] as Bool),
                                disabledRules: Set(disabled))
        }
    }

    /// Saves every rule that fired (FR-23). Returns the id of the one shown as a card, if any.
    @discardableResult
    public func record(_ result: WarningResult, forSend sendID: Int64, familyID: Int64?, fileID: Int64?,
                       sensitivity: Sensitivity, at date: Date = Date()) throws -> Int64? {
        try db.write { db in
            var cardID: Int64?
            for warning in result.fired {
                let isCard = warning == result.card
                let detail = result.detail(for: warning)
                try db.execute(sql: """
                    INSERT INTO warnings (send_id, rule, shown_as_card, outcome, created_at, family_id, file_id,
                                          other_file_id, other_send_id, token, detail)
                    VALUES (?, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?)
                    """, arguments: [sendID, warning.rule.rawValue, isCard, date, familyID, fileID,
                                     warning.otherFile?.id, warning.previousSend?.sendID, warning.token, detail])
                if isCard { cardID = db.lastInsertedRowID }
            }
            return cardID
        }
    }

    /// What happened after a warning (FR-27): fixed (a save), sent_anyway, muted or dismissed.
    public func setOutcome(warning id: Int64, _ outcome: String, detail: String) throws {
        try db.write {
            try $0.execute(sql: "UPDATE warnings SET outcome = ?, detail = ? WHERE id = ?", arguments: [outcome, detail, id])
        }
    }

    /// "Don't warn for this document" / "…destination" (FR-25). Undone in Settings (M5).
    public func muteFamily(_ id: Int64, _ muted: Bool = true) throws {
        try db.write { try $0.execute(sql: "UPDATE families SET muted = ? WHERE id = ?", arguments: [muted, id]) }
    }

    public func muteDestination(_ id: Int64, _ muted: Bool = true) throws {
        try db.write { try $0.execute(sql: "UPDATE destinations SET muted = ? WHERE id = ?", arguments: [muted, id]) }
    }

    /// FR-37: this destination has been asked about; don't ask again, whatever the answer.
    public func markLabelAsked(destination id: Int64) throws {
        try db.write { try $0.execute(sql: "UPDATE destinations SET label_asked = 1 WHERE id = ?", arguments: [id]) }
    }

    /// The family and file of a send, for save detection.
    public func familyAndFile(ofSend id: Int64) throws -> (family: Int64?, file: Int64?, name: String)? {
        try db.read { db in
            try Row.fetchOne(db, sql: """
                SELECT f.family_id, s.file_id, s.file_name_at_send FROM sends s LEFT JOIN files f ON f.id = s.file_id WHERE s.id = ?
                """, arguments: [id]).map { ($0[0], $0[1], $0[2]) }
        }
    }
}
