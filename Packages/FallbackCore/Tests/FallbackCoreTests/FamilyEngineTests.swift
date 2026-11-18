import CoreGraphics
import Foundation
import Testing
@testable import FallbackCore

// MARK: - Name stem (PRD 8.3 layer 4)

struct NameStemTests {
    // The PRD's table, row by row.
    @Test(arguments: [
        ("Resume_v3.pdf", "resume"),
        ("Anshu Resume FINAL (1).pdf", "anshu resume"),
        ("resume-v5-final-final.pdf", "resume"),
        ("Pitch Deck 2026-11-16.key", "pitch deck"),
        ("Proposal_Acme_revised.docx", "proposal acme"),
    ])
    func prdTable(name: String, stem: String) {
        #expect(NameStem.stem(name) == stem)
    }

    @Test func screenshotIsTooGeneric() {
        #expect(NameStem.stem("Screenshot 2026-11-16 at 10.42.png") == nil)
    }

    // Edge cases.
    @Test(arguments: [
        ("Resume v 3.pdf", "resume"),                  // "v 3" with a space
        ("Resume version 2.pdf", "resume"),            // "version 2"
        ("Resume ver4.pdf", "resume"),                 // "ver4"
        ("report_2.pdf", "report"),                    // trailing _2
        ("report-12.pdf", "report"),                   // trailing -12
        ("Pitch-Deck.final.v2.key", "pitch deck"),     // dots as separators
        ("budget 16.11.2026.xlsx", "budget"),          // day-first date
        ("draft new latest proposal.docx", "proposal"),
        ("resume (1) copy.pdf", "resume"),
        ("Invoice_Nov_Acme.pdf", "invoice nov acme"),
        ("FINAL Resume.PDF", "resume"),                // marker first, upper-case extension
        ("Updated   Resume  .pdf", "resume"),          // repeated spaces
    ])
    func edgeCases(name: String, stem: String) {
        #expect(NameStem.stem(name) == stem)
    }

    @Test(arguments: ["IMG_1234.jpg", "Untitled.docx", "abc.pdf", "Document (3).pdf", "2.0.pdf", "final.pdf", "Scan 3.pdf", "photo_2.heic"])
    func neverGroupedByName(name: String) {
        #expect(NameStem.stem(name) == nil)
    }

    @Test func versionNumbers() {
        #expect(NameStem.versionNumber("Resume_Arjun_v5.pdf") == 5)
        #expect(NameStem.versionNumber("Deck ver 3.key") == 3)
        #expect(NameStem.versionNumber("plan-version-2.docx") == 2)
        #expect(NameStem.versionNumber("review.pdf") == nil)
        #expect(NameStem.versionNumber("TV4.pdf") == nil)
    }
}

// MARK: - Fingerprints

struct SignatureTests {
    @Test func identicalTextIsFullySimilar() {
        let text = Fixtures.resume
        #expect(TextSignature.similarity(TextSignature.make(text)!, TextSignature.make(text)!) == 1)
    }

    @Test func unrelatedTextIsNotSimilar() {
        let a = TextSignature.make(Fixtures.resume)!, b = TextSignature.make(Fixtures.recipe)!
        #expect(TextSignature.similarity(a, b) < 0.2)
    }

    @Test func tooLittleTextHasNoSignature() {
        #expect(TextSignature.make("Hello there") == nil)
    }

    @Test func signatureSurvivesStorage() {
        let signature = TextSignature.make(Fixtures.resume)!
        #expect(TextSignature.from(TextSignature.data(signature)) == signature)
    }

    @Test func sameImageHashesTheSame() {
        let image = Fixtures.gradient(flipped: false)
        #expect(ImageSignature.distance(ImageSignature.make(image)!, ImageSignature.make(image)!) == 0)
        #expect(ImageSignature.distance(ImageSignature.make(image)!, ImageSignature.make(Fixtures.gradient(flipped: true))!) > 20)
    }

    @Test func largeFilesUseASampledFingerprint() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "big-\(UUID()).bin")
        try Data(repeating: 7, count: 3 << 20).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let full = FileFacts.read(path: url.path)
        let sampled = FileFacts.read(path: url.path, fullHashLimit: 1 << 20)
        #expect(full.sha256 != nil && sampled.sha256 != nil && full.sha256 != sampled.sha256)
    }
}

