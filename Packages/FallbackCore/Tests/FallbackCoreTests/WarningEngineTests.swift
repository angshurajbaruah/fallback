import Foundation
import Testing
@testable import FallbackCore

/// PRD 8.1 to 8.4, using the files in ~/FallbackTest (README dates: v3 5 Nov … v5 18 Nov).
struct WarningEngineTests {
    let now = Date(timeIntervalSince1970: 1_795_000_000)
    let day: TimeInterval = 86_400

    func date(_ daysAgo: Double) -> Date { now - daysAgo * day }

    /// The Resume family as Fallback stores it, seen from the picked file.
    func resumeFamily(picked: String) -> [FamilyFile] {
        let all = [
            FamilyFile(id: 1, name: "resume_v3.pdf", editedAt: date(13), versionNumber: 1),
            FamilyFile(id: 2, name: "final.pdf", editedAt: date(8), versionNumber: 2),
            FamilyFile(id: 3, name: "resume_v5.pdf", editedAt: date(0.5), versionNumber: 5),
            FamilyFile(id: 4, name: "Resume_Razorpay.pdf", editedAt: date(2), isVariant: true),
            FamilyFile(id: 5, name: "Resume_Emergent.pdf", editedAt: date(1), isVariant: true),
        ]
        guard let me = all.first(where: { $0.name == picked }) else { return [] }
        return all.filter { $0.id != me.id }.map { other in
            var other = other
            other.relationToPicked = (me.isVariant || other.isVariant) ? .variant : .version
            if other.name == "final.pdf" && me.name == "resume_v3.pdf" { other.relationToPicked = .unclear }
            return other
        }
    }

    func input(_ name: String, sha: String? = nil, edited: Date? = nil, family: Int64? = 10, version: Int? = nil,
               variant: Bool = false, exportOf: Int64? = nil, members: [FamilyFile]? = nil,
               to destination: (key: String, label: String, text: String) = ("lever:northwind", "Northwind", "jobs.lever.co Apply Product Manager"),
               identified: Bool = true, past: [PastSend] = [], known: [String: Int64] = [:],
               sensitivity: Sensitivity = .balanced, familyMuted: Bool = false, destinationMuted: Bool = false,
               recent: [ShownCard] = []) -> WarningInput {
        let members = members ?? resumeFamily(picked: name)
        let mine = [
            "resume_v3.pdf": (1, 13.0, 1), "final.pdf": (2, 8, 2), "resume_v5.pdf": (3, 0.5, 5),
            "Resume_Razorpay.pdf": (4, 2, 0), "Resume_Emergent.pdf": (5, 1, 0),
        ][name]
        return WarningInput(sendID: 100, fileID: mine.map { Int64($0.0) } ?? 50, fileName: name, sha256: sha ?? "sha-\(name)",
                            editedAt: edited ?? mine.map { date($0.1) }, familyID: family,
                            versionNumber: version ?? mine.flatMap { $0.2 == 0 ? nil : $0.2 }, isVariant: variant,
                            exportOfID: exportOf, family: members, destinationID: 7, destinationKey: destination.key,
                            destinationLabel: destination.label, destinationText: destination.text,
                            destinationIdentified: identified, pastSends: past, knownOrganisations: known,
                            sensitivity: sensitivity, familyMuted: familyMuted, destinationMuted: destinationMuted,
                            recentCards: recent, now: now)
    }

    func past(_ name: String, to key: String = "lever:northwind", daysAgo: Double = 3, file: Int64? = nil, family: Int64? = 10) -> PastSend {
        PastSend(sendID: Int64(name.count), fileID: file, fileName: name, sha256: "sha-\(name)", familyID: family,
                 destinationKey: key, sentAt: date(daysAgo))
    }

    // MARK: W1

    @Test func w1_v3PickedWhileV5Exists() {
        let result = WarningEngine.evaluate(input("resume_v3.pdf"))
        #expect(result.card?.rule == .w1)
        #expect(result.card?.otherFile?.name == "resume_v5.pdf") // names the newest, not final.pdf
    }

