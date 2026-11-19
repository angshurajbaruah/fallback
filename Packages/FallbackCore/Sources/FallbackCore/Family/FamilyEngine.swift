import Foundation

/// A destination a file was sent to, used for the sibling-variant rule.
public struct SentTo: Sendable, Hashable {
    public var destinationKey: String
    public var at: Date
    public init(destinationKey: String, at: Date) { self.destinationKey = destinationKey; self.at = at }
}

/// What the FamilyEngine knows about one file. No contents, only metadata and fingerprints.
public struct FileEvidence: Sendable, Identifiable, Equatable {
    public var id: Int64
    public var name: String
    public var sha256: String?
    public var modifiedAt: Date?
    public var createdAt: Date?
    public var docModifiedAt: Date?
    public var whereFrom: String?
    public var downloadedAt: Date?
    public var docTitle: String?
    public var docAuthor: String?
    public var docCreatedAt: Date?
    public var docInternalID: String?
    public var textSignature: [UInt64]?
    public var imageHash: UInt64?
    public var imageColor: UInt32?
    public var sends: [SentTo]

    public init(id: Int64, name: String, sha256: String? = nil, modifiedAt: Date? = nil, createdAt: Date? = nil,
                docModifiedAt: Date? = nil, whereFrom: String? = nil, downloadedAt: Date? = nil,
                docTitle: String? = nil, docAuthor: String? = nil, docCreatedAt: Date? = nil, docInternalID: String? = nil,
                textSignature: [UInt64]? = nil, imageHash: UInt64? = nil, imageColor: UInt32? = nil, sends: [SentTo] = []) {
        self.id = id; self.name = name; self.sha256 = sha256; self.modifiedAt = modifiedAt; self.createdAt = createdAt
        self.docModifiedAt = docModifiedAt; self.whereFrom = whereFrom; self.downloadedAt = downloadedAt
        self.docTitle = docTitle; self.docAuthor = docAuthor; self.docCreatedAt = docCreatedAt
        self.docInternalID = docInternalID; self.textSignature = textSignature; self.imageHash = imageHash
        self.imageColor = imageColor; self.sends = sends
    }

    public var ext: String { (name as NSString).pathExtension.lowercased() }
    public var stem: String? { NameStem.stem(name) }
    /// PRD 8.3 "Which is newer": the document's internal modified date, else the file's.
    public var effectiveDate: Date? { docModifiedAt ?? modifiedAt }
}

public enum LinkConfidence: Int, Sendable, Comparable, Codable {
    case low, medium, high
    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
    public var name: String { ["low", "medium", "high"][rawValue] }
}

public enum LinkSignal: String, Sendable, Codable, CaseIterable { case lineage, metadata, content, name, user }

public enum Relation: String, Sendable, Codable { case version, variant, export, unclear }

/// One pairwise link between two files, with the evidence behind it.
public struct FamilyLink: Sendable, Equatable {
    public var a: Int64
    public var b: Int64
    public var signals: [LinkSignal]
    public var confidence: LinkConfidence
    public var similarity: Double?
    public var relation: Relation
    /// Short evidence labels for the UI: "88% same text", "same source", "same title + date".
    public var reasons: [String]
}

/// The user's word, which always wins (layer 5).
public enum UserDecision: Sendable, Equatable {
    case same(Int64, Int64)
    case separate(Int64, Int64)
    /// "Not now" on a suggestion: don't suggest this pair again.
    case dismissed(Int64, Int64)
}

