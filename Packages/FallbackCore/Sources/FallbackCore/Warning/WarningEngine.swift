import Foundation

/// The five rules of PRD 8.1, plus the softer "Another version exists" check from 8.3.
public enum WarningRule: String, Sendable, Codable, CaseIterable {
    case w1 = "W1", w2 = "W2", w3 = "W3", w4 = "W4", w5 = "W5", softer = "S"
    /// FR-37: "Recorded, destination unknown". Neutral, not a warning, and never above one.
    case unknownDestination = "U"

    /// PRD 8.2 precedence: W4, then W1 (or its softer form), then W5, then W3, then W2.
    var precedence: Int {
        switch self {
        case .w4: 0
        case .w1, .softer: 1
        case .w5: 2
        case .w3: 3
        case .w2: 4
        case .unknownDestination: 9
        }
    }

    /// Warning (Burnt Tangerine) or info (Frosted Blue).
    public var isWarning: Bool { [.w1, .w4, .w5].contains(self) }
}

/// PRD 8.2 sensitivity: which rules may show as a card. The others go to the Ledger only.
public enum Sensitivity: String, Sendable, CaseIterable {
    case strict, balanced, quiet

    public func showsCard(_ rule: WarningRule) -> Bool {
        switch self {
        case .strict: true
        case .balanced: [.w1, .w4, .w5, .softer, .unknownDestination].contains(rule)
        case .quiet: [.w1, .w4].contains(rule)
        }
    }
}

/// A file in the picked file's family, as the rules need it.
public struct FamilyFile: Sendable, Equatable {
    public var id: Int64
    public var name: String
    public var editedAt: Date?
    public var versionNumber: Int?
    public var isVariant: Bool
    public var exportOfID: Int64?
    /// How this file relates to the picked one (from the family links): version, variant, export or unclear.
    public var relationToPicked: Relation?

    public init(id: Int64, name: String, editedAt: Date?, versionNumber: Int? = nil, isVariant: Bool = false,
                exportOfID: Int64? = nil, relationToPicked: Relation? = nil) {
        self.id = id; self.name = name; self.editedAt = editedAt; self.versionNumber = versionNumber
        self.isVariant = isVariant; self.exportOfID = exportOfID; self.relationToPicked = relationToPicked
    }

    public var ext: String { (name as NSString).pathExtension.lowercased() }
}

/// An earlier send, for W2 and W3.
public struct PastSend: Sendable, Equatable {
    public var sendID: Int64
    public var fileID: Int64?
    public var fileName: String
    public var sha256: String?
    public var familyID: Int64?
    public var destinationKey: String
    public var sentAt: Date

    public init(sendID: Int64, fileID: Int64?, fileName: String, sha256: String?, familyID: Int64?, destinationKey: String, sentAt: Date) {
        self.sendID = sendID; self.fileID = fileID; self.fileName = fileName; self.sha256 = sha256
        self.familyID = familyID; self.destinationKey = destinationKey; self.sentAt = sentAt
    }
}

/// A card shown earlier, for the 10-minute cool-down.
public struct ShownCard: Sendable, Equatable {
    public var rule: WarningRule
    public var familyID: Int64?
    public var at: Date
    public init(rule: WarningRule, familyID: Int64?, at: Date) { self.rule = rule; self.familyID = familyID; self.at = at }
}

/// Everything known about one pick, gathered by the app from the ledger.
public struct WarningInput: Sendable {
    public var sendID: Int64
    public var fileID: Int64?
    public var fileName: String
    public var sha256: String?
    public var editedAt: Date?
    public var familyID: Int64?
    public var versionNumber: Int?
    public var isVariant: Bool
    public var exportOfID: Int64?
    /// The other files in the family (not the picked one).
    public var family: [FamilyFile]

    public var destinationID: Int64
    public var destinationKey: String
    public var destinationLabel: String
    /// The destination's domain and page title, for W4 ("part of the current destination").
    public var destinationText: String
    /// False when Fallback couldn't tell who the file is going to (a mail service, a chat app,
    /// a destination it couldn't name): W4 never guesses (PRD 8.4 step 4).
    public var destinationIdentified: Bool