    @Test func w1_newestPickedIsQuiet() {
        #expect(WarningEngine.evaluate(input("resume_v5.pdf")).fired.isEmpty)
    }

    @Test func w1_neverForATailoredVariant_softerInstead() {
        let result = WarningEngine.evaluate(input("Resume_Razorpay.pdf", variant: true))
        #expect(!result.fired.contains { $0.rule == .w1 })
        #expect(result.card?.rule == .softer)
        #expect(result.card?.otherFile?.name == "resume_v5.pdf") // the most recently changed relative
    }

    @Test func w1_onlyComparesTheSameFormat() {
        let members = [FamilyFile(id: 2, name: "Proposal.docx", editedAt: date(1), versionNumber: 2, relationToPicked: .version)]
        let result = WarningEngine.evaluate(input("Proposal.pdf", edited: date(1), version: 1, members: members))
        #expect(!result.fired.contains { $0.rule == .w1 })
    }

    @Test func softer_isLedgerOnlyWhenTheOtherFileIsOld() {
        let members = [FamilyFile(id: 2, name: "plan b.pdf", editedAt: date(20), relationToPicked: .unclear)]
        let result = WarningEngine.evaluate(input("plan a.pdf", edited: date(30), version: 1, members: members))
        #expect(result.fired.map(\.rule) == [.softer])
        #expect(result.card == nil) // changed more than 7 days ago
    }

    // MARK: W2

    @Test func w2_sameFileSameDestinationTwice() {
        let result = WarningEngine.evaluate(input("resume_v5.pdf", past: [past("resume_v5.pdf", file: 3)], sensitivity: .strict))
        #expect(result.card?.rule == .w2)
    }

    @Test func w2_isLedgerOnlyInBalanced() {
        let result = WarningEngine.evaluate(input("resume_v5.pdf", past: [past("resume_v5.pdf", file: 3)]))
        #expect(result.fired.map(\.rule) == [.w2])
        #expect(result.card == nil)
    }

    @Test func w2_notAfter90Days() {
        let result = WarningEngine.evaluate(input("resume_v5.pdf", past: [past("resume_v5.pdf", daysAgo: 91, file: 3)]))
        #expect(result.fired.isEmpty)
    }

    @Test func w2_notForADifferentDestination() {
        let result = WarningEngine.evaluate(input("resume_v5.pdf", past: [past("resume_v5.pdf", to: "workday:razorpay", file: 3)]))
        #expect(result.fired.isEmpty)
    }

    // MARK: W3

    @Test func w3_v3ThenV5ToTheSamePlace() {
        let result = WarningEngine.evaluate(input("resume_v5.pdf", past: [past("resume_v3.pdf", file: 1)], sensitivity: .strict))
        #expect(result.card?.rule == .w3)
        #expect(result.card?.previousSend?.fileName == "resume_v3.pdf")
    }

    @Test func w3_isLedgerOnlyInBalanced() {
        let result = WarningEngine.evaluate(input("resume_v5.pdf", past: [past("resume_v3.pdf", file: 1)]))
        #expect(result.fired.map(\.rule) == [.w3] && result.card == nil)
    }

    @Test func w3_notForAnotherDocument() {
        let result = WarningEngine.evaluate(input("resume_v5.pdf", past: [past("invoice.pdf", file: 9, family: 99)], sensitivity: .strict))
        #expect(result.fired.isEmpty)
    }

    // MARK: W4 (PRD 8.4)

    let acme = (key: "domain:globex.com", label: "Globex", text: "careers.globex.com Apply")

    func proposalAcme(to destination: (key: String, label: String, text: String), identified: Bool = true,
                      known: [String: Int64] = ["Acme": 3, "Globex": 7]) -> WarningInput {
        input("Proposal_Acme.pdf", edited: date(4), family: 20, version: 1, members: [], to: destination,
              identified: identified, known: known)
    }

    @Test func w4_acmeFileToGlobex() {
        let result = WarningEngine.evaluate(proposalAcme(to: acme))
        #expect(result.card?.rule == .w4)
        #expect(result.card?.token == "Acme" && result.card?.tokenDestinationID == 3)
    }