/// One document family as the Ledger shows it.
public struct FamilyGroup: Sendable, Equatable {
    /// Every member, oldest to newest.
    public var members: [Int64]
    public var name: String
    /// Version number per non-variant member, counted separately for each format (PDFs among PDFs,
    /// Word files among Word files): v1 is the oldest. An exported PDF is never a "newer version" of its source.
    public var versions: [Int64: Int]
    /// Export pairs (PRD 8.3): exported PDF → the document it came from. Used by W5 only.
    public var exportOf: [Int64: Int64]
    public var variants: Set<Int64>
    public var confidence: LinkConfidence
    public var signals: Set<LinkSignal>
    /// The newest version in the family's main format (the format most of its versions are in).
    public var newest: Int64? { members.last { versions[$0] != nil && formats[$0] == mainFormat } }
    /// Each member's file extension, and the family's main one.
    public var formats: [Int64: String]
    public var mainFormat: String?
}

public struct FamilyResult: Sendable {
    public var groups: [FamilyGroup]
    public var links: [FamilyLink]
    /// Medium-confidence clusters across families: "These 3 files look like the same document. Group them?"
    public var suggestions: [[Int64]]
}

/// PRD 8.3: groups files into document families from lineage, metadata, content, name and the user.
public enum FamilyEngine {
    static let exportSources: Set<String> = ["docx", "doc", "pages", "key", "pptx", "ppt"]
    static let genericTitles: Set<String> = ["untitled", "document", "presentation", "microsoft word", "untitled document"]
    static let thirtyDays: TimeInterval = 30 * 86_400
    static let tolerance: TimeInterval = 60

    public static func build(files: [FileEvidence], decisions: [UserDecision] = [], knownOrganisations: Set<String> = []) -> FamilyResult {
        let byID = Dictionary(uniqueKeysWithValues: files.map { ($0.id, $0) })
        var separate = Set<Pair>(), same: [Pair] = [], dismissed = Set<Pair>()
        for decision in decisions {
            switch decision {
            case .same(let a, let b): same.append(Pair(a, b))
            case .separate(let a, let b): separate.insert(Pair(a, b))
            case .dismissed(let a, let b): dismissed.insert(Pair(a, b))
            }
        }
        let orgs = Set(knownOrganisations.map { $0.lowercased() })
        let links = candidatePairs(files).compactMap { pair -> FamilyLink? in
            guard !separate.contains(pair), let a = byID[pair.a], let b = byID[pair.b] else { return nil }
            return compare(a, b, knownOrganisations: orgs)
        }

        var families = UnionFind(files.map(\.id))
        for link in links where link.confidence == .high { families.union(link.a, link.b) }
        for pair in same where byID[pair.a] != nil && byID[pair.b] != nil { families.union(pair.a, pair.b) }

        let groups = families.components().map { ids in
            describe(ids.compactMap { byID[$0] }, links: links.filter { ids.contains($0.a) && ids.contains($0.b) })
        }
        .sorted { $0.name < $1.name }

        // Suggestions: Medium links joining different families, never ones the user dismissed.
        var suggest = UnionFind(files.map(\.id))
        var suggested = Set<Int64>()
        for link in links where link.confidence == .medium && families.find(link.a) != families.find(link.b) {
            guard !dismissed.contains(Pair(link.a, link.b)) else { continue }
            suggest.union(families.find(link.a), families.find(link.b))
            suggested.formUnion([families.find(link.a), families.find(link.b)])
        }
        let suggestions = suggest.components()
            .filter { $0.count > 1 && $0.allSatisfy(suggested.contains) }
            .map { roots in files.map(\.id).filter { roots.contains(families.find($0)) } }
        // A tailored variant is never "older" or "newer" than the main line (PRD 8.3): links between
        // a variant and a version are labelled .variant, matching the family view, so W1 can't fire.
        let variantIDs = Set(groups.flatMap(\.variants))
        let mainLine = Set(groups.flatMap { $0.versions.keys })
        let labelled = links.map { link -> FamilyLink in
            var link = link
            let oneEachSide = (variantIDs.contains(link.a) && mainLine.contains(link.b))
                || (variantIDs.contains(link.b) && mainLine.contains(link.a))
            if oneEachSide, link.relation == .version || link.relation == .unclear { link.relation = .variant }
            return link
        }
        return FamilyResult(groups: groups, links: labelled, suggestions: suggestions)
    }