    public var pastSends: [PastSend]
    /// Destination labels in the ledger plus names the user added (PRD 8.4 step 1), with their destination ids.
    public var knownOrganisations: [String: Int64]
    public var sensitivity: Sensitivity
    public var familyMuted: Bool
    public var destinationMuted: Bool
    public var recentCards: [ShownCard]
    public var now: Date
    /// FR-37: the destination couldn't be resolved, has no user label, and hasn't been asked about before.
    public var askForLabel: Bool = false
    /// Rules turned off in Settings › Warnings (FR-32). The softer check follows W1.
    public var disabledRules: Set<WarningRule> = []
    /// P-2: words of the user's own name (from macOS), never taken for a company.
    public var ownNames: Set<String> = []
    /// P-2: words the user said aren't company names ("Not a company name" on a card).
    public var notOrganisations: Set<String> = []

    public init(sendID: Int64, fileID: Int64?, fileName: String, sha256: String?, editedAt: Date?, familyID: Int64?,
                versionNumber: Int?, isVariant: Bool, exportOfID: Int64?, family: [FamilyFile],
                destinationID: Int64, destinationKey: String, destinationLabel: String, destinationText: String,
                destinationIdentified: Bool, pastSends: [PastSend], knownOrganisations: [String: Int64],
                sensitivity: Sensitivity = .balanced, familyMuted: Bool = false, destinationMuted: Bool = false,
                recentCards: [ShownCard] = [], now: Date = Date(), askForLabel: Bool = false, disabledRules: Set<WarningRule> = [],
                ownNames: Set<String> = [], notOrganisations: Set<String> = []) {
        self.sendID = sendID; self.fileID = fileID; self.fileName = fileName; self.sha256 = sha256; self.editedAt = editedAt
        self.familyID = familyID; self.versionNumber = versionNumber; self.isVariant = isVariant; self.exportOfID = exportOfID
        self.family = family; self.destinationID = destinationID; self.destinationKey = destinationKey
        self.destinationLabel = destinationLabel; self.destinationText = destinationText
        self.destinationIdentified = destinationIdentified; self.pastSends = pastSends
        self.knownOrganisations = knownOrganisations; self.sensitivity = sensitivity; self.familyMuted = familyMuted
        self.destinationMuted = destinationMuted; self.recentCards = recentCards; self.now = now
        self.askForLabel = askForLabel
        self.disabledRules = disabledRules
        self.ownNames = ownNames; self.notOrganisations = notOrganisations
    }
}

/// One rule that fired, with what the card needs to say (Design/COPY.md).
public struct Warning: Sendable, Equatable {
    public var rule: WarningRule
    /// The other file involved: the newer version (W1), the source (W5), the previous file (W3),
    /// the other version (softer check).
    public var otherFile: FamilyFile?
    /// The earlier send involved (W2, W3).
    public var previousSend: PastSend?
    /// The organisation name found in the file name (W4) and its destination, if any.
    public var token: String?
    public var tokenDestinationID: Int64?
    /// P-2: W4 for a company Fallback has never seen (not yet a destination in the ledger).
    public var unfamiliar: Bool

    public init(rule: WarningRule, otherFile: FamilyFile? = nil, previousSend: PastSend? = nil,
                token: String? = nil, tokenDestinationID: Int64? = nil, unfamiliar: Bool = false) {
        self.rule = rule; self.otherFile = otherFile; self.previousSend = previousSend
        self.token = token; self.tokenDestinationID = tokenDestinationID; self.unfamiliar = unfamiliar
    }
}

/// Why a warning that fired didn't become a card, worded for the Ledger's "What happened" column.
public enum HiddenReason: Sendable, Equatable {
    case sensitivity(Sensitivity)
    case coolDown(minutesAgo: Int)
    case softerWindow
    case mutedDocument
    case mutedDestination

    public var text: String {
        switch self {
        case .sensitivity(let level): "Not shown on \(level.rawValue.capitalized)"
        case .coolDown(let minutes):
            minutes < 1 ? "Already warned about this less than a minute ago"
                : "Already warned about this \(minutes) minute\(minutes == 1 ? "" : "s") ago"
        case .softerWindow: "Not shown: the other version hasn't changed in the last 7 days"
        case .mutedDocument: "Muted for this document"
        case .mutedDestination: "Muted for this destination"
        }
    }

    var isMute: Bool { self == .mutedDocument || self == .mutedDestination }
}

/// What the WarningEngine decided for one pick.
public struct WarningResult: Sendable, Equatable {
    /// Every rule that fired, most important first (PRD 8.2 precedence).
    public var fired: [Warning]
    /// The one to show as a card, if any. The rest appear under "More" and in the Ledger.
    public var card: Warning?
    /// Why each rule that couldn't be a card wasn't one. Rules missing here were eligible
    /// but another one came first.
    public var hidden: [WarningRule: HiddenReason] = [:]