    @Test func w4_acmeFileToAcmeIsFine() {
        #expect(WarningEngine.evaluate(proposalAcme(to: ("domain:acme.com", "Acme", "acme.com Upload"))).fired.isEmpty)
    }

    @Test func w4_matchesTheDomainOrPageTitleToo() {
        // Label renamed by the user, but the page is still Acme's.
        #expect(WarningEngine.evaluate(proposalAcme(to: ("domain:acme.co.in", "Big client", "careers.acme.co.in"))).fired.isEmpty)
    }

    @Test func w4_unknownOrganisationNeverFires() {
        #expect(WarningEngine.evaluate(proposalAcme(to: acme, known: ["Globex": 7])).fired.isEmpty)
    }

    @Test func w4_neverGuessesAnUnidentifiedDestination() {
        #expect(WarningEngine.evaluate(proposalAcme(to: ("gmail", "Gmail", "mail.google.com"), identified: false)).fired.isEmpty)
    }

    @Test func w4_ignoresShortAndCommonWords() {
        #expect(WarningEngine.nameWords("Final_CV_for_Acme_Proposal.pdf") == ["acme"])
        #expect(WarningEngine.nameWords("AcmeProposal.pdf") == ["acme"]) // CamelCase split
    }

    @Test func w4_normalisesLabels() {
        #expect(WarningEngine.organisationKey("acme.co.in") == "acme")
        #expect(WarningEngine.organisationKey("#globex") == "globex")
        #expect(WarningEngine.organisationKey("Meera Iyer") == nil)
        #expect(WarningEngine.organisationKey("CV") == nil)
    }

    // MARK: W5

    func proposalFamily(docxEdited: Double) -> [FamilyFile] {
        [FamilyFile(id: 8, name: "Proposal_Acme.docx", editedAt: date(docxEdited), versionNumber: 1, relationToPicked: .export)]
    }

    @Test func w5_docxEditedAfterThePdf() {
        let result = WarningEngine.evaluate(input("Proposal_Acme.pdf", edited: date(4), family: 20, version: 1, exportOf: 8,
                                                  members: proposalFamily(docxEdited: 0)))
        #expect(result.card?.rule == .w5)
        #expect(result.card?.otherFile?.name == "Proposal_Acme.docx")
    }

    @Test func w5_quietWhenThePdfIsNewer() {
        let result = WarningEngine.evaluate(input("Proposal_Acme.pdf", edited: date(0), family: 20, version: 1, exportOf: 8,
                                                  members: proposalFamily(docxEdited: 4)))
        #expect(result.fired.isEmpty)
    }

    @Test func w5_onlyForPDFs() {
        let members = [FamilyFile(id: 9, name: "Proposal_Acme.pdf", editedAt: date(0), versionNumber: 1, relationToPicked: .export)]
        let result = WarningEngine.evaluate(input("Proposal_Acme.docx", edited: date(4), family: 20, version: 1, members: members))
        #expect(result.fired.isEmpty)
    }

    // MARK: FR-37 destination unknown

    func unknown(_ name: String, sensitivity: Sensitivity = .balanced, ask: Bool = true, muted: Bool = false) -> WarningInput {
        var value = input(name, to: ("window:com.google.Chrome:upload", "Unlabelled", " Upload"), identified: false,
                          sensitivity: sensitivity, familyMuted: muted)
        value.askForLabel = ask
        return value
    }

    @Test func unknown_asksWhenNothingElseFires() {
        let result = WarningEngine.evaluate(unknown("resume_v5.pdf"))
        #expect(result.card?.rule == .unknownDestination)
        #expect(!WarningRule.unknownDestination.isWarning) // neutral, never Tangerine
    }

    @Test func unknown_neverAboveARealWarning() {
        let result = WarningEngine.evaluate(unknown("resume_v3.pdf"))
        #expect(result.card?.rule == .w1)
        #expect(result.fired.last?.rule == .unknownDestination) // kept for the Ledger
    }