// MARK: - Index rules (FR-21, FR-22)

struct IndexRulesTests {
    let rules = IndexRules()

    @Test func skipsNoise() {
        #expect(rules.skipsFolder("node_modules"))
        #expect(rules.skipsFolder(".git"))
        #expect(rules.skipsFolder("Library"))
        #expect(rules.skipsFolder("Caches"))
        #expect(rules.skipsFolder("Slack.app"))
        #expect(rules.skipsFolder(".hidden"))
        #expect(!rules.skipsFolder("Resumes"))
        #expect(rules.skipsPath("/Users/a/Docs/project/node_modules/x/readme.md", under: "/Users/a/Docs"))
    }

    @Test func indexesDefaultTypesOverOneKilobyte() {
        #expect(rules.indexes(name: "resume.pdf", sizeBytes: 2048))
        #expect(!rules.indexes(name: "tiny.pdf", sizeBytes: 500))
        #expect(!rules.indexes(name: ".DS_Store", sizeBytes: 9000))
        #expect(!rules.indexes(name: "song.mp3", sizeBytes: 9000))
        #expect(rules.indexes(name: "Deck.key", sizeBytes: nil, isPackage: true))
    }

    @Test func usersCanAddTypesAndExclusions() {
        let custom = IndexRules(extraTypes: [".SKETCH"], extraExcludes: ["Archive"])
        #expect(custom.indexes(name: "logo.sketch", sizeBytes: 4096))
        #expect(custom.skipsFolder("Archive"))
    }
}

// MARK: - FamilyEngine (PRD 8.3)

struct FamilyEngineTests {
    let day: TimeInterval = 86_400
    let start = Date(timeIntervalSince1970: 1_790_000_000)

    func file(_ id: Int64, _ name: String, text: String? = nil, edited: TimeInterval = 0, created: TimeInterval? = nil,
              source: String? = nil, downloaded: TimeInterval? = nil, sha: String? = nil, title: String? = nil,
              docID: String? = nil, image: UInt64? = nil, sends: [SentTo] = []) -> FileEvidence {
        FileEvidence(id: id, name: name, sha256: sha ?? "sha-\(id)", modifiedAt: start + edited, createdAt: start + (created ?? edited),
                     whereFrom: source, downloadedAt: downloaded.map { start + $0 }, docTitle: title,
                     docCreatedAt: title == nil ? nil : start, docInternalID: docID,
                     textSignature: text.flatMap(TextSignature.make), imageHash: image, sends: sends)
    }

    func family(of id: Int64, in result: FamilyResult) -> FamilyGroup? { result.groups.first { $0.members.contains(id) } }

    // The PRD's "Examples the tests must cover" table.

    @Test func resumeV3AndV5_nameAndContent_v5IsNewer() {
        let v3 = file(1, "resume_v3.pdf", text: Fixtures.resume, edited: 0)
        let v5 = file(2, "resume_v5.pdf", text: Fixtures.resumeEdited, edited: 3 * day)
        let link = FamilyEngine.compare(v3, v5)!
        #expect(link.signals.contains(.name) && link.signals.contains(.content))
        #expect(link.confidence == .high && link.relation == .version)
        #expect(FamilyEngine.newer(v3, v5) == 2)
        let group = family(of: 1, in: FamilyEngine.build(files: [v3, v5]))!
        #expect(group.members == [1, 2] && group.versions == [1: 1, 2: 2] && group.newest == 2)
    }

    @Test func downloadsFromOneThread_lineageAndContent_orderedByDownload() {
        let thread = "https://mail.google.com/mail/u/0/#inbox/offer-docs"
        let files = [
            file(1, "final.pdf", text: Fixtures.resume, edited: 0, source: thread, downloaded: 2 * day),
            file(2, "2.0.pdf", text: Fixtures.resumeEdited, edited: 0, source: thread, downloaded: 1 * day),
            file(3, "Document (3).pdf", text: Fixtures.resumeEdited, edited: 0, source: thread, downloaded: 3 * day),
        ]
        let link = FamilyEngine.compare(files[0], files[1])!
        #expect(link.signals.contains(.lineage) && link.signals.contains(.content))
        #expect(link.reasons.contains("same source"))
        let group = family(of: 1, in: FamilyEngine.build(files: files))!
        #expect(group.members == [2, 1, 3]) // download order
        #expect(group.newest == 3)
    }