    // MARK: Pairwise evidence

    public static func compare(_ a: FileEvidence, _ b: FileEvidence, knownOrganisations: Set<String> = []) -> FamilyLink? {
        var found: [(LinkSignal, LinkConfidence, String)] = []
        var similarity: Double?

        // 1. Lineage
        if let sha = a.sha256, sha == b.sha256 { found.append((.lineage, .high, "same file")) }
        if let source = a.whereFrom, source == b.whereFrom { found.append((.lineage, .high, "same source")) }
        // 2. Document metadata
        if let id = a.docInternalID, id == b.docInternalID {
            found.append((.metadata, .high, "same document ID"))
        } else if let title = a.docTitle?.lowercased(), title.count >= 4, !genericTitles.contains(title), title == b.docTitle?.lowercased() {
            if let ca = a.docCreatedAt, let cb = b.docCreatedAt, Calendar.current.isDate(ca, inSameDayAs: cb) {
                found.append((.metadata, .medium, "same title + date"))
            } else if let author = a.docAuthor, author == b.docAuthor {
                found.append((.metadata, .medium, "same title + author"))
            }
        }
        // 3. Content
        if let ta = a.textSignature, let tb = b.textSignature {
            let score = TextSignature.similarity(ta, tb)
            if score >= 0.5 {
                similarity = score
                found.append((.content, score >= 0.75 ? .high : .medium, "\(Int((score * 100).rounded()))% same text"))
            }
        }
        if let ia = a.imageHash, let ib = b.imageHash {
            let distance = ImageSignature.distance(ia, ib)
            let sameColours = a.imageColor.flatMap { ca in b.imageColor.map { ImageSignature.colorDistance(ca, $0) <= 60 } } ?? true
            if distance <= 10, sameColours { found.append((.content, distance <= 6 ? .high : .medium, "near-identical image")) }
        }
        // 4. Name stem: Medium alone, High with any other signal
        if let stem = a.stem, stem == b.stem { found.append((.name, .medium, "similar name")) }

        guard !found.isEmpty else { return nil }
        var confidence = found.map(\.1).max()!
        if found.contains(where: { $0.0 == .name }) && found.contains(where: { $0.0 != .name }) { confidence = .high }
        let signals = LinkSignal.allCases.filter { signal in found.contains { $0.0 == signal } }
        return FamilyLink(a: min(a.id, b.id), b: max(a.id, b.id), signals: signals, confidence: confidence,
                          similarity: similarity, relation: relation(a, b, confidence: confidence, knownOrganisations: knownOrganisations),
                          reasons: found.map(\.2))
    }

    /// PRD 8.3 "Version or sibling variant?"
    public static func relation(_ a: FileEvidence, _ b: FileEvidence, confidence: LinkConfidence,
                                knownOrganisations: Set<String> = []) -> Relation {
        let exts = [a.ext, b.ext]
        if exts.contains("pdf") && exts.contains(where: exportSources.contains) { return .export }
        if isVariant(a, b, knownOrganisations: knownOrganisations) { return .variant }
        if confidence == .high, newer(a, b) != nil { return .version }
        return .unclear
    }

    static func isVariant(_ a: FileEvidence, _ b: FileEvidence, knownOrganisations: Set<String>) -> Bool {
        // Names carry different organisation names: Resume_Razorpay vs Resume_Emergent.
        let wordsA = Set(NameStem.tokens(a.name).filter(isNameWord)), wordsB = Set(NameStem.tokens(b.name).filter(isNameWord))
        let onlyA = wordsA.subtracting(wordsB), onlyB = wordsB.subtracting(wordsA)
        if !onlyA.isEmpty && !onlyB.isEmpty && !wordsA.isDisjoint(with: wordsB) { return true }
        if !onlyA.union(onlyB).isDisjoint(with: knownOrganisations) { return true }
        // Went to different destinations within 30 days. Only for pairs without a clear order: sending the
        // older file somewhere new is exactly the mistake W1 catches, so it never makes two versions siblings.
        for sa in a.sends where newer(a, b) == nil {
            if b.sends.contains(where: { $0.destinationKey != sa.destinationKey && abs($0.at.timeIntervalSince(sa.at)) <= thirtyDays }) {
                return true
            }
        }
        // Both keep getting edited: each was changed after the other appeared.
        if let ma = a.modifiedAt, let mb = b.modifiedAt, let ca = a.createdAt, let cb = b.createdAt,
           ma > cb.addingTimeInterval(tolerance), mb > ca.addingTimeInterval(tolerance) { return true }
        return false
    }