    @Test func unknown_staysInTheLedgerWhenAWarningFiresButIsLedgerOnly() {
        var value = unknown("resume_v5.pdf")
        value.pastSends = [past("resume_v5.pdf", to: "window:com.google.Chrome:upload", file: 3)]
        let result = WarningEngine.evaluate(value) // W2 fires, Ledger-only in Balanced
        #expect(result.fired.map(\.rule) == [.w2, .unknownDestination])
        #expect(result.card == nil)
    }

    @Test func unknown_isLedgerOnlyInQuiet() {
        let result = WarningEngine.evaluate(unknown("resume_v5.pdf", sensitivity: .quiet))
        #expect(result.fired.map(\.rule) == [.unknownDestination] && result.card == nil)
    }

    @Test func unknown_showsInStrict() {
        #expect(WarningEngine.evaluate(unknown("resume_v5.pdf", sensitivity: .strict)).card?.rule == .unknownDestination)
    }

    @Test func unknown_notAskedTwice() {
        #expect(WarningEngine.evaluate(unknown("resume_v5.pdf", ask: false)).fired.isEmpty)
    }

    @Test func unknown_stillAskedForAMutedDocument() {
        // Muting silences warnings; the label question isn't one.
        #expect(WarningEngine.evaluate(unknown("resume_v3.pdf", muted: true)).card?.rule == .unknownDestination)
    }

    // MARK: FR-27 saves

    @Test func save_differentFileSameDocumentWithin2Minutes() {
        #expect(WarningEngine.isSave(card: (10, 1, now), pick: (10, 3, now + 40)))
    }

    @Test func save_notTheSameFileAgain() {
        #expect(!WarningEngine.isSave(card: (10, 1, now), pick: (10, 1, now + 40)))
    }

    @Test func save_notAfter2Minutes() {
        #expect(!WarningEngine.isSave(card: (10, 1, now), pick: (10, 3, now + 121)))
    }

    @Test func save_notAnotherDocument() {
        #expect(!WarningEngine.isSave(card: (10, 1, now), pick: (11, 3, now + 30)))
    }

    // MARK: PRD 8.2 rules about rules

    @Test func precedence_w4BeatsW5_andTheRestGoUnderMore() {
        var both = input("Proposal_Acme.pdf", edited: date(4), family: 20, version: 1, exportOf: 8,
                         members: proposalFamily(docxEdited: 0), to: acme, known: ["Acme": 3])
        both.pastSends = [past("Proposal_Globex.pdf", to: acme.key, file: 11, family: 20)]
        both.sensitivity = .strict
        let result = WarningEngine.evaluate(both)
        #expect(result.fired.map(\.rule) == [.w4, .w5, .w3])
        #expect(result.card?.rule == .w4)
    }

    @Test func quiet_showsOnlyW4AndW1() {
        let quiet = input("Proposal_Acme.pdf", edited: date(4), family: 20, version: 1, exportOf: 8,
                          members: proposalFamily(docxEdited: 0), sensitivity: .quiet)
        let result = WarningEngine.evaluate(quiet)
        #expect(result.fired.map(\.rule) == [.w5] && result.card == nil)
    }

    @Test func mutedDocument_noCard_reasonRecorded() {
        let result = WarningEngine.evaluate(input("resume_v3.pdf", familyMuted: true))
        #expect(result.card == nil)
        #expect(result.detail(for: result.fired[0]) == "Muted for this document")
        #expect(result.moreChecks == 0)
    }

    @Test func mutedDestination_noCard_reasonRecorded() {
        let result = WarningEngine.evaluate(input("resume_v3.pdf", destinationMuted: true))
        #expect(result.card == nil)
        #expect(result.detail(for: result.fired[0]) == "Muted for this destination")
    }

    // MARK: Why no card ("What happened" in Ledger › Warnings)

    @Test func reason_sensitivityNamesTheLevel() {
        let result = WarningEngine.evaluate(input("resume_v5.pdf", past: [past("resume_v5.pdf", file: 3)]))
        #expect(result.detail(for: result.fired[0]) == "Not shown on Balanced")
    }