    @Test func razorpayAndEmergentResumes_content_siblingVariants() {
        let a = file(1, "Resume_Razorpay.pdf", text: Fixtures.resume, edited: 0)
        let b = file(2, "Resume_Emergent.pdf", text: Fixtures.resumeEdited, edited: day)
        let link = FamilyEngine.compare(a, b)!
        #expect(link.signals == [.content] && link.confidence == .high)
        #expect(link.relation == .variant) // never called "older"
        #expect(family(of: 1, in: FamilyEngine.build(files: [a, b]))!.members.count == 2)
    }

    @Test func proposalDocxAndPdf_nameAndContent_exportPair() {
        let docx = file(1, "Proposal.docx", text: Fixtures.proposal, edited: day)
        let pdf = file(2, "Proposal.pdf", text: Fixtures.proposal, edited: 0)
        let link = FamilyEngine.compare(docx, pdf)!
        #expect(link.signals.contains(.name) && link.signals.contains(.content))
        #expect(link.relation == .export)
        #expect(family(of: 1, in: FamilyEngine.build(files: [docx, pdf]))!.members.count == 2)
    }

    @Test func twoDifferentScreenshots_notGrouped() {
        let a = file(1, "Screenshot 2026-11-16 at 10.42.png", image: ImageSignature.make(Fixtures.gradient(flipped: false)))
        let b = file(2, "Screenshot 2026-11-17 at 18.05.png", image: ImageSignature.make(Fixtures.gradient(flipped: true)))
        #expect(FamilyEngine.compare(a, b) == nil)
        #expect(FamilyEngine.build(files: [a, b]).groups.count == 2)
    }

    // Edge cases.

    @Test func exactDuplicateWithAnotherName_isLineage() {
        let link = FamilyEngine.compare(file(1, "contract.pdf", sha: "abc"), file(2, "Signed copy.pdf", sha: "abc"))!
        #expect(link.signals == [.lineage] && link.confidence == .high)
    }

    @Test func sameNameAlone_isOnlyASuggestion() {
        let a = file(1, "Budget_v1.xlsx", edited: 0), b = file(2, "Budget_v2.xlsx", edited: day)
        #expect(FamilyEngine.compare(a, b)!.confidence == .medium)
        let result = FamilyEngine.build(files: [a, b])
        #expect(result.groups.count == 2)
        #expect(result.suggestions == [[1, 2]])
    }

    @Test func halfTheSameText_isMedium() {
        let a = file(1, "notes one.txt", text: Fixtures.resume), b = file(2, "other thing.txt", text: Fixtures.resumeHalf)
        let link = FamilyEngine.compare(a, b)
        #expect(link?.confidence == .medium, "similarity \(link?.similarity ?? 0)")
    }

    @Test func userMergeWins() {
        let a = file(1, "alpha plan.docx"), b = file(2, "beta budget.xlsx")
        let result = FamilyEngine.build(files: [a, b], decisions: [.same(1, 2)])
        #expect(result.groups.count == 1)
    }

    @Test func userSplitWinsOverStrongEvidence() {
        let a = file(1, "contract.pdf", sha: "abc"), b = file(2, "contract copy.pdf", sha: "abc")
        let result = FamilyEngine.build(files: [a, b], decisions: [.separate(1, 2)])
        #expect(result.groups.count == 2)
        #expect(result.suggestions.isEmpty)
    }

    @Test func dismissedSuggestionStaysDismissed() {
        let a = file(1, "Budget_v1.xlsx"), b = file(2, "Budget_v2.xlsx", edited: day)
        #expect(FamilyEngine.build(files: [a, b], decisions: [.dismissed(1, 2)]).suggestions.isEmpty)
    }

    @Test func genericNamesWithoutOtherEvidence_neverGroup() {
        #expect(FamilyEngine.compare(file(1, "Untitled.pdf"), file(2, "Untitled.pdf")) == nil)
    }

    @Test func bothKeepGettingEdited_isVariantNotVersion() {
        let a = file(1, "plan_v1.docx", text: Fixtures.proposal, edited: 10 * day, created: 0)
        let b = file(2, "plan_v2.docx", text: Fixtures.proposal, edited: 9 * day, created: 1 * day)
        #expect(FamilyEngine.compare(a, b)!.relation == .variant)
    }