    public init(fired: [Warning], card: Warning?, hidden: [WarningRule: HiddenReason] = [:]) {
        self.fired = fired; self.card = card; self.hidden = hidden
    }

    /// The "{n} more checks" count on the card (FR-24). Muted rules never count.
    public var moreChecks: Int { fired.filter { $0 != card && hidden[$0.rule]?.isMute != true }.count }

    /// The Ledger's "What happened" text for a rule that fired but wasn't the card.
    public func detail(for warning: Warning) -> String? {
        guard warning != card else { return nil }
        if let reason = hidden[warning.rule], reason.isMute { return reason.text }
        if card != nil { return "Under “more”" }
        if warning.rule == .unknownDestination, hidden[warning.rule] == nil { return "Not asked: a warning came first" }
        // No reason and no card: another file picked at the same time got this pick's one card (FR-24).
        return hidden[warning.rule]?.text ?? "Another file in this pick was warned about"
    }
}

/// PRD 8.1 to 8.4: decides which warnings fire for a pick and which one becomes a card.
public enum WarningEngine {
    static let alreadySentWindow: TimeInterval = 90 * 86_400
    static let coolDown: TimeInterval = 10 * 60
    static let softerCardWindow: TimeInterval = 7 * 86_400
    static let tolerance: TimeInterval = 60
    /// PRD 8.4 step 2: words that never count as organisation names.
    static let commonWords: Set<String> = ["resume", "cv", "final", "draft", "proposal", "invoice", "deck", "the", "for",
                                           "and", "copy", "new", "version", "updated", "revised", "latest", "cover", "letter"]
    static let exportSources: Set<String> = ["docx", "doc", "pages", "key", "pptx", "ppt"]

    public static func evaluate(_ input: WarningInput) -> WarningResult {
        // FR-37: asking for a label is never a warning, so muting doesn't hide it.
        let ask = input.askForLabel ? [Warning(rule: .unknownDestination)] : []
        var fired: [Warning] = []
        if let w4 = nameMismatch(input) { fired.append(w4) }
        if let w1 = olderVersion(input) { fired.append(w1) }
        if let w5 = staleExport(input) { fired.append(w5) }
        if let w3 = changedSinceLastSend(input) { fired.append(w3) }
        if let w2 = alreadySent(input) { fired.append(w2) }
        fired.removeAll { input.disabledRules.contains($0.rule) || ($0.rule == .softer && input.disabledRules.contains(.w1)) }
        fired.sort { $0.rule.precedence < $1.rule.precedence }

        // Muting (PRD 8.2): a muted document or destination never gets a warning card. The warnings
        // are still recorded so the Ledger can say why. FR-37's question isn't a warning, so it still shows.
        if let muted: HiddenReason = input.familyMuted ? .mutedDocument : input.destinationMuted ? .mutedDestination : nil {
            var hidden = Dictionary(uniqueKeysWithValues: fired.map { ($0.rule, muted) })
            let card = ask.first.flatMap { input.sensitivity.showsCard($0.rule) ? $0 : nil }
            if card == nil, !ask.isEmpty { hidden[.unknownDestination] = .sensitivity(input.sensitivity) }
            return WarningResult(fired: fired + ask, card: card, hidden: hidden)
        }

        // FR-37: the label question shows only when no warning fired for this pick; otherwise it stays
        // in the Ledger and the warning gets the card.
        if !ask.isEmpty {
            let card = fired.isEmpty && input.sensitivity.showsCard(.unknownDestination) ? ask[0] : nil
            fired.append(contentsOf: ask)
            if card != nil { return WarningResult(fired: fired, card: card) }
        }

        var hidden: [WarningRule: HiddenReason] = [:]
        for warning in fired {
            if let reason = hiddenReason(warning, input) { hidden[warning.rule] = reason }
        }
        let card = fired.first { $0.rule != .unknownDestination && hidden[$0.rule] == nil }
        return WarningResult(fired: fired, card: card, hidden: hidden)
    }

    /// Why this warning can't be a card, or nil if it can.
    static func hiddenReason(_ warning: Warning, _ input: WarningInput) -> HiddenReason? {
        guard input.sensitivity.showsCard(warning.rule) else { return .sensitivity(input.sensitivity) }
        // P-2 trades some precision for catching first applications: Quiet keeps it to the Ledger.
        if warning.unfamiliar, input.sensitivity == .quiet { return .sensitivity(.quiet) }
        // The softer check is a card only if the other file changed in the last 7 days (PRD 8.3).
        if warning.rule == .softer {
            guard let edited = warning.otherFile?.editedAt, input.now.timeIntervalSince(edited) <= softerCardWindow else { return .softerWindow }
        }
        // Cool-down: the same rule for the same document at most once every 10 minutes.
        if let last = input.recentCards.filter({
            $0.rule == warning.rule && $0.familyID == input.familyID && input.now.timeIntervalSince($0.at) < coolDown
        }).map(\.at).max() {
            return .coolDown(minutesAgo: Int(input.now.timeIntervalSince(last) / 60))
        }
        return nil
    }