    @Test func reason_coolDownSaysHowLongAgo_evenInStrict() {
        let recent = [ShownCard(rule: .w1, familyID: 10, at: now - 6 * 60 - 20)]
        let result = WarningEngine.evaluate(input("resume_v3.pdf", sensitivity: .strict, recent: recent))
        #expect(result.card == nil)
        #expect(result.detail(for: result.fired[0]) == "Already warned about this 6 minutes ago")
    }

    @Test func reason_coolDownUnderAMinute() {
        let recent = [ShownCard(rule: .w1, familyID: 10, at: now - 20)]
        let result = WarningEngine.evaluate(input("resume_v3.pdf", recent: recent))
        #expect(result.detail(for: result.fired[0]) == "Already warned about this less than a minute ago")
    }

    @Test func reason_softerCheckOutsideItsSevenDays() {
        let members = [FamilyFile(id: 2, name: "plan b.pdf", editedAt: date(20), relationToPicked: .unclear)]
        let result = WarningEngine.evaluate(input("plan a.pdf", edited: date(30), version: 1, members: members, sensitivity: .strict))
        #expect(result.detail(for: result.fired[0]) == "Not shown: the other version hasn't changed in the last 7 days")
    }

    @Test func reason_othersUnderMoreWhenACardShows() {
        let result = WarningEngine.evaluate(input("Proposal_Acme.pdf", edited: date(4), family: 20, version: 1, exportOf: 8,
                                                  members: proposalFamily(docxEdited: 0), known: ["Acme": 1]))
        let others = result.fired.filter { $0 != result.card }
        #expect(!others.isEmpty && others.allSatisfy { result.detail(for: $0) == "Under “more”" })
    }

    @Test func coolDown_sameRuleSameDocumentWithin10Minutes() {
        let recent = [ShownCard(rule: .w1, familyID: 10, at: now - 5 * 60)]
        let result = WarningEngine.evaluate(input("resume_v3.pdf", recent: recent))
        #expect(result.fired.map(\.rule) == [.w1])
        #expect(result.card == nil) // still recorded for the Ledger
    }

    @Test func coolDown_endsAfter10Minutes() {
        let recent = [ShownCard(rule: .w1, familyID: 10, at: now - 11 * 60)]
        #expect(WarningEngine.evaluate(input("resume_v3.pdf", recent: recent)).card?.rule == .w1)
    }

    @Test func coolDown_otherDocumentsStillWarn() {
        let recent = [ShownCard(rule: .w1, familyID: 99, at: now - 60)]
        #expect(WarningEngine.evaluate(input("resume_v3.pdf", recent: recent)).card?.rule == .w1)
    }
}