    @Test func sentToDifferentPlacesWithin30Days_isVariant() {
        let a = file(1, "cv_v1.pdf", text: Fixtures.resume, edited: 0, sends: [SentTo(destinationKey: "lever:emergent", at: start + day)])
        let b = file(2, "cv_v2.pdf", text: Fixtures.resume, edited: day, sends: [SentTo(destinationKey: "workday:razorpay", at: start + 10 * day)])
        #expect(FamilyEngine.compare(a, b)!.relation == .variant)
    }

    @Test func sentToDifferentPlaces60DaysApart_staysAVersion() {
        let a = file(1, "cv_v1.pdf", text: Fixtures.resume, edited: 0, sends: [SentTo(destinationKey: "lever:emergent", at: start + day)])
        let b = file(2, "cv_v2.pdf", text: Fixtures.resume, edited: day, sends: [SentTo(destinationKey: "workday:razorpay", at: start + 61 * day)])
        #expect(FamilyEngine.compare(a, b)!.relation == .version)
    }

    @Test func equalDatesWithoutNumbers_areUnclear() {
        let a = file(1, "final.pdf", text: Fixtures.resume), b = file(2, "2.0.pdf", text: Fixtures.resume)
        #expect(FamilyEngine.newer(a, b) == nil)
        #expect(FamilyEngine.compare(a, b)!.relation == .unclear)
    }

    @Test func equalDates_versionNumberBreaksTheTie() {
        let v3 = file(1, "resume_v3.pdf", text: Fixtures.resume), v5 = file(2, "resume_v5.pdf", text: Fixtures.resume)
        #expect(FamilyEngine.newer(v3, v5) == 2)
    }

    @Test func datesBeatVersionNumbers() {
        let v5 = file(1, "resume_v5.pdf", text: Fixtures.resume, edited: 0), v3 = file(2, "resume_v3.pdf", text: Fixtures.resume, edited: day)
        #expect(FamilyEngine.newer(v5, v3) == 2) // v3 was edited later, so it's newer
    }

    @Test func olderChangedAfterNewerAppeared_isUnclear() {
        let a = file(1, "deck_v1.key", text: Fixtures.proposal, edited: 5 * day, created: 0)
        let b = file(2, "deck_v2.key", text: Fixtures.proposal, edited: 6 * day, created: 2 * day)
        #expect(FamilyEngine.newer(a, b) == nil)
    }

    @Test func matchingInternalDocumentID_isHigh() {
        let link = FamilyEngine.compare(file(1, "a1.pdf", docID: "5343eb62"), file(2, "b2.pdf", docID: "5343eb62"))!
        #expect(link.signals == [.metadata] && link.confidence == .high)
    }

    @Test func sameTitleAndDate_isMediumOnly() {
        let link = FamilyEngine.compare(file(1, "x1.pdf", title: "Arjun Mehta Resume"), file(2, "y2.pdf", title: "Arjun Mehta Resume"))!
        #expect(link.confidence == .medium && link.reasons == ["same title + date"])
    }

    @Test func genericTitleDoesNotCount() {
        #expect(FamilyEngine.compare(file(1, "x1.pdf", title: "Untitled"), file(2, "y2.pdf", title: "Untitled")) == nil)
    }

    @Test func nearIdenticalImages_group() {
        let hash = ImageSignature.make(Fixtures.gradient(flipped: false))!
        let link = FamilyEngine.compare(file(1, "logo.png", image: hash), file(2, "logo small.png", image: hash ^ 0b101))!
        #expect(link.confidence == .high)
    }

    /// The two screenshots in ~/FallbackTest: same layout, different background colour.
    @Test func sameLayoutDifferentColours_notGrouped() {
        let blue = Fixtures.panel(red: 0.15, green: 0.47, blue: 0.78), orange = Fixtures.panel(red: 0.78, green: 0.35, blue: 0.15)
        let a = FileEvidence(id: 1, name: "Screenshot 1.png", imageHash: ImageSignature.make(blue), imageColor: ImageSignature.averageColor(blue))
        let b = FileEvidence(id: 2, name: "Screenshot 2.png", imageHash: ImageSignature.make(orange), imageColor: ImageSignature.averageColor(orange))
        #expect(ImageSignature.distance(a.imageHash!, b.imageHash!) <= 6) // the layout alone looks identical
        #expect(FamilyEngine.compare(a, b) == nil)
    }