    // MARK: Saves (FR-27)

    static let saveWindow: TimeInterval = 120

    /// A "save": after a card about a document, a different file from the same document is picked
    /// within 2 minutes. `card` is the card's document, file and time; `pick` is the new pick.
    public static func isSave(card: (familyID: Int64?, fileID: Int64?, at: Date),
                              pick: (familyID: Int64?, fileID: Int64?, at: Date)) -> Bool {
        guard let family = card.familyID, family == pick.familyID, card.fileID != pick.fileID else { return false }
        let elapsed = pick.at.timeIntervalSince(card.at)
        return elapsed >= 0 && elapsed <= saveWindow
    }

    // MARK: W1 Older version (or the softer check)

    /// Another file of the same format in the family is a High-confidence newer version. When the
    /// order is unclear, or the picked file is a tailored variant, only the softer check applies.
    static func olderVersion(_ input: WarningInput) -> Warning? {
        let ext = (input.fileName as NSString).pathExtension.lowercased()
        let sameFormat = input.family.filter { $0.ext == ext && $0.exportOfID == nil }
        if !input.isVariant, let mine = input.versionNumber {
            let newer = sameFormat
                .filter { $0.relationToPicked == .version && !$0.isVariant && ($0.versionNumber ?? 0) > mine }
                .max { ($0.versionNumber ?? 0) < ($1.versionNumber ?? 0) }
            if let newer { return Warning(rule: .w1, otherFile: newer) }
        }
        // Softer: a sibling or unclear relative that changed more recently.
        let mineEdited = input.editedAt ?? .distantPast
        let other = sameFormat
            .filter { [.variant, .unclear].contains($0.relationToPicked) || (input.isVariant && $0.relationToPicked == .version) }
            // Two copies tailored for different organisations aren't rivals: a Razorpay resume isn't an
            // outdated Zinier one. A variant against its own main line (Resume_Razorpay vs Resume) still counts.
            .filter { !tailoredForDifferentOrganisations(input.fileName, $0.name) }
            .filter { ($0.editedAt ?? .distantPast) > mineEdited.addingTimeInterval(tolerance) }
            .max { ($0.editedAt ?? .distantPast) < ($1.editedAt ?? .distantPast) }
        return other.map { Warning(rule: .softer, otherFile: $0) }
    }

    /// Each name carries a word the other lacks (ignoring common words like "final" or "draft") and
    /// they share the rest: Resume_Razorpay and Resume_Zinier, but not Resume and Resume_Razorpay.
    static func tailoredForDifferentOrganisations(_ a: String, _ b: String) -> Bool {
        let wordsA = FamilyEngine.nameWords(a).subtracting(commonWords), wordsB = FamilyEngine.nameWords(b).subtracting(commonWords)
        return !wordsA.subtracting(wordsB).isEmpty && !wordsB.subtracting(wordsA).isEmpty && !wordsA.isDisjoint(with: wordsB)
    }

    // MARK: W2 Already sent

    static func alreadySent(_ input: WarningInput) -> Warning? {
        guard let sha = input.sha256 else { return nil }
        let previous = input.pastSends
            .filter { $0.sendID != input.sendID && $0.sha256 == sha && $0.destinationKey == input.destinationKey }
            .filter { input.now.timeIntervalSince($0.sentAt) <= alreadySentWindow }
            .max { $0.sentAt < $1.sentAt }
        return previous.map { Warning(rule: .w2, previousSend: $0) }
    }

    // MARK: W3 Changed since last send

    static func changedSinceLastSend(_ input: WarningInput) -> Warning? {
        guard let family = input.familyID else { return nil }
        let previous = input.pastSends
            .filter { $0.sendID != input.sendID && $0.familyID == family && $0.destinationKey == input.destinationKey }
            .filter { $0.sha256 != input.sha256 && $0.fileID != input.fileID }
            .max { $0.sentAt < $1.sentAt }
        guard let previous else { return nil }
        let file = input.family.first { $0.id == previous.fileID }
        return Warning(rule: .w3, otherFile: file, previousSend: previous)
    }

