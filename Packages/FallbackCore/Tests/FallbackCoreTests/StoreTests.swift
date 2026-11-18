import Foundation
import Testing
@testable import FallbackCore

struct StoreTests {
    let store = try! Store.inMemory()
    let razorpay = Destination(key: "workday:razorpay", label: "Razorpay", source: .rule)
    let gmail = Destination(key: "gmail", label: "Gmail", source: .rule)

    func send(_ name: String, url: String? = "https://razorpay.wd3.myworkdayjobs.com/x", path: Bool = true,
              title: String = "Product Manager, Payments", at date: Date = Date()) -> NewSend {
        NewSend(path: path ? "/tmp/\(name)" : nil, fileName: name, appBundleID: "com.google.Chrome",
                appName: "Chrome", url: url, pageTitle: title, method: .axPanel, sentAt: date)
    }

    @Test func recordsAndListsNewestFirst() throws {
        try store.record(send("resume_v3.pdf", at: Date(timeIntervalSinceNow: -60)), destination: razorpay, facts: nil)
        try store.record(send("resume_v5.pdf"), destination: razorpay, facts: nil)
        #expect(try store.sends().map(\.fileName) == ["resume_v5.pdf", "resume_v3.pdf"])
        #expect(try store.sends(newestFirst: false).map(\.fileName) == ["resume_v3.pdf", "resume_v5.pdf"])
        #expect(try store.destinations().first?.sendCount == 2)
    }

    @Test func confidenceFollowsWhatWasKnown() throws {
        try store.record(send("a.pdf"), destination: razorpay, facts: nil)
        try store.record(send("b.pdf", url: nil), destination: razorpay, facts: nil)
        try store.record(send("c.pdf", path: false), destination: razorpay, facts: nil)
        #expect(try store.sends(newestFirst: false).map(\.confidence) == [.high, .medium, .low])
    }

    @Test func searchMatchesFileDestinationTitleAndApp() throws {
        try store.record(send("Resume_Arjun_v5.pdf"), destination: razorpay, facts: nil)
        try store.record(send("Proposal_Globex.pdf", url: "https://mail.google.com", title: "Inbox"), destination: gmail, facts: nil)
        #expect(try store.search("razor").map(\.fileName) == ["Resume_Arjun_v5.pdf"])     // destination
        #expect(try store.search("arjun").count == 1)                                       // file name part
        #expect(try store.search("payments").count == 1)                                    // page title
        #expect(try store.search("chrome").count == 2)                                      // app
        #expect(try store.search("glo gmail").map(\.fileName) == ["Proposal_Globex.pdf"])  // every word
        #expect(try store.search("   ").isEmpty)
    }

    @Test func renameForAllUpdatesSearchAndFutureSends() throws {
        let first = try store.record(send("a.pdf"), destination: razorpay, facts: nil)
        try store.renameDestination(ofSend: first, to: "Razorpay PM", includingOthers: true)
        try store.record(send("b.pdf"), destination: razorpay, facts: nil)
        #expect(try store.sends().allSatisfy { $0.destinationLabel == "Razorpay PM" })
        #expect(try store.search("pm").count == 2)
    }

    @Test func renameOnlyThisSendLeavesOthers() throws {
        let first = try store.record(send("a.pdf"), destination: razorpay, facts: nil)
        try store.record(send("b.pdf"), destination: razorpay, facts: nil)
        #expect(try store.otherSendCount(sameDestinationAs: first) == 1)
        try store.renameDestination(ofSend: first, to: "Old job", includingOthers: false)
        try store.record(send("c.pdf"), destination: razorpay, facts: nil)
        #expect(try store.sends().map(\.destinationLabel).sorted() == ["Old job", "Razorpay", "Razorpay"])
    }

    @Test func notASendAndDeleteDisappear() throws {
        let a = try store.record(send("a.pdf"), destination: razorpay, facts: nil)
        let b = try store.record(send("b.pdf"), destination: razorpay, facts: nil)
        try store.markNotASend(id: a)
        try store.deleteSend(id: b)
        #expect(try store.sends().isEmpty)
        #expect(try store.search("pdf").isEmpty)
        #expect(try store.sendCount() == 0)
    }

    @Test func suggestsClosestDestination() throws {
        try store.record(send("p.pdf"), destination: Destination(key: "domain:globex.com", label: "Globex", source: .rule), facts: nil)
        #expect(try store.closestDestination(to: "globx")?.label == "Globex")
        #expect(try store.closestDestination(to: "zzzzzz") == nil)
        try store.record(send("q.pdf"), destination: gmail, facts: nil)
        #expect(try store.closestDestination(to: "gmial")?.label == "Gmail")
    }

    @Test func fingerprintsAFile() throws {
        let path = FileManager.default.temporaryDirectory.appending(path: "fallback-\(UUID()).txt").path
        try Data("hello".utf8).write(to: URL(filePath: path))
        defer { try? FileManager.default.removeItem(atPath: path) }
        let facts = FileFacts.read(path: path)
        #expect(facts.sha256 == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
        #expect(facts.sizeBytes == 5)
        #expect(facts.identity != nil)
    }

    @Test func settingsRoundTrip() throws {
        try store.setSetting("paused_until", "x")
        #expect(try store.setting("paused_until") == "x")
        try store.setSetting("paused_until", nil)
        #expect(try store.setting("paused_until") == nil)
    }
}

@Test func searchIsFastOnTenThousandSends() throws {
    let store = try Store.inMemory()
    let places = (0..<50).map { Destination(key: "domain:company\($0).com", label: "Company \($0)", source: .fallback) }
    for i in 0..<10_000 {
        try store.record(NewSend(path: nil, fileName: "Document_\(i)_v\(i % 7).pdf", appBundleID: "com.google.Chrome",
                                 appName: "Chrome", url: "https://company\(i % 50).com", pageTitle: "Apply \(i)",
                                 method: .axPanel), destination: places[i % 50], facts: nil)
    }
    let start = ContinuousClock.now
    let results = try store.search("company 4")
    let elapsed = ContinuousClock.now - start
    #expect(!results.isEmpty)
    #expect(elapsed < .milliseconds(100), "search took \(elapsed)") // FR-10
}