    @Test func knownOrganisationInOneName_isVariant() {
        let a = file(1, "resume.pdf", text: Fixtures.resume), b = file(2, "resume globex.pdf", text: Fixtures.resume, edited: day)
        #expect(FamilyEngine.compare(a, b, knownOrganisations: ["globex"])!.relation == .variant)
    }

    @Test func familyNameAndVariantsAndVersionNumbers() {
        let files = [
            file(1, "resume_v3.pdf", text: Fixtures.resume),
            file(2, "resume_v5.pdf", text: Fixtures.resume),
            file(3, "Resume_Razorpay.pdf", text: Fixtures.resume),
            file(4, "Resume_Emergent.pdf", text: Fixtures.resume),
        ]
        let group = FamilyEngine.build(files: files).groups.first!
        #expect(group.name == "Resume")
        #expect(group.variants == [3, 4])
        #expect(group.versions == [1: 1, 2: 2])
        #expect(group.newest == 2)
    }

    @Test func singleFileIsItsOwnFamily() {
        let result = FamilyEngine.build(files: [file(1, "Invoice_Nov_Acme.pdf")])
        #expect(result.groups.count == 1 && result.groups[0].versions == [1: 1])
    }

    @Test func unrelatedDocuments_neverCompared() {
        let files = [file(1, "Resume.pdf", text: Fixtures.resume), file(2, "Lasagne.pdf", text: Fixtures.recipe)]
        #expect(FamilyEngine.build(files: files).links.isEmpty)
    }
}

enum Fixtures {
    static let resume = """
    Arjun Mehta Product Manager Bengaluru arjun mehta example com Experience Senior Associate Product Acme Fintech
    2023 2026 Led onboarding revamp that lifted activation by 18 percent across three markets Built the payments
    reconciliation dashboard used by forty finance analysts every day Associate Product Manager Globex 2021 2023
    Shipped the merchant risk score that cut chargebacks by a quarter Ran weekly experiments with design and data
    Education B Tech Computer Science 2021 Skills SQL Figma experimentation roadmapping stakeholder communication
    """
    /// The same resume with a few words changed: well over 75% the same.
    static let resumeEdited = resume.replacingOccurrences(of: "18 percent", with: "22 percent")
        .replacingOccurrences(of: "forty", with: "fifty")
    /// Roughly half the same text.
    static let resumeHalf = resume.split(whereSeparator: \.isWhitespace).prefix(76).joined(separator: " ") + """
     Volunteer teaching at the weekend school for six years organised book drives and maths clubs
     for children in three neighbourhoods
    """
    static let proposal = """
    Proposal for Acme Corp Scope CX quality audit for forty agents across two shifts Price Rs 4 50 000 for eight weeks
    Timeline kickoff 1 December 2026 with weekly reviews and a final readout Contact Arjun Mehta for questions
    """
    static let recipe = """
    Lasagne for six people Brown the onions and garlic add the minced beef and tomatoes simmer for forty minutes
    Layer sheets of pasta with the sauce and bechamel finish with cheese and bake until golden and bubbling
    """

    /// A light rectangle on a coloured background, like the test screenshots.
    static func panel(red: CGFloat, green: CGFloat, blue: CGFloat) -> CGImage {
        let context = CGContext(data: nil, width: 160, height: 100, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.setFillColor(red: red, green: green, blue: blue, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 160, height: 100))
        context.setFillColor(red: 0.94, green: 0.94, blue: 0.94, alpha: 1)
        context.fill(CGRect(x: 12, y: 40, width: 88, height: 48))
        return context.makeImage()!
    }

    static func gradient(flipped: Bool) -> CGImage {
        let size = 64
        let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size,
                                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        for x in 0..<size {
            let value = CGFloat(flipped ? size - x : x) / CGFloat(size)
            context.setFillColor(gray: value, alpha: 1)
            context.fill(CGRect(x: x, y: 0, width: 1, height: size))
        }
        return context.makeImage()!
    }
}