    private static func isNameWord(_ word: String) -> Bool {
        word.count >= 3 && word.allSatisfy(\.isLetter) && !NameStem.filler.contains(word) && !NameStem.generic.contains(word)
    }

    /// The newer of the two when the order is clear, else nil. Dates decide; an explicit version number
    /// in the names (v3 < v5) breaks a tie only when the dates are equal.
    public static func newer(_ a: FileEvidence, _ b: FileEvidence) -> Int64? {
        // Downloads from the same source: download order.
        if let source = a.whereFrom, source == b.whereFrom, let da = a.downloadedAt, let db = b.downloadedAt, da != db {
            return da > db ? a.id : b.id
        }
        guard let da = a.effectiveDate, let db = b.effectiveDate else { return nil }
        let (new, old): (FileEvidence, FileEvidence)
        if abs(da.timeIntervalSince(db)) < 1 {
            guard let va = NameStem.versionNumber(a.name), let vb = NameStem.versionNumber(b.name), va != vb else { return nil }
            (new, old) = va > vb ? (a, b) : (b, a)
        } else {
            (new, old) = da > db ? (a, b) : (b, a)
        }
        // "A hasn't been changed since B appeared."
        if let changed = old.modifiedAt, let appeared = new.createdAt ?? new.modifiedAt,
           changed > appeared.addingTimeInterval(tolerance) { return nil }
        return new.id
    }