    // MARK: W4 Name mismatch (PRD 8.4)

    static func nameMismatch(_ input: WarningInput) -> Warning? {
        guard input.destinationIdentified else { return nil } // step 4: never guess
        let known = Dictionary(input.knownOrganisations.compactMap { name, id in organisationKey(name).map { ($0, (name, id)) } },
                               uniquingKeysWith: { first, _ in first })
        let here = input.destinationText.lowercased() + " " + input.destinationLabel.lowercased()
        for word in nameWords(input.fileName) {
            guard let (name, id) = known[word], !here.contains(word) else { continue }
            return Warning(rule: .w4, token: name, tokenDestinationID: id)
        }
        // P-2 (PRD 16.4): a company Fallback hasn't seen yet, named where tailored documents put it
        // (Resume_Zinier, Cover_Letter_Zamp), going somewhere that clearly isn't that company.
        for (word, shown) in tailoredWords(input.fileName) {
            guard known[word] == nil, !here.contains(word), !input.ownNames.contains(word),
                  !input.notOrganisations.contains(word), !commonWords.contains(word), !Self.dictionary.contains(word) else { continue }
            return Warning(rule: .w4, token: shown, unfamiliar: true)
        }
        return nil
    }

    /// Document words that tailored copies are named around.
    static let documentWords: Set<String> = ["resume", "cv", "cover", "letter", "proposal", "deck", "pitch", "application",
                                             "portfolio", "sow", "quote", "quotation"]

    /// Words right before or after a document word: "Zinier" in Anshuraj_Baruah_Zinier_Resume, "Zamp" in
    /// Cover_Letter_Zamp. CamelCase stays one word (TwinCafe), as a company name would. Lowercased, with how it's written.
    static func tailoredWords(_ fileName: String) -> [(word: String, shown: String)] {
        let base = (fileName as NSString).deletingPathExtension
        let tokens = base.split { !$0.isLetter }.map(String.init)
        var found: [(String, String)] = []
        for (index, token) in tokens.enumerated() where documentWords.contains(token.lowercased()) {
            for neighbour in [index - 1, index + 1] where tokens.indices.contains(neighbour) {
                let shown = tokens[neighbour], word = shown.lowercased()
                guard word.count >= 3, !documentWords.contains(word), !found.contains(where: { $0.0 == word }) else { continue }
                found.append((word, shown))
            }
        }
        return found
    }

    /// macOS's built-in word list (offline). A dictionary word (origin, master) is never taken for an unfamiliar company.
    static let dictionary: Set<String> = {
        guard let text = try? String(contentsOfFile: "/usr/share/dict/words", encoding: .utf8) else { return [] }
        return Set(text.split(separator: "\n").map { $0.lowercased() })
    }()

    /// Step 2: words of the file name, CamelCase split, lowercased, without short or common words.
    static func nameWords(_ fileName: String) -> [String] {
        let base = (fileName as NSString).deletingPathExtension
        let spaced = base.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
        return spaced.lowercased().split { !$0.isLetter }.map(String.init)
            .filter { $0.count >= 3 && !commonWords.contains($0) }
    }

    /// "Acme", "acme.co.in" and "#acme" all mean acme. Multi-word labels and generic ones don't count.
    static func organisationKey(_ label: String) -> String? {
        var text = label.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "#@ "))
        if text.contains(".") { text = String(text.split(separator: ".").first ?? "") }
        guard text.count >= 3, text.allSatisfy(\.isLetter), !commonWords.contains(text) else { return nil }
        return text
    }

    // MARK: W5 Stale export

    /// The picked file is a PDF, and the document it was exported from (or a source file with the
    /// same family stem) was changed after the PDF.
    static func staleExport(_ input: WarningInput) -> Warning? {
        guard (input.fileName as NSString).pathExtension.lowercased() == "pdf", let pdfEdited = input.editedAt else { return nil }
        let pdfStem = NameStem.stem(input.fileName)
        let source = input.family
            .filter { exportSources.contains($0.ext) }
            .filter { $0.id == input.exportOfID || $0.relationToPicked == .export || (pdfStem != nil && NameStem.stem($0.name) == pdfStem) }
            .filter { ($0.editedAt ?? .distantPast) > pdfEdited.addingTimeInterval(tolerance) }
            .max { ($0.editedAt ?? .distantPast) < ($1.editedAt ?? .distantPast) }
        return source.map { Warning(rule: .w5, otherFile: $0) }
    }
}