/// The whole path through the database: files grouped, a send recorded, its context gathered, W1 decided.
struct WarningStoreTests {
    @Test func olderResumeSentFromTheLedger() throws {
        let store = try Store.inMemory()
        let start = Date(timeIntervalSinceNow: -20 * 86_400)
        func add(_ name: String, daysLater: Double) throws -> Int64 {
            let date = start + daysLater * 86_400
            return try store.upsert(IndexedFile(path: "/t/\(name)", name: name, facts: FileFacts(sha256: name, sizeBytes: 2000, modifiedAt: date),
                                                createdAt: date, textSignature: TextSignature.make(Fixtures.resume)), inWatchedFolder: true)
        }
        _ = try add("resume_v3.pdf", daysLater: 0)
        _ = try add("resume_v5.pdf", daysLater: 13)
        try store.apply(FamilyEngine.build(files: store.evidence()))

        let destination = Destination(key: "lever:northwind", label: "Northwind", source: .rule)
        let sendID = try store.record(NewSend(path: "/t/resume_v3.pdf", fileName: "resume_v3.pdf", appBundleID: "com.google.Chrome",
                                              appName: "Chrome", url: "https://jobs.lever.co/northwind", pageTitle: "Apply",
                                              method: .axPanel),
                                      destination: destination, facts: FileFacts(sha256: "resume_v3.pdf"))
        let input = try #require(try store.warningInput(forSend: sendID))
        let result = WarningEngine.evaluate(input)
        #expect(result.card?.rule == .w1)
        #expect(result.card?.otherFile?.name == "resume_v5.pdf")

        let cardID = try store.record(result, forSend: sendID, familyID: input.familyID, fileID: input.fileID, sensitivity: .balanced)
        try store.setOutcome(warning: #require(cardID), "fixed", detail: "Picked resume_v5.pdf 20 s later")
        #expect(try store.warnings(outcome: "fixed").first?.rule == "W1")
    }

    /// The bug this replaced: a cool-down in Strict was stored as "Ledger only (Strict)".
    @Test func recordStoresTheRealReason() throws {
        let store = try Store.inMemory()
        let sendID = try store.record(NewSend(path: nil, fileName: "resume_v3.pdf", appBundleID: "com.google.Chrome", appName: "Chrome",
                                              url: nil, pageTitle: "Apply", method: .axPanel),
                                      destination: Destination(key: "lever:northwind", label: "Northwind", source: .rule), facts: nil)
        let w1 = Warning(rule: .w1), w2 = Warning(rule: .w2), w3 = Warning(rule: .w3), softer = Warning(rule: .softer)
        let result = WarningResult(fired: [w1, softer, w3, w2], card: nil,
                                   hidden: [.w1: .coolDown(minutesAgo: 6), .softer: .softerWindow, .w3: .sensitivity(.quiet),
                                            .w2: .mutedDestination])
        #expect(try store.record(result, forSend: sendID, familyID: nil, fileID: nil, sensitivity: .strict) == nil)
        let details = Dictionary(uniqueKeysWithValues: try store.warnings().map { ($0.rule, $0.detail ?? "") })
        #expect(details == ["W1": "Already warned about this 6 minutes ago",
                            "S": "Not shown: the other version hasn't changed in the last 7 days",
                            "W3": "Not shown on Quiet", "W2": "Muted for this destination"])
    }

    @Test func mailIsNotAnIdentifiedRecipient() throws {
        let store = try Store.inMemory()
        let sendID = try store.record(NewSend(path: nil, fileName: "Proposal_Acme.pdf", appBundleID: "com.apple.mail", appName: "Mail",
                                              url: nil, pageTitle: "New Message", method: .axPanel),
                                      destination: Destination(key: "app:com.apple.mail", label: "Mail", source: .fallback), facts: nil)
        #expect(try store.warningInput(forSend: sendID)?.destinationIdentified == false)
    }
}


/// FR-37 through the database: asked once per place, never again after a label or a dismissal.
struct UnknownDestinationStoreTests {
    func send(_ store: Store, title: String) throws -> Int64 {
        try store.record(NewSend(path: nil, fileName: "Budget_Q4.xlsx", appBundleID: "org.mozilla.firefox", appName: "Firefox",
                                 url: nil, pageTitle: title, method: .axPanel),
                         destination: Destination(key: "window:org.mozilla.firefox:\(title.lowercased())", label: "Unlabelled", source: .fallback),
                         facts: nil)
    }

    @Test func askedOnceThenNeverAgain() throws {
        let store = try Store.inMemory()
        let first = try send(store, title: "Upload")
        let input = try #require(try store.warningInput(forSend: first))
        #expect(input.askForLabel && !input.destinationIdentified)
        try store.markLabelAsked(destination: input.destinationID) // the card was shown (then dismissed)
        #expect(try store.warningInput(forSend: send(store, title: "Upload"))?.askForLabel == false)
        // A different unknown place is still asked about.
        #expect(try store.warningInput(forSend: send(store, title: "Attach files"))?.askForLabel == true)
    }

    @Test func labelledPlacesAreNeverAsked() throws {
        let store = try Store.inMemory()
        let first = try send(store, title: "Upload")
        try store.renameDestination(ofSend: first, to: "Acme finance", includingOthers: true) // FR-13 label rule
        #expect(try store.warningInput(forSend: send(store, title: "Upload"))?.askForLabel == false)
        #expect(try store.sends().first?.destinationLabel == "Acme finance")
    }
}