    /// Oldest to newest for display: date, then version number in the name, then name.
    public static func ordered(_ files: [FileEvidence]) -> [FileEvidence] {
        files.sorted { a, b in
            let da = a.downloadedAt ?? a.effectiveDate ?? .distantPast, db = b.downloadedAt ?? b.effectiveDate ?? .distantPast
            if abs(da.timeIntervalSince(db)) >= 1 { return da < db }
            let va = NameStem.versionNumber(a.name) ?? -1, vb = NameStem.versionNumber(b.name) ?? -1
            if va != vb { return va < vb }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    // MARK: Families

    static func describe(_ files: [FileEvidence], links: [FamilyLink]) -> FamilyGroup {
        let stems = files.compactMap(\.stem)
        let counts = Dictionary(stems.map { ($0, 1) }, uniquingKeysWith: +)
        let base = counts.max { $0.value == $1.value ? $0.key.count > $1.key.count : $0.value < $1.value }?.key
        let baseWords = Set(base.map { NameStem.tokens($0) } ?? [])
        // Tailored copies: same base name plus extra words (Resume_Razorpay against Resume).
        let variants = Set(files.filter { file in
            guard let stem = file.stem, stem != base, !baseWords.isEmpty else { return false }
            let words = Set(NameStem.tokens(stem))
            return words.isSuperset(of: baseWords) && words.subtracting(baseWords).contains(where: isNameWord)
        }.map(\.id))
        let ordered = ordered(files)
        // Versions are numbered within each format, so an export pair (Proposal.docx + Proposal.pdf)
        // is two v1s, not "v1 and its newer v2" (PRD 8.3: exports are never newer or older versions).
        var versions: [Int64: Int] = [:]
        let lines = Dictionary(grouping: ordered.filter { !variants.contains($0.id) }, by: \.ext)
        for line in lines.values { for (index, file) in line.enumerated() { versions[file.id] = index + 1 } }
        // The format with the most versions; on a tie, the source rather than the PDF made from it.
        let mainFormat = lines.max { a, b in
            (a.value.count, a.key == "pdf" ? 0 : 1, b.key) < (b.value.count, b.key == "pdf" ? 0 : 1, a.key)
        }?.key
        var exportOf: [Int64: Int64] = [:]
        let byID = Dictionary(uniqueKeysWithValues: files.map { ($0.id, $0) })
        for link in links where link.relation == .export {
            guard let a = byID[link.a], let b = byID[link.b] else { continue }
            if a.ext == "pdf" { exportOf[a.id] = b.id } else { exportOf[b.id] = a.id }
        }
        let name = base.map(titleCased) ?? files.first.map { ($0.name as NSString).deletingPathExtension } ?? "Document"
        return FamilyGroup(members: ordered.map(\.id), name: name, versions: versions, exportOf: exportOf, variants: variants,
                           confidence: links.map(\.confidence).max() ?? (files.count > 1 ? .high : .low),
                           signals: Set(links.filter { $0.confidence == .high }.flatMap(\.signals)),
                           formats: Dictionary(uniqueKeysWithValues: files.map { ($0.id, $0.ext) }), mainFormat: mainFormat)
    }

    static func titleCased(_ stem: String) -> String {
        stem.split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }

    // MARK: Bucketing (PRD 8.3 "Speed"): only likely matches are compared

    static func candidatePairs(_ files: [FileEvidence]) -> [Pair] {
        var buckets: [String: [Int64]] = [:]
        for file in files {
            var keys: [String] = []
            if let sha = file.sha256 { keys.append("sha:\(sha)") }
            if let source = file.whereFrom { keys.append("from:\(source)") }
            if let id = file.docInternalID { keys.append("id:\(id)") }
            if let title = file.docTitle?.lowercased(), title.count >= 4 { keys.append("title:\(title)") }
            if let stem = file.stem { keys.append("stem:\(stem)") }
            if let signature = file.textSignature {
                // 32 bands of 2 rows: pairs sharing 50% of word groups almost always meet in some band.
                for band in 0..<32 { keys.append("lsh:\(band):\(signature[band * 2]):\(signature[band * 2 + 1])") }
            }
            if let hash = file.imageHash {
                for band in 0..<8 { keys.append("img:\(band):\((hash >> (band * 8)) & 0xFF)") }
            }
            for key in keys { buckets[key, default: []].append(file.id) }
        }
        var pairs = Set<Pair>()
        for ids in buckets.values where ids.count > 1 {
            let capped = ids.prefix(300) // a huge bucket means a too-common key; don't compare everything
            for i in capped.indices { for j in capped.indices where j > i { pairs.insert(Pair(capped[i], capped[j])) } }
        }
        return pairs.sorted { ($0.a, $0.b) < ($1.a, $1.b) }
    }

    struct Pair: Hashable {
        let a: Int64, b: Int64
        init(_ x: Int64, _ y: Int64) { a = min(x, y); b = max(x, y) }
    }

    struct UnionFind {
        private var parent: [Int64: Int64]
        init(_ ids: [Int64]) { parent = Dictionary(uniqueKeysWithValues: ids.map { ($0, $0) }) }

        mutating func find(_ id: Int64) -> Int64 {
            var root = id
            while let next = parent[root], next != root { root = next }
            var node = id
            while let next = parent[node], next != root { parent[node] = root; node = next }
            return root
        }

        mutating func union(_ a: Int64, _ b: Int64) {
            let ra = find(a), rb = find(b)
            if ra != rb { parent[max(ra, rb)] = min(ra, rb) }
        }

        mutating func components() -> [[Int64]] {
            var groups: [Int64: [Int64]] = [:]
            for id in parent.keys.sorted() { groups[find(id), default: []].append(id) }
            return groups.keys.sorted().map { groups[$0]! }
        }
    }
}
